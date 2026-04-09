package com.example.crm_caller_nxtgen.overlay.state

import com.example.crm_caller_nxtgen.overlay.domain.*
import com.example.crm_caller_nxtgen.overlay.data.FrappeRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch

/**
 * Finite state machine for the call overlay.
 *
 * Rules:
 *  - One event is processed at a time (serialised via scope).
 *  - Submission states (SubmittingLead, SubmittingAction) ignore new submit events.
 *  - A new CallRinging while another is in progress cancels the first lookup.
 *  - CallEnded moves to PostCall (no auto-dismiss — user must explicitly close).
 *  - Complaint opens as a separate popup window; main overlay minimises to bubble.
 */
class OverlayStateMachine(
    private val repository: FrappeRepository,
    private val scope: CoroutineScope,
) {
    private val _state = MutableStateFlow<OverlayState>(OverlayState.Idle)
    val state: StateFlow<OverlayState> = _state.asStateFlow()

    private val _complaintState = MutableStateFlow<ComplaintPopupState>(ComplaintPopupState.Hidden)
    val complaintState: StateFlow<ComplaintPopupState> = _complaintState.asStateFlow()

    private val _sideEffects = Channel<OverlaySideEffect>(Channel.BUFFERED)
    val sideEffects = _sideEffects.receiveAsFlow()

    // Guard: only one lookup/submit job runs at a time
    private var activeJob: Job? = null

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────

    fun handleEvent(event: OverlayEvent) {
        val current = _state.value

        when (event) {

            // ── Phone OS ──────────────────────────────────────────────────────

            is OverlayEvent.CallRinging -> {
                activeJob?.cancel()
                _state.value = OverlayState.LoadingIdentity(event.phoneNumber, CallPhase.RINGING)
                activeJob = scope.launch {
                    val identity = repository.lookupIdentityByPhone(event.phoneNumber)
                    if (identity != null) {
                        transition(OverlayEvent.IdentityResolved(identity))
                    } else {
                        transition(OverlayEvent.IdentityNotFound)
                    }
                }
            }

            is OverlayEvent.CallAnswered -> {
                _state.value = current.withCallPhase(CallPhase.ACTIVE)
            }

            is OverlayEvent.CallEnded -> {
                activeJob?.cancel()
                val phone = current.phoneNumber ?: return
                val identity = current.knownIdentity ?: CallerIdentity.Unknown
                val duration = repository.getSessionDuration(phone)
                // Stop recording if active
                if (current.isRecordingActive) emitEffect(OverlaySideEffect.StopRecording)
                // PostCall stays expanded — user must explicitly close
                _state.value = OverlayState.PostCall(phone, identity, duration, isExpanded = true)
            }

            // ── Backend results ───────────────────────────────────────────────

            is OverlayEvent.IdentityResolved -> {
                val phone = current.phoneNumber ?: return
                val wasExpanded = current.isExpanded
                _state.value = OverlayState.KnownCaller(
                    phoneNumber = phone,
                    identity = event.identity,
                    callPhase = current.callPhase ?: CallPhase.RINGING,
                    isExpanded = wasExpanded,
                )
            }

            is OverlayEvent.IdentityNotFound -> {
                val phone = current.phoneNumber ?: return
                val wasExpanded = current.isExpanded
                _state.value = OverlayState.UnknownCaller(
                    phoneNumber = phone,
                    callPhase = current.callPhase ?: CallPhase.RINGING,
                    isExpanded = wasExpanded,
                )
            }

            // ── UI actions ────────────────────────────────────────────────────

            is OverlayEvent.ToggleExpand -> {
                when (current) {
                    is OverlayState.UnknownCaller ->
                        _state.value = current.copy(isExpanded = !current.isExpanded)
                    is OverlayState.KnownCaller ->
                        _state.value = current.copy(isExpanded = !current.isExpanded)
                    is OverlayState.PostCall ->
                        _state.value = current.copy(isExpanded = !current.isExpanded)
                    else -> { /* ignore during submission states */ }
                }
            }

            is OverlayEvent.OpenOpportunityForm -> {
                when (current) {
                    is OverlayState.KnownCaller ->
                        _state.value = current.copy(isExpanded = true, activeSheet = ActiveSheet.OPPORTUNITY)
                    is OverlayState.PostCall ->
                        _state.value = OverlayState.KnownCaller(
                            phoneNumber = current.phoneNumber,
                            identity    = current.identity,
                            callPhase   = CallPhase.ENDED,
                            isExpanded  = true,
                            activeSheet = ActiveSheet.OPPORTUNITY,
                        )
                    else -> {}
                }
            }

            is OverlayEvent.OpenAddLeadForm -> {
                if (current is OverlayState.KnownCaller)
                    _state.value = current.copy(isExpanded = true, activeSheet = ActiveSheet.ADD_LEAD)
            }

            is OverlayEvent.OpenAddNoteForm -> {
                when (current) {
                    is OverlayState.KnownCaller ->
                        _state.value = current.copy(isExpanded = true, activeSheet = ActiveSheet.ADD_NOTE)
                    is OverlayState.PostCall ->
                        _state.value = OverlayState.KnownCaller(
                            phoneNumber = current.phoneNumber,
                            identity    = current.identity,
                            callPhase   = CallPhase.ENDED,
                            isExpanded  = true,
                            activeSheet = ActiveSheet.ADD_NOTE,
                        )
                    else -> {}
                }
            }

            is OverlayEvent.SubmitNote -> {
                val phone = current.phoneNumber ?: return
                scope.launch {
                    runCatching { repository.saveNote(phone, event.content) }
                    if (current is OverlayState.KnownCaller)
                        _state.value = current.copy(activeSheet = ActiveSheet.NONE)
                    emitEffect(OverlaySideEffect.ShowToast("Note saved"))
                }
            }

            is OverlayEvent.CancelSheet -> {
                if (current is OverlayState.KnownCaller) {
                    _state.value = current.copy(activeSheet = ActiveSheet.NONE)
                }
            }

            is OverlayEvent.DismissOverlay,
            is OverlayEvent.PostCallDismissed -> {
                activeJob?.cancel()
                if (current.isRecordingActive) emitEffect(OverlaySideEffect.StopRecording)
                _complaintState.value = ComplaintPopupState.Hidden
                _state.value = OverlayState.Idle
                emitEffect(OverlaySideEffect.HideComplaintPopup)
                emitEffect(OverlaySideEffect.DismissWindow)
            }

            // ── Complaint popup ───────────────────────────────────────────────

            is OverlayEvent.OpenComplaintPopup,
            is OverlayEvent.OpenComplaintForm -> {
                val phone = current.phoneNumber ?: return
                val identity = current.knownIdentity ?: CallerIdentity.Unknown
                
                // Minimise main overlay to bubble
                when (current) {
                    is OverlayState.KnownCaller -> _state.value = current.copy(isExpanded = false)
                    is OverlayState.PostCall    -> _state.value = current.copy(isExpanded = false)
                    else -> {}
                }
                _complaintState.value = ComplaintPopupState.Visible(identity, phone)
                emitEffect(OverlaySideEffect.ShowComplaintPopup)
            }

            is OverlayEvent.CloseComplaintPopup -> {
                _complaintState.value = ComplaintPopupState.Hidden
                emitEffect(OverlaySideEffect.HideComplaintPopup)
                // Re-expand main overlay
                when (val cur = _state.value) {
                    is OverlayState.KnownCaller -> _state.value = cur.copy(isExpanded = true)
                    is OverlayState.PostCall    -> _state.value = cur.copy(isExpanded = true)
                    else -> {}
                }
            }

            is OverlayEvent.SubmitComplaint -> {
                val popupState = _complaintState.value
                if (popupState !is ComplaintPopupState.Visible) return
                val identity = popupState.identity
                val phone = popupState.phoneNumber

                _complaintState.value = ComplaintPopupState.Submitting(identity, phone)
                activeJob = scope.launch {
                    val result = runCatching {
                        repository.createComplaint(identity, phone, event.category, event.details, event.priority)
                    }
                    result.fold(
                        onSuccess = {
                            _complaintState.value = ComplaintPopupState.Hidden
                            emitEffect(OverlaySideEffect.HideComplaintPopup)
                            emitEffect(OverlaySideEffect.ShowToast("Complaint logged"))
                            // Re-expand main overlay
                            when (val cur = _state.value) {
                                is OverlayState.KnownCaller -> _state.value = cur.copy(isExpanded = true)
                                is OverlayState.PostCall    -> _state.value = cur.copy(isExpanded = true)
                                else -> {}
                            }
                        },
                        onFailure = { err ->
                            _complaintState.value = ComplaintPopupState.Visible(identity, phone)
                            emitEffect(OverlaySideEffect.ShowToast("Failed: ${err.message}"))
                        }
                    )
                }
            }

            is OverlayEvent.ComplaintCreated -> {
                // Legacy path — handled via SubmitComplaint now, but kept for compat
                val phone = current.phoneNumber ?: return
                val identity = current.knownIdentity ?: return
                _state.value = OverlayState.KnownCaller(phone, identity, current.callPhase ?: CallPhase.ACTIVE, true)
            }

            // ── Recording ─────────────────────────────────────────────────────

            is OverlayEvent.ToggleRecording -> {
                when (current) {
                    is OverlayState.KnownCaller -> {
                        val next = current.copy(isRecording = !current.isRecording)
                        _state.value = next
                        emitEffect(if (next.isRecording) OverlaySideEffect.StartRecording else OverlaySideEffect.StopRecording)
                    }
                    is OverlayState.UnknownCaller -> {
                        val next = current.copy(isRecording = !current.isRecording)
                        _state.value = next
                        emitEffect(if (next.isRecording) OverlaySideEffect.StartRecording else OverlaySideEffect.StopRecording)
                    }
                    else -> {}
                }
            }

            // ── Lead submission ───────────────────────────────────────────────

            is OverlayEvent.SubmitLead -> {
                if (current !is OverlayState.UnknownCaller) return
                if (event.name.isBlank()) return
                val phone = current.phoneNumber
                val wasRecording = current.isRecording

                _state.value = OverlayState.SubmittingLead(phone, current.callPhase)
                activeJob = scope.launch {
                    val result = runCatching {
                        repository.createLead(
                            name    = event.name,
                            email   = event.email,
                            company = event.company,
                            phone   = phone,
                            note    = event.note,
                        )
                    }
                    result.fold(
                        onSuccess = { identity ->
                            _state.value = OverlayState.KnownCaller(
                                phoneNumber = phone,
                                identity    = identity,
                                callPhase   = current.callPhase,
                                isExpanded  = true,
                                activeSheet = ActiveSheet.NONE,
                                isRecording = wasRecording,
                            )
                            emitEffect(OverlaySideEffect.ShowToast("Lead created: ${identity.name}"))
                        },
                        onFailure = { err ->
                            _state.value = OverlayState.UnknownCaller(phone, current.callPhase, isExpanded = true)
                            emitEffect(OverlaySideEffect.ShowToast("Failed: ${err.message}"))
                        }
                    )
                }
            }

            is OverlayEvent.LeadCreated -> {
                val phone = current.phoneNumber ?: return
                _state.value = OverlayState.KnownCaller(
                    phoneNumber = phone,
                    identity    = event.identity,
                    callPhase   = current.callPhase ?: CallPhase.ACTIVE,
                    isExpanded  = true,
                )
            }

            is OverlayEvent.LeadFailed -> {
                val phone = current.phoneNumber ?: return
                _state.value = OverlayState.UnknownCaller(phone, current.callPhase ?: CallPhase.RINGING, isExpanded = true)
                emitEffect(OverlaySideEffect.ShowToast("Lead creation failed: ${event.reason}"))
            }

            // ── Opportunity submission ────────────────────────────────────────

            is OverlayEvent.SubmitOpportunity -> {
                if (current !is OverlayState.KnownCaller) return
                val identity = current.identity
                if (identity is CallerIdentity.Unknown) return

                _state.value = OverlayState.SubmittingAction(
                    phoneNumber = current.phoneNumber,
                    identity    = identity,
                    callPhase   = current.callPhase,
                    action      = ActiveSheet.OPPORTUNITY,
                )
                activeJob = scope.launch {
                    val result = runCatching {
                        repository.createOpportunity(identity, event.expectedValue, event.stage, event.note)
                    }
                    result.fold(
                        onSuccess = { updatedIdentity ->
                            _state.value = OverlayState.KnownCaller(
                                phoneNumber = current.phoneNumber,
                                identity    = updatedIdentity,
                                callPhase   = current.callPhase,
                                isExpanded  = true,
                                activeSheet = ActiveSheet.NONE,
                            )
                            emitEffect(OverlaySideEffect.ShowToast("Opportunity saved"))
                        },
                        onFailure = { err ->
                            _state.value = current.copy(activeSheet = ActiveSheet.OPPORTUNITY)
                            emitEffect(OverlaySideEffect.ShowToast("Failed: ${err.message}"))
                        }
                    )
                }
            }

            is OverlayEvent.OpportunityCreated -> {
                if (current is OverlayState.KnownCaller || current is OverlayState.SubmittingAction) {
                    val phone = current.phoneNumber ?: return
                    _state.value = OverlayState.KnownCaller(
                        phoneNumber = phone,
                        identity    = event.updatedIdentity,
                        callPhase   = current.callPhase ?: CallPhase.ACTIVE,
                        isExpanded  = true,
                    )
                }
            }

            is OverlayEvent.ActionFailed -> {
                emitEffect(OverlaySideEffect.ShowToast("Action failed: ${event.reason}"))
                if (current is OverlayState.SubmittingAction) {
                    _state.value = OverlayState.KnownCaller(
                        phoneNumber = current.phoneNumber,
                        identity    = current.identity,
                        callPhase   = current.callPhase,
                        isExpanded  = true,
                        activeSheet = current.action,
                    )
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Internal helpers
    // ─────────────────────────────────────────────────────────────────────────

    private fun transition(event: OverlayEvent) = handleEvent(event)

    private fun emitEffect(effect: OverlaySideEffect) {
        scope.launch { _sideEffects.send(effect) }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// OverlayState extension helpers (avoid verbose when blocks in the FSM)
// ─────────────────────────────────────────────────────────────────────────────

private val OverlayState.phoneNumber: String?
    get() = when (this) {
        is OverlayState.LoadingIdentity  -> phoneNumber
        is OverlayState.UnknownCaller    -> phoneNumber
        is OverlayState.SubmittingLead   -> phoneNumber
        is OverlayState.KnownCaller      -> phoneNumber
        is OverlayState.SubmittingAction -> phoneNumber
        is OverlayState.PostCall         -> phoneNumber
        else -> null
    }

private val OverlayState.callPhase: CallPhase?
    get() = when (this) {
        is OverlayState.LoadingIdentity  -> callPhase
        is OverlayState.UnknownCaller    -> callPhase
        is OverlayState.SubmittingLead   -> callPhase
        is OverlayState.KnownCaller      -> callPhase
        is OverlayState.SubmittingAction -> callPhase
        else -> null
    }

private val OverlayState.knownIdentity: CallerIdentity?
    get() = when (this) {
        is OverlayState.KnownCaller      -> identity
        is OverlayState.SubmittingAction -> identity
        is OverlayState.PostCall         -> identity
        else -> null
    }

private val OverlayState.isRecordingActive: Boolean
    get() = when (this) {
        is OverlayState.KnownCaller   -> isRecording
        is OverlayState.UnknownCaller -> isRecording
        else -> false
    }

private fun OverlayState.withCallPhase(phase: CallPhase): OverlayState = when (this) {
    is OverlayState.LoadingIdentity  -> copy(callPhase = phase)
    is OverlayState.UnknownCaller    -> copy(callPhase = phase)
    is OverlayState.SubmittingLead   -> copy(callPhase = phase)
    is OverlayState.KnownCaller      -> copy(callPhase = phase)
    is OverlayState.SubmittingAction -> copy(callPhase = phase)
    else -> this
}
