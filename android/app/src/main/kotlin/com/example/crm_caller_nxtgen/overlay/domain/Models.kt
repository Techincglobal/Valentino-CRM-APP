package com.example.crm_caller_nxtgen.overlay.domain

import java.util.UUID

// ─────────────────────────────────────────────────────────────────────────────
// QUOTATION LINE ITEMS
// ─────────────────────────────────────────────────────────────────────────────

/** A catalogue item returned by the item search API. */
data class ItemSearchResult(
    val itemCode: String,
    val itemName: String,
    val rate: Double,
)

/** One line on a quotation being built in the overlay. */
data class QuoteLineItem(
    val itemCode: String,
    val itemName: String,
    val qty: Double,
    val rate: Double,
) {
    val amount: Double get() = qty * rate
}

/**
 * Points at a Mobile Call Log record that was auto-created the instant a call
 * ended — [localId] is the Room primary key (always present), [frappeDocname]
 * is set once/if the immediate network sync succeeded (empty otherwise, in
 * which case SyncWorker will eventually push the local row).
 */
data class CallLogRef(
    val localId: String,
    val frappeDocname: String = "",
)

// ─────────────────────────────────────────────────────────────────────────────
// CALLER IDENTITY
// Who is on the other end of the call.
// ─────────────────────────────────────────────────────────────────────────────

sealed class CallerIdentity {

    /** Phone rang but no match in CRM. */
    object Unknown : CallerIdentity()

    /** Phone matched a Lead in Frappe. */
    data class Lead(
        val docname: String,         // Frappe docname: "CRM-LEAD-2024-00042" (empty if not yet synced)
        val localId: String,         // local Room UUID — primary key until synced
        val name: String,
        val company: String,
        val email: String = "",
        val phone: String,
        val status: String = "Lead", // "New", "Lead", "Interested", "Converted", "Customer", "Supplier", "Contact"
        val hasOpportunity: Boolean = false,
        val isCustomer: Boolean = false,
        val isSupplier: Boolean = false,
        val latestNote: String = "",         // most recent note from Frappe — shown on incoming call
        val latestQuoteSubject: String = "", // most recent quotation subject
        val latestQuoteAmount: Double = 0.0, // most recent quotation grand total
        val latestQuoteStatus: String = "",  // "Draft", "Submitted", etc.
    ) : CallerIdentity()

    /** Phone matched a Customer in Frappe. */
    data class Customer(
        val docname: String,
        val leadDocname: String,     // original lead — kept for opportunity/complaint linkage
        val name: String,
        val company: String,
        val email: String = "",
        val phone: String,
        val latestNote: String = "",         // most recent note from Frappe — shown on incoming call
        val latestQuoteSubject: String = "",
        val latestQuoteAmount: Double = 0.0,
        val latestQuoteStatus: String = "",
    ) : CallerIdentity()
}

// Helpers — avoid when/is everywhere in UI
val CallerIdentity.displayName: String
    get() = when (this) {
        is CallerIdentity.Unknown  -> "Unknown Caller"
        is CallerIdentity.Lead     -> name
        is CallerIdentity.Customer -> name
    }

val CallerIdentity.displayCompany: String
    get() = when (this) {
        is CallerIdentity.Unknown  -> ""
        is CallerIdentity.Lead     -> company
        is CallerIdentity.Customer -> company
    }

val CallerIdentity.displayPhone: String
    get() = when (this) {
        is CallerIdentity.Unknown  -> ""
        is CallerIdentity.Lead     -> phone
        is CallerIdentity.Customer -> phone
    }

val CallerIdentity.displayEmail: String
    get() = when (this) {
        is CallerIdentity.Unknown  -> ""
        is CallerIdentity.Lead     -> email
        is CallerIdentity.Customer -> email
    }

/** The Frappe docname to attach opportunities/complaints to. Null = offline/unsynced */
val CallerIdentity.linkedDocname: String?
    get() = when (this) {
        is CallerIdentity.Unknown  -> null
        is CallerIdentity.Lead     -> docname.ifBlank { null }
        is CallerIdentity.Customer -> leadDocname.ifBlank { null }
    }

val CallerIdentity.isKnown: Boolean
    get() = this !is CallerIdentity.Unknown

// ─────────────────────────────────────────────────────────────────────────────
// CALL PHASE
// ─────────────────────────────────────────────────────────────────────────────

enum class CallPhase { RINGING, ACTIVE, ENDED }

// ─────────────────────────────────────────────────────────────────────────────
// OVERLAY STATE  (single source of truth for all overlay UI)
// All states carry enough data to render without external lookups.
// ─────────────────────────────────────────────────────────────────────────────

sealed class OverlayState {

    /** Service running, window hidden. */
    object Idle : OverlayState()

    /** DB/network lookup in progress — show spinner bubble. */
    data class LoadingIdentity(
        val phoneNumber: String,
        val callPhase: CallPhase = CallPhase.RINGING,
    ) : OverlayState()

    /** Unknown caller — mini bubble shows "Unknown", expanded shows create-lead form. */
    data class UnknownCaller(
        val phoneNumber: String,
        val callPhase: CallPhase = CallPhase.RINGING,
        val isExpanded: Boolean = false,
        val activeSheet: ActiveSheet = ActiveSheet.NONE,
        // Set once "Add to Contacts" succeeds — lets the call log this call
        // produces link to that Contact instead of staying unlinked.
        val linkedContactDocname: String? = null,
    ) : OverlayState()

    /** Lead form is being submitted. Input locked. */
    data class SubmittingLead(
        val phoneNumber: String,
        val callPhase: CallPhase,
    ) : OverlayState()

    /** Known caller (lead or customer). Full CRM interaction available. */
    data class KnownCaller(
        val phoneNumber: String,
        val identity: CallerIdentity,
        val callPhase: CallPhase = CallPhase.RINGING,
        val isExpanded: Boolean = false,
        val activeSheet: ActiveSheet = ActiveSheet.NONE,
    ) : OverlayState()

    /** Opportunity or note form is submitting. */
    data class SubmittingAction(
        val phoneNumber: String,
        val identity: CallerIdentity,
        val callPhase: CallPhase,
        val action: ActiveSheet,
        val isExpanded: Boolean = true,
    ) : OverlayState()

    /** Call ended — overlay stays until user explicitly closes. */
    data class PostCall(
        val phoneNumber: String,
        val identity: CallerIdentity,
        val durationSeconds: Long,
        val isExpanded: Boolean = false,
        val activeSheet: ActiveSheet = ActiveSheet.NONE,
        val direction: String = "Inbound",
        // Set once the call has been auto-logged (see OverlayStateMachine.CallEnded).
        // The "add a note" form patches this record rather than creating a new one.
        val callLogRef: CallLogRef? = null,
        // Carried over from UnknownCaller if "Add to Contacts" was used mid-call —
        // lets createCallLog link the record to that Contact.
        val linkedContactDocname: String? = null,
    ) : OverlayState()
}

enum class ActiveSheet { NONE, OPPORTUNITY, ADD_LEAD, ADD_NOTE, QUOTE, LOG_CALL }

// ─────────────────────────────────────────────────────────────────────────────
// COMPLAINT POPUP STATE  (second WindowManager window)
// ─────────────────────────────────────────────────────────────────────────────

sealed class ComplaintPopupState {
    object Hidden : ComplaintPopupState()
    data class Visible(
        val identity: CallerIdentity,
        val phoneNumber: String,
    ) : ComplaintPopupState()
    data class Submitting(
        val identity: CallerIdentity,
        val phoneNumber: String,
    ) : ComplaintPopupState()
}

// Convenience: is the overlay currently visible (window should be shown)?
val OverlayState.shouldShowWindow: Boolean
    get() = this !is OverlayState.Idle

// Convenience: should the window be focusable (keyboard needed)?
val OverlayState.needsFocus: Boolean
    get() = when (this) {
        is OverlayState.UnknownCaller    -> isExpanded
        is OverlayState.KnownCaller      -> isExpanded
        is OverlayState.SubmittingAction -> true
        is OverlayState.PostCall         -> isExpanded
        else -> false
    }

val OverlayState.isExpanded: Boolean
    get() = when (this) {
        is OverlayState.UnknownCaller    -> isExpanded
        is OverlayState.KnownCaller      -> isExpanded
        is OverlayState.SubmittingAction -> true
        is OverlayState.SubmittingLead   -> true
        is OverlayState.PostCall         -> isExpanded
        else -> false
    }

val OverlayState.activeSheetOrNone: ActiveSheet
    get() = when (this) {
        is OverlayState.UnknownCaller -> activeSheet
        is OverlayState.KnownCaller   -> activeSheet
        is OverlayState.PostCall      -> activeSheet
        else                          -> ActiveSheet.NONE
    }

// ─────────────────────────────────────────────────────────────────────────────
// OVERLAY EVENTS
// ─────────────────────────────────────────────────────────────────────────────

sealed class OverlayEvent {

    // Phone OS
    data class CallRinging(val phoneNumber: String) : OverlayEvent()
    // Overlay opened manually from within the app (e.g. tapping a Lead in the
    // pipeline) with an already-known identity — skips the phone-number
    // lookup entirely instead of re-resolving and risking a false "Unknown".
    data class ShowKnownIdentity(val phoneNumber: String, val identity: CallerIdentity) : OverlayEvent()
    object CallAnswered : OverlayEvent()
    /** User tapped "Answer" on the overlay while the phone is ringing. */
    object AnswerCall : OverlayEvent()
    // phone/direction let the state machine log the call even when no overlay
    // was ever shown (e.g. outbound calls, or state already reset to Idle).
    data class CallEnded(
        val direction: String = "Inbound",
        val phone: String = "",
        // "Answered" / "Missed" / "Rejected" / "No Answer" — read from the
        // system's own CallLog entry (see queryLatestSystemCallStatus), since
        // TelephonyManager's RINGING/OFFHOOK/IDLE transitions alone can't
        // reliably distinguish these (notably: OFFHOOK fires for an outgoing
        // call the instant it's dialed, regardless of whether the far end
        // ever actually answers).
        val status: String = "Answered",
    ) : OverlayEvent()

    // Backend results
    data class IdentityResolved(val identity: CallerIdentity) : OverlayEvent()
    object IdentityNotFound : OverlayEvent()

    // UI — expand/collapse/dismiss
    object ToggleExpand : OverlayEvent()
    object DismissOverlay : OverlayEvent()
    object PostCallDismissed : OverlayEvent()  // kept as no-op for backward compat

    // Lead creation (unknown caller)
    data class SubmitLead(
        val name: String,
        val email: String,
        val company: String,
        val note: String,
    ) : OverlayEvent()
    data class LeadCreated(val identity: CallerIdentity.Lead) : OverlayEvent()
    data class LeadFailed(val reason: String) : OverlayEvent()

    // Contact creation (unknown caller) — lighter-weight than a Lead: just
    // identifies the caller and links them to this call's log.
    data class SubmitContact(
        val name: String,
        val email: String,
        val company: String,
        val note: String,
    ) : OverlayEvent()
    data class ContactCreated(val docname: String) : OverlayEvent()
    data class ContactFailed(val reason: String) : OverlayEvent()

    // Supplier creation (unknown caller calling as a vendor/supplier)
    data class SubmitSupplier(
        val name: String,
        val email: String,
    ) : OverlayEvent()
    data class SupplierCreated(val docname: String) : OverlayEvent()
    data class SupplierFailed(val reason: String) : OverlayEvent()

    // Opportunity
    object OpenOpportunityForm : OverlayEvent()
    data class SubmitOpportunity(
        val expectedValue: Double,
        val stage: String,
        val note: String = "",
    ) : OverlayEvent()
    data class OpportunityCreated(val updatedIdentity: CallerIdentity) : OverlayEvent()
    data class ActionFailed(val reason: String) : OverlayEvent()

    // Additional lead (known caller creating a new lead from same call)
    object OpenAddLeadForm : OverlayEvent()

    // Note
    object OpenAddNoteForm : OverlayEvent()
    data class SubmitNote(val content: String) : OverlayEvent()

    // Complaint popup (separate window)
    object OpenComplaintPopup : OverlayEvent()
    object CloseComplaintPopup : OverlayEvent()
    data class SubmitComplaint(
        val category: String,
        val details: String,
        val priority: String,
    ) : OverlayEvent()
    object ComplaintCreated : OverlayEvent()

    // Quotation
    object OpenQuoteForm : OverlayEvent()
    data class SearchItems(val query: String) : OverlayEvent()
    data class SubmitQuote(
        val items: List<QuoteLineItem>,
        val note: String = "",
        val currency: String = "",
        val validTill: String = "",
    ) : OverlayEvent()
    data class QuoteCreated(val docname: String) : OverlayEvent()

    // Call logging
    data class SubmitCallLog(
        val notes: String,
        val callType: String = "Regular",
    ) : OverlayEvent()

    // Cancel sub-form
    object CancelSheet : OverlayEvent()

    // Launch the Flutter app and navigate to the caller's profile
    object OpenInApp : OverlayEvent()

    // Legacy complaint sheet event — kept for no-op backward compat
    object OpenComplaintForm : OverlayEvent()
}

// ─────────────────────────────────────────────────────────────────────────────
// OVERLAY SESSION  (runtime data for ONE call)
// ─────────────────────────────────────────────────────────────────────────────

data class OverlaySession(
    val sessionId: String = UUID.randomUUID().toString(),
    val phoneNumber: String,
    val startedAt: Long = System.currentTimeMillis(),
    var callAnsweredAt: Long? = null,
    var callEndedAt: Long? = null,
) {
    val durationSeconds: Long
        get() {
            val start = callAnsweredAt ?: startedAt
            val end   = callEndedAt   ?: System.currentTimeMillis()
            return maxOf(0L, (end - start) / 1000L)
        }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDE EFFECTS  (one-shot commands from FSM → service)
// ─────────────────────────────────────────────────────────────────────────────

sealed class OverlaySideEffect {
    data class ShowToast(val message: String) : OverlaySideEffect()
    object DismissWindow : OverlaySideEffect()
    object Vibrate : OverlaySideEffect()
    data class OpenFlutter(val route: String, val args: Map<String, String> = emptyMap()) : OverlaySideEffect()
    /** Show the complaint popup (second WindowManager window). */
    object ShowComplaintPopup : OverlaySideEffect()
    /** Hide the complaint popup. */
    object HideComplaintPopup : OverlaySideEffect()
    /** Legacy — kept as no-op so old references compile. */
    object CancelAutoDismiss : OverlaySideEffect()
    /** Notify Flutter to refresh the CRM pipeline tab (lead or opportunity created). */
    object PipelineRefreshNeeded : OverlaySideEffect()
    /** Notify Flutter to refresh the Call Logs tab. */
    object CallLogSaved : OverlaySideEffect()
    /** Answer the ringing call via TelecomManager. */
    object AnswerCall : OverlaySideEffect()
}
