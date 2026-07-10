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

    private val _itemSearchResults = MutableStateFlow<List<ItemSearchResult>>(emptyList())
    val itemSearchResults: StateFlow<List<ItemSearchResult>> = _itemSearchResults.asStateFlow()

    // Guard: only one lookup/submit job runs at a time
    private var activeJob: Job? = null

    // Separate from activeJob so typing an item search never cancels a submit
    private var searchJob: Job? = null

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────

    fun handleEvent(event: OverlayEvent) {
        val current = _state.value

        when (event) {

            // ── Phone OS ──────────────────────────────────────────────────────

            is OverlayEvent.ShowKnownIdentity -> {
                // Opened manually (or from an already-resolved caller lookup) with
                // an identity we already trust — show it immediately instead of
                // risking a phone-number lookup falsely returning "Unknown".
                activeJob?.cancel()
                _state.value = OverlayState.KnownCaller(
                    phoneNumber = event.phoneNumber,
                    identity    = event.identity,
                    callPhase   = CallPhase.RINGING,
                    isExpanded  = true,
                )
                // Enrich in the background — the caller info we were handed may be
                // minimal (just name/email/status); the full lookup fills in
                // company, latest note and latest quote once it resolves.
                activeJob = scope.launch {
                    val enriched = runCatching { repository.lookupIdentityByPhone(event.phoneNumber) }
                        .getOrNull()
                    if (enriched != null) {
                        val stillShowingSameCall = (_state.value as? OverlayState.KnownCaller)
                            ?.phoneNumber == event.phoneNumber
                        if (stillShowingSameCall) {
                            transition(OverlayEvent.IdentityResolved(enriched))
                        }
                    }
                }
            }

            is OverlayEvent.CallRinging -> {
                // Ignore duplicate event for the same phone number to prevent race
                // between the native BroadcastReceiver and the Flutter phone listener.
                val currentPhone = when (current) {
                    is OverlayState.LoadingIdentity -> current.phoneNumber
                    is OverlayState.UnknownCaller   -> current.phoneNumber
                    is OverlayState.KnownCaller     -> current.phoneNumber
                    else -> null
                }
                if (currentPhone == event.phoneNumber) return

                // CrmCallScreeningService (real number, authoritative) and
                // CallMonitorService/CallStateReceiver (fallback, can only see "Hidden"
                // without READ_CALL_LOG) fire independently with no ordering guarantee.
                // If we're already showing/resolving a REAL number for this call, never
                // let a later "Hidden"/blank fallback event downgrade it.
                val haveRealNumber  = currentPhone != null && currentPhone != "Hidden" && currentPhone.isNotBlank()
                val incomingIsWorse = event.phoneNumber == "Hidden" || event.phoneNumber.isBlank()
                if (haveRealNumber && incomingIsWorse) return

                activeJob?.cancel()
                _state.value = OverlayState.LoadingIdentity(event.phoneNumber, CallPhase.RINGING)
                activeJob = scope.launch {
                    // Wrap in runCatching so a DB/network crash can't leave overlay
                    // stuck at LoadingIdentity forever showing a spinner
                    runCatching { repository.lookupIdentityByPhone(event.phoneNumber) }
                        .onSuccess { identity ->
                            if (identity != null) transition(OverlayEvent.IdentityResolved(identity))
                            else                  transition(OverlayEvent.IdentityNotFound)
                        }
                        .onFailure { transition(OverlayEvent.IdentityNotFound) }
                }
            }

            is OverlayEvent.CallAnswered -> {
                _state.value = current.withCallPhase(CallPhase.ACTIVE)
            }

            is OverlayEvent.AnswerCall -> {
                emitEffect(OverlaySideEffect.AnswerCall)
            }

            is OverlayEvent.CallEnded -> {
                // CallStateReceiver (broadcast) and CallMonitorService (TelephonyCallback)
                // both independently fire this same signal for one real call ending. Without
                // this guard, the second firing would reconstruct PostCall from scratch —
                // wiping whatever the user had already typed/opened — and launch a second
                // createCallLog, creating a duplicate backend record for one call.
                val phoneForDedup = current.phoneNumber ?: event.phone.takeIf { it.isNotBlank() }
                android.util.Log.d("CrmMonitor", "CallEnded: current=${current::class.simpleName} currentPhone=${current.phoneNumber} eventPhone=${event.phone} phoneForDedup=$phoneForDedup")
                if (current is OverlayState.PostCall && current.phoneNumber == phoneForDedup) {
                    android.util.Log.d("CrmMonitor", "CallEnded: IGNORED (dedup — already PostCall for this phone)")
                    return
                }

                activeJob?.cancel()
                // Fall back to the phone passed by the call-ended signal itself —
                // needed when no overlay was ever shown (e.g. outbound calls, or
                // the state already reset to Idle) so the call still gets logged.
                val phone = phoneForDedup ?: run {
                    android.util.Log.w("CrmMonitor", "CallEnded: NO PHONE AVAILABLE — dropping, no log will be created")
                    return
                }
                android.util.Log.d("CrmMonitor", "CallEnded: proceeding to log call for phone=$phone direction=${event.direction}")
                val identity = current.knownIdentity ?: CallerIdentity.Unknown
                val duration = repository.getSessionDuration(phone)
                // PostCall stays expanded and opens straight into the "add a note"
                // form — the second popup the user sees right after a call ends.
                _state.value = OverlayState.PostCall(
                    phone, identity, duration,
                    isExpanded  = true,
                    activeSheet = ActiveSheet.LOG_CALL,
                    direction   = event.direction,
                )

                // Log the call immediately, with no notes — every call gets a
                // backend record whether or not the user ever touches the note
                // form that just opened. Submitting notes later PATCHes this
                // same record instead of creating a second one.
                activeJob = scope.launch {
                    val ref = runCatching {
                        repository.createCallLog(identity, phone, duration, "", "Regular", event.direction)
                    }.onFailure {
                        android.util.Log.e("CrmMonitor", "createCallLog failed for $phone", it)
                    }.getOrNull()
                    val stillSamePostCall = (_state.value as? OverlayState.PostCall)?.phoneNumber == phone
                    if (ref != null && stillSamePostCall) {
                        _state.value = (_state.value as OverlayState.PostCall).copy(callLogRef = ref)
                    }
                }
            }

            // ── Backend results ───────────────────────────────────────────────

            is OverlayEvent.IdentityResolved -> {
                // Guard: if call ended before lookup finished, don't revert PostCall/Idle
                if (current is OverlayState.PostCall || current is OverlayState.Idle) return
                val phone = current.phoneNumber ?: return
                // Pop up expanded immediately — no tiny pill the user has to tap.
                _state.value = OverlayState.KnownCaller(
                    phoneNumber = phone,
                    identity    = event.identity,
                    callPhase   = current.callPhase ?: CallPhase.RINGING,
                    isExpanded  = true,
                )
            }

            is OverlayEvent.IdentityNotFound -> {
                // Guard: if call ended before lookup finished, don't revert PostCall/Idle
                if (current is OverlayState.PostCall || current is OverlayState.Idle) return
                val phone = current.phoneNumber ?: return
                // Pop up expanded immediately — no tiny pill the user has to tap.
                _state.value = OverlayState.UnknownCaller(
                    phoneNumber = phone,
                    callPhase   = current.callPhase ?: CallPhase.RINGING,
                    isExpanded  = true,
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
                val phone    = current.phoneNumber ?: return
                val identity = current.knownIdentity
                scope.launch {
                    runCatching { repository.saveNote(phone, event.content, identity) }
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
                
                // Minimise main overlay to bubble so complaint popup has full focus
                when (current) {
                    is OverlayState.KnownCaller   -> _state.value = current.copy(isExpanded = false)
                    is OverlayState.PostCall      -> _state.value = current.copy(isExpanded = false)
                    is OverlayState.UnknownCaller -> _state.value = current.copy(isExpanded = false)
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
                    is OverlayState.KnownCaller   -> _state.value = cur.copy(isExpanded = true)
                    is OverlayState.PostCall      -> _state.value = cur.copy(isExpanded = true)
                    is OverlayState.UnknownCaller -> _state.value = cur.copy(isExpanded = true)
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
                            emitEffect(OverlaySideEffect.ShowToast("Ticket logged ✓"))
                            // Re-expand main overlay
                            when (val cur = _state.value) {
                                is OverlayState.KnownCaller   -> _state.value = cur.copy(isExpanded = true)
                                is OverlayState.PostCall      -> _state.value = cur.copy(isExpanded = true)
                                is OverlayState.UnknownCaller -> _state.value = cur.copy(isExpanded = true)
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

            // ── Lead submission ───────────────────────────────────────────────

            is OverlayEvent.SubmitLead -> {
                if (event.name.isBlank()) return

                // Accept from UnknownCaller (during call) OR PostCall with Unknown identity (after call)
                val phone: String
                val phase: CallPhase
                when {
                    current is OverlayState.UnknownCaller -> {
                        phone = current.phoneNumber
                        phase = current.callPhase
                    }
                    current is OverlayState.PostCall && current.identity is CallerIdentity.Unknown -> {
                        phone = current.phoneNumber
                        phase = CallPhase.ENDED
                    }
                    else -> return
                }

                _state.value = OverlayState.SubmittingLead(phone, phase)
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
                                callPhase   = phase,
                                isExpanded  = true,
                                activeSheet = ActiveSheet.NONE,
                            )
                            emitEffect(OverlaySideEffect.ShowToast("Lead created: ${identity.name}"))
                            emitEffect(OverlaySideEffect.PipelineRefreshNeeded)
                        },
                        onFailure = { err ->
                            _state.value = OverlayState.UnknownCaller(phone, phase, isExpanded = true)
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
                            emitEffect(OverlaySideEffect.PipelineRefreshNeeded)
                        },
                        onFailure = { err ->
                            _state.value = current.copy(activeSheet = ActiveSheet.OPPORTUNITY)
                            emitEffect(OverlaySideEffect.ShowToast("Failed: ${err.message}"))
                        }
                    )
                }
            }

            // ── Quote submission ──────────────────────────────────────────────

            is OverlayEvent.OpenQuoteForm -> {
                _itemSearchResults.value = emptyList()
                when (current) {
                    is OverlayState.KnownCaller ->
                        _state.value = current.copy(isExpanded = true, activeSheet = ActiveSheet.QUOTE)
                    is OverlayState.PostCall ->
                        _state.value = OverlayState.KnownCaller(
                            phoneNumber = current.phoneNumber,
                            identity    = current.identity,
                            callPhase   = CallPhase.ENDED,
                            isExpanded  = true,
                            activeSheet = ActiveSheet.QUOTE,
                        )
                    else -> {}
                }
            }

            is OverlayEvent.SearchItems -> {
                searchJob?.cancel()
                if (event.query.isBlank()) {
                    _itemSearchResults.value = emptyList()
                    return
                }
                searchJob = scope.launch {
                    val results = runCatching { repository.searchItems(event.query) }.getOrNull()
                    _itemSearchResults.value = results ?: emptyList()
                }
            }

            is OverlayEvent.SubmitQuote -> {
                if (current !is OverlayState.KnownCaller) return
                val identity = current.identity
                if (identity is CallerIdentity.Unknown) return
                if (event.items.isEmpty()) return

                _state.value = OverlayState.SubmittingAction(
                    phoneNumber = current.phoneNumber,
                    identity    = identity,
                    callPhase   = current.callPhase,
                    action      = ActiveSheet.QUOTE,
                )
                activeJob = scope.launch {
                    val result = runCatching {
                        repository.createQuotation(identity, event.items, event.note, event.currency, event.validTill)
                    }
                    result.fold(
                        onSuccess = { docname ->
                            _state.value = OverlayState.KnownCaller(
                                phoneNumber = current.phoneNumber,
                                identity    = identity,
                                callPhase   = current.callPhase,
                                isExpanded  = true,
                                activeSheet = ActiveSheet.NONE,
                            )
                            val msg = if (docname.isNotBlank()) "Quote created: $docname" else "Quote saved"
                            emitEffect(OverlaySideEffect.ShowToast(msg))
                        },
                        onFailure = { err ->
                            _state.value = current.copy(activeSheet = ActiveSheet.QUOTE)
                            emitEffect(OverlaySideEffect.ShowToast("Quote failed: ${err.message}"))
                        }
                    )
                }
            }

            is OverlayEvent.QuoteCreated -> {
                val phone = current.phoneNumber ?: return
                val identity = current.knownIdentity ?: return
                _state.value = OverlayState.KnownCaller(
                    phoneNumber = phone,
                    identity    = identity,
                    callPhase   = current.callPhase ?: CallPhase.ACTIVE,
                    isExpanded  = true,
                )
                emitEffect(OverlaySideEffect.ShowToast("Quote created: ${event.docname}"))
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

            // ── Call logging ──────────────────────────────────────────────────

            is OverlayEvent.SubmitCallLog -> {
                val phone      = current.phoneNumber ?: return
                val identity   = current.knownIdentity ?: CallerIdentity.Unknown
                val duration   = repository.getSessionDuration(phone)
                val direction  = (current as? OverlayState.PostCall)?.direction ?: "Inbound"
                // If CallEnded already auto-logged this call, patch that record
                // with the notes instead of creating a duplicate log.
                val existingRef = (current as? OverlayState.PostCall)?.callLogRef

                // Close the sheet immediately so UI feels responsive
                when (current) {
                    is OverlayState.KnownCaller   -> _state.value = current.copy(activeSheet = ActiveSheet.NONE)
                    is OverlayState.PostCall      -> _state.value = current.copy(activeSheet = ActiveSheet.NONE)
                    is OverlayState.UnknownCaller -> _state.value = current.copy(activeSheet = ActiveSheet.NONE)
                    else -> {}
                }

                scope.launch {
                    val result = runCatching {
                        if (existingRef != null) {
                            repository.updateCallLogNotes(existingRef, event.notes)
                        } else {
                            repository.createCallLog(identity, phone, duration, event.notes, event.callType, direction)
                        }
                    }
                    if (result.isSuccess) {
                        emitEffect(OverlaySideEffect.ShowToast("Call logged ✓"))
                        emitEffect(OverlaySideEffect.CallLogSaved)
                    } else {
                        emitEffect(OverlaySideEffect.ShowToast("Failed to log call: ${result.exceptionOrNull()?.message}"))
                    }
                }
            }

            is OverlayEvent.OpenInApp -> {
                val phone = current.phoneNumber ?: return
                emitEffect(OverlaySideEffect.OpenFlutter("lead_detail", mapOf("phone" to phone)))
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

private fun OverlayState.withCallPhase(phase: CallPhase): OverlayState = when (this) {
    is OverlayState.LoadingIdentity  -> copy(callPhase = phase)
    is OverlayState.UnknownCaller    -> copy(callPhase = phase)
    is OverlayState.SubmittingLead   -> copy(callPhase = phase)
    is OverlayState.KnownCaller      -> copy(callPhase = phase)
    is OverlayState.SubmittingAction -> copy(callPhase = phase)
    else -> this
}
