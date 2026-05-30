package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.OpenInNew
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.RequestQuote
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.domain.ActiveSheet
import com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity
import com.example.crm_caller_nxtgen.overlay.domain.CallPhase
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent
import com.example.crm_caller_nxtgen.overlay.domain.displayName

private val Indigo400  = Color(0xFF818CF8)
private val Indigo500  = Color(0xFF6366F1)
private val Indigo600  = Color(0xFF4F46E5)
private val Blue400    = Color(0xFF60A5FA)
private val Blue500    = Color(0xFF3B82F6)
private val Emerald400 = Color(0xFF34D399)
private val Emerald500 = Color(0xFF10B981)
private val Amber500   = Color(0xFFF59E0B)
private val Amber400   = Color(0xFFFBBF24)
private val Red500     = Color(0xFFEF4444)
private val Violet500  = Color(0xFF8B5CF6)

@Composable
fun KnownContactDashboard(
    identity: CallerIdentity,
    callPhase: CallPhase,
    activeSheet: ActiveSheet,
    onEvent: (OverlayEvent) -> Unit,
) {
    val isDark = isSystemInDarkTheme()

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {

        // ── Lead / Customer summary card ──────────────────────────────────────
        LeadSummaryCard(identity, isDark, onEvent)

        // ── Call-ended banner ─────────────────────────────────────────────────
        if (callPhase == CallPhase.ENDED) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Emerald500.copy(alpha = if (isDark) 0.09f else 0.07f))
                    .border(1.dp, Emerald500.copy(alpha = 0.25f), RoundedCornerShape(10.dp))
                    .padding(horizontal = 12.dp, vertical = 9.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .clip(CircleShape)
                        .background(Emerald500),
                )
                Text(
                    text       = "Call ended — actions still available",
                    color      = Emerald500,
                    fontSize   = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }

        // ── Quick actions ─────────────────────────────────────────────────────
        Text(
            text          = "QUICK ACTIONS",
            color         = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.50f),
            fontSize      = 10.sp,
            fontWeight    = FontWeight.ExtraBold,
            letterSpacing = 1.2.sp,
        )

        Row(
            modifier              = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            QuickActionCard(
                label       = "Opportunity",
                icon        = Icons.Default.Star,
                accentColor = Indigo500,
                isDark      = isDark,
                modifier    = Modifier.weight(1f),
                onClick     = { onEvent(OverlayEvent.OpenOpportunityForm) },
            )
            QuickActionCard(
                label       = "Add Note",
                icon        = Icons.Default.Edit,
                accentColor = Emerald500,
                isDark      = isDark,
                modifier    = Modifier.weight(1f),
                onClick     = { onEvent(OverlayEvent.OpenAddNoteForm) },
            )
            QuickActionCard(
                label       = "Quote",
                icon        = Icons.Default.Receipt,
                accentColor = Amber500,
                isDark      = isDark,
                modifier    = Modifier.weight(1f),
                onClick     = { onEvent(OverlayEvent.OpenQuoteForm) },
            )
        }

        // ── Inline forms ──────────────────────────────────────────────────────
        AnimatedVisibility(
            visible = activeSheet == ActiveSheet.OPPORTUNITY,
            enter   = fadeIn(tween(120)),
            exit    = fadeOut(tween(120)),
        ) {
            OpportunityForm(
                isDark   = isDark,
                onCancel = { onEvent(OverlayEvent.CancelSheet) },
                onSubmit = { value, stage, note ->
                    onEvent(OverlayEvent.SubmitOpportunity(value, stage, note))
                },
            )
        }

        AnimatedVisibility(
            visible = activeSheet == ActiveSheet.ADD_NOTE,
            enter   = fadeIn(tween(120)),
            exit    = fadeOut(tween(120)),
        ) {
            AddNoteInlineForm(
                isDark   = isDark,
                onCancel = { onEvent(OverlayEvent.CancelSheet) },
                onSubmit = { note -> onEvent(OverlayEvent.SubmitNote(note)) },
            )
        }

        AnimatedVisibility(
            visible = activeSheet == ActiveSheet.QUOTE,
            enter   = fadeIn(tween(120)),
            exit    = fadeOut(tween(120)),
        ) {
            QuoteForm(
                callerName = identity.displayName,
                isDark     = isDark,
                onCancel   = { onEvent(OverlayEvent.CancelSheet) },
                onSubmit   = { subject, amount, note ->
                    onEvent(OverlayEvent.SubmitQuote(subject, amount, note))
                },
            )
        }

        AnimatedVisibility(
            visible = activeSheet == ActiveSheet.LOG_CALL,
            enter   = fadeIn(tween(120)),
            exit    = fadeOut(tween(120)),
        ) {
            LogCallInlineForm(
                isDark     = isDark,
                isWhatsApp = false,
                onCancel   = { onEvent(OverlayEvent.CancelSheet) },
                onSubmit   = { notes, callType -> onEvent(OverlayEvent.SubmitCallLog(notes, callType)) },
            )
        }

        // ── Divider + secondary actions ───────────────────────────────────────
        HorizontalDivider(
            color     = MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.08f else 0.06f),
            thickness = 1.dp,
        )

        Row(
            modifier              = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            SecondaryActionButton(
                label       = "Log Ticket",
                icon        = Icons.Default.Warning,
                accentColor = Red500,
                modifier    = Modifier.weight(1f),
                onClick     = { onEvent(OverlayEvent.OpenComplaintPopup) },
            )
            SecondaryActionButton(
                label       = "Log Call",
                icon        = Icons.Default.Phone,
                accentColor = Blue500,
                modifier    = Modifier.weight(1f),
                onClick     = { onEvent(OverlayEvent.OpenLogCallForm) },
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lead / Customer summary card
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun LeadSummaryCard(
    identity: CallerIdentity,
    isDark: Boolean,
    onEvent: (OverlayEvent) -> Unit,
) {
    if (identity is CallerIdentity.Unknown) return

    val email = when (identity) {
        is CallerIdentity.Lead     -> identity.email
        is CallerIdentity.Customer -> identity.email
        else -> ""
    }
    val phone = when (identity) {
        is CallerIdentity.Lead     -> identity.phone
        is CallerIdentity.Customer -> identity.phone
        else -> ""
    }
    val company = when (identity) {
        is CallerIdentity.Lead     -> identity.company
        is CallerIdentity.Customer -> identity.company
        else -> ""
    }
    val latestNote = when (identity) {
        is CallerIdentity.Lead     -> identity.latestNote
        is CallerIdentity.Customer -> identity.latestNote
        else -> ""
    }
    val latestQuoteSubject = when (identity) {
        is CallerIdentity.Lead     -> identity.latestQuoteSubject
        is CallerIdentity.Customer -> identity.latestQuoteSubject
        else -> ""
    }
    val latestQuoteAmount = when (identity) {
        is CallerIdentity.Lead     -> identity.latestQuoteAmount
        is CallerIdentity.Customer -> identity.latestQuoteAmount
        else -> 0.0
    }
    val latestQuoteStatus = when (identity) {
        is CallerIdentity.Lead     -> identity.latestQuoteStatus
        is CallerIdentity.Customer -> identity.latestQuoteStatus
        else -> ""
    }
    val status = when (identity) {
        is CallerIdentity.Lead     -> identity.status
        is CallerIdentity.Customer -> "Customer"
        else -> ""
    }
    val hasOpportunity = identity is CallerIdentity.Lead && identity.hasOpportunity
    val isCustomer     = identity is CallerIdentity.Customer || (identity is CallerIdentity.Lead && identity.isCustomer)

    val accentColor = when {
        isCustomer     -> Emerald500
        hasOpportunity -> Indigo500
        else           -> Blue500
    }

    val initials = buildInitialsFromName(identity.displayName)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .border(
                1.dp,
                MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.10f else 0.07f),
                RoundedCornerShape(18.dp),
            ),
    ) {
        // ── Header: avatar + name + status chips ──────────────────────────────
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.verticalGradient(
                        listOf(
                            accentColor.copy(alpha = if (isDark) 0.13f else 0.07f),
                            accentColor.copy(alpha = 0f),
                        )
                    )
                )
                .padding(horizontal = 14.dp, vertical = 14.dp),
        ) {
            Row(
                verticalAlignment     = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Avatar
                Box(
                    modifier = Modifier
                        .size(46.dp)
                        .clip(CircleShape)
                        .background(accentColor.copy(alpha = if (isDark) 0.22f else 0.14f))
                        .border(1.5.dp, accentColor.copy(alpha = 0.40f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text       = initials,
                        color      = accentColor,
                        fontSize   = if (initials.length == 1) 19.sp else 15.sp,
                        fontWeight = FontWeight.ExtraBold,
                    )
                }

                Column(
                    modifier            = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    Text(
                        text       = identity.displayName,
                        color      = MaterialTheme.colorScheme.onSurface,
                        fontSize   = 15.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines   = 1,
                        overflow   = TextOverflow.Ellipsis,
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        StatusPill(
                            label       = status.ifBlank { "Lead" }.uppercase(),
                            accentColor = accentColor,
                        )
                        if (hasOpportunity) {
                            StatusPill(
                                label       = "OPPORTUNITY",
                                accentColor = Violet500,
                            )
                        }
                    }
                }
            }
        }

        // ── Contact details ───────────────────────────────────────────────────
        Column(
            modifier            = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(7.dp),
        ) {
            if (company.isNotBlank()) {
                DetailRow(icon = Icons.Default.Business, text = company, isDark = isDark)
            }
            if (phone.isNotBlank()) {
                DetailRow(icon = Icons.Default.Phone, text = phone, isDark = isDark)
            }
            if (email.isNotBlank()) {
                DetailRow(icon = Icons.Default.Email, text = email, isDark = isDark)
            }

            // ── Last note ─────────────────────────────────────────────────────
            if (latestNote.isNotBlank()) {
                Spacer(Modifier.height(2.dp))
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(Amber500.copy(alpha = if (isDark) 0.09f else 0.06f))
                        .border(1.dp, Amber500.copy(alpha = 0.28f), RoundedCornerShape(10.dp))
                        .padding(horizontal = 11.dp, vertical = 9.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Row(
                        verticalAlignment     = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(5.dp),
                    ) {
                        Box(
                            modifier = Modifier
                                .size(5.dp)
                                .clip(CircleShape)
                                .background(Amber500),
                        )
                        Text(
                            text          = "LAST NOTE",
                            color         = Amber500,
                            fontSize      = 9.sp,
                            fontWeight    = FontWeight.ExtraBold,
                            letterSpacing = 0.8.sp,
                        )
                    }
                    Text(
                        text       = latestNote,
                        color      = MaterialTheme.colorScheme.onSurface,
                        fontSize   = 12.sp,
                        maxLines   = 3,
                        lineHeight = 17.sp,
                        overflow   = TextOverflow.Ellipsis,
                    )
                }
            }

            // ── Last quote ────────────────────────────────────────────────────
            if (latestQuoteSubject.isNotBlank() || latestQuoteAmount > 0.0) {
                Spacer(Modifier.height(2.dp))
                val quoteColor = when (latestQuoteStatus.lowercase()) {
                    "submitted", "ordered" -> Emerald500
                    "cancelled"            -> Red500
                    else                   -> Blue400
                }
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(quoteColor.copy(alpha = if (isDark) 0.09f else 0.06f))
                        .border(1.dp, quoteColor.copy(alpha = 0.28f), RoundedCornerShape(10.dp))
                        .padding(horizontal = 11.dp, vertical = 9.dp),
                    verticalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    Row(
                        verticalAlignment     = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(5.dp),
                    ) {
                        Icon(
                            imageVector        = Icons.Default.RequestQuote,
                            contentDescription = null,
                            tint               = quoteColor,
                            modifier           = Modifier.size(10.dp),
                        )
                        Text(
                            text          = "LAST QUOTE",
                            color         = quoteColor,
                            fontSize      = 9.sp,
                            fontWeight    = FontWeight.ExtraBold,
                            letterSpacing = 0.8.sp,
                        )
                        if (latestQuoteStatus.isNotBlank()) {
                            Spacer(Modifier.weight(1f))
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(5.dp))
                                    .background(quoteColor.copy(alpha = 0.15f))
                                    .padding(horizontal = 5.dp, vertical = 2.dp),
                            ) {
                                Text(
                                    text          = latestQuoteStatus.uppercase(),
                                    color         = quoteColor,
                                    fontSize      = 8.sp,
                                    fontWeight    = FontWeight.ExtraBold,
                                    letterSpacing = 0.5.sp,
                                )
                            }
                        }
                    }
                    if (latestQuoteSubject.isNotBlank()) {
                        Text(
                            text       = latestQuoteSubject,
                            color      = MaterialTheme.colorScheme.onSurface,
                            fontSize   = 12.sp,
                            maxLines   = 1,
                            overflow   = TextOverflow.Ellipsis,
                        )
                    }
                    if (latestQuoteAmount > 0.0) {
                        Text(
                            text       = "Value: %.2f".format(latestQuoteAmount),
                            color      = quoteColor,
                            fontSize   = 13.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }

            Spacer(Modifier.height(2.dp))

            // ── Open in App button ────────────────────────────────────────────
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(
                        Brush.horizontalGradient(listOf(Indigo600, Indigo400))
                    )
                    .clickable { onEvent(OverlayEvent.OpenInApp) },
                contentAlignment = Alignment.Center,
            ) {
                Row(
                    verticalAlignment     = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(7.dp),
                ) {
                    Icon(
                        imageVector        = Icons.Default.OpenInNew,
                        contentDescription = null,
                        tint               = Color.White,
                        modifier           = Modifier.size(15.dp),
                    )
                    Text(
                        text       = "Open Full Profile in App",
                        color      = Color.White,
                        fontSize   = 13.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Icon(
                        imageVector        = Icons.Default.ArrowForward,
                        contentDescription = null,
                        tint               = Color.White.copy(alpha = 0.70f),
                        modifier           = Modifier.size(13.dp),
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Micro-components
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun StatusPill(label: String, accentColor: Color) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(accentColor.copy(alpha = 0.15f))
            .border(1.dp, accentColor.copy(alpha = 0.30f), RoundedCornerShape(6.dp))
            .padding(horizontal = 7.dp, vertical = 3.dp),
    ) {
        Text(
            text          = label,
            color         = accentColor,
            fontSize      = 9.sp,
            fontWeight    = FontWeight.ExtraBold,
            letterSpacing = 0.5.sp,
        )
    }
}

@Composable
private fun DetailRow(icon: ImageVector, text: String, isDark: Boolean) {
    Row(
        verticalAlignment     = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            modifier = Modifier
                .size(24.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.07f else 0.05f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector        = icon,
                contentDescription = null,
                tint               = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier           = Modifier.size(13.dp),
            )
        }
        Text(
            text     = text,
            color    = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 12.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun SecondaryActionButton(
    label: String,
    icon: ImageVector,
    accentColor: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier
            .height(42.dp)
            .clip(RoundedCornerShape(12.dp))
            .border(1.dp, accentColor.copy(alpha = 0.30f), RoundedCornerShape(12.dp))
            .background(accentColor.copy(alpha = 0.06f))
            .clickable { onClick() },
        contentAlignment = Alignment.Center,
    ) {
        Row(
            verticalAlignment     = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            Icon(icon, null, tint = accentColor, modifier = Modifier.size(14.dp))
            Spacer(Modifier.width(5.dp))
            Text(label, color = accentColor, fontWeight = FontWeight.SemiBold, fontSize = 12.sp, maxLines = 1)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action cards row
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun QuickActionCard(
    label: String,
    icon: ImageVector,
    accentColor: Color,
    isDark: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(
                Brush.verticalGradient(
                    listOf(
                        accentColor.copy(alpha = if (isDark) 0.14f else 0.08f),
                        accentColor.copy(alpha = if (isDark) 0.06f else 0.03f),
                    )
                )
            )
            .border(1.dp, accentColor.copy(alpha = if (isDark) 0.28f else 0.20f), RoundedCornerShape(14.dp))
            .clickable { onClick() }
            .padding(vertical = 14.dp, horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(accentColor.copy(alpha = if (isDark) 0.22f else 0.13f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = accentColor, modifier = Modifier.size(19.dp))
        }
        Text(
            text          = label,
            color         = accentColor,
            fontSize      = 10.sp,
            fontWeight    = FontWeight.ExtraBold,
            letterSpacing = 0.3.sp,
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline forms (unchanged logic, consistent styling)
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun AddNoteInlineForm(isDark: Boolean, onCancel: () -> Unit, onSubmit: (String) -> Unit) {
    var note by remember { mutableStateOf("") }
    val fc = darkFieldColors(Emerald500)
    InlineFormCard(isDark) {
        FormHeader("Add Note", onCancel)
        OutlinedTextField(
            value         = note,
            onValueChange = { note = it },
            label         = { Text("Note") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fc,
            shape         = RoundedCornerShape(10.dp),
            maxLines      = 4,
            minLines      = 3,
        )
        Button(
            onClick  = { onSubmit(note.trim()) },
            modifier = Modifier.fillMaxWidth().height(46.dp),
            enabled  = note.isNotBlank(),
            colors   = ButtonDefaults.buttonColors(
                containerColor         = Emerald500,
                disabledContainerColor = Emerald500.copy(alpha = 0.30f),
            ),
            shape = RoundedCornerShape(10.dp),
        ) { Text("Save Note", color = Color.White, fontWeight = FontWeight.Bold) }
    }
}

@Composable
private fun OpportunityForm(isDark: Boolean, onCancel: () -> Unit, onSubmit: (Double, String, String) -> Unit) {
    var expectedValue by remember { mutableStateOf("") }
    var stage         by remember { mutableStateOf("Prospecting") }
    var note          by remember { mutableStateOf("") }
    val stages = listOf("Prospecting", "Qualification", "Proposal", "Negotiation", "Closed Won")
    val fc = darkFieldColors(Blue400)

    InlineFormCard(isDark) {
        FormHeader("Create Opportunity", onCancel)
        OutlinedTextField(
            value         = expectedValue,
            onValueChange = { if (it.isEmpty() || it.toDoubleOrNull() != null) expectedValue = it },
            label         = { Text("Expected value") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fc,
            shape         = RoundedCornerShape(10.dp),
            singleLine    = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        )
        Text(
            text          = "STAGE",
            color         = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.50f),
            fontSize      = 10.sp,
            fontWeight    = FontWeight.ExtraBold,
            letterSpacing = 1.sp,
        )
        stages.chunked(3).forEach { rowStages ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                rowStages.forEach { s ->
                    SelectChip(
                        text        = s,
                        isSelected  = stage == s,
                        accentColor = Blue400,
                        modifier    = Modifier.weight(1f),
                        onClick     = { stage = s },
                    )
                }
                repeat(3 - rowStages.size) { Spacer(Modifier.weight(1f)) }
            }
        }
        OutlinedTextField(
            value         = note,
            onValueChange = { note = it },
            label         = { Text("Note") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fc,
            shape         = RoundedCornerShape(10.dp),
            maxLines      = 2,
        )
        Button(
            onClick  = { onSubmit(expectedValue.toDoubleOrNull() ?: 0.0, stage, note.trim()) },
            modifier = Modifier.fillMaxWidth().height(46.dp),
            enabled  = expectedValue.isNotBlank(),
            colors   = ButtonDefaults.buttonColors(
                containerColor         = Blue400,
                disabledContainerColor = Blue400.copy(alpha = 0.30f),
            ),
            shape = RoundedCornerShape(10.dp),
        ) { Text("Save Opportunity", fontWeight = FontWeight.Bold, color = Color.White) }
    }
}

@Composable
private fun QuoteForm(
    callerName: String,
    isDark: Boolean,
    onCancel: () -> Unit,
    onSubmit: (String, Double, String) -> Unit,
) {
    var subject by remember { mutableStateOf(callerName) }
    var amount  by remember { mutableStateOf("") }
    var note    by remember { mutableStateOf("") }
    val fc = darkFieldColors(Amber500)

    InlineFormCard(isDark) {
        FormHeader("Create Quotation", onCancel)
        OutlinedTextField(
            value         = subject,
            onValueChange = { subject = it },
            label         = { Text("Subject *") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fc,
            shape         = RoundedCornerShape(10.dp),
            singleLine    = true,
        )
        OutlinedTextField(
            value         = amount,
            onValueChange = { if (it.isEmpty() || it.toDoubleOrNull() != null) amount = it },
            label         = { Text("Amount") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fc,
            shape         = RoundedCornerShape(10.dp),
            singleLine    = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        )
        OutlinedTextField(
            value         = note,
            onValueChange = { note = it },
            label         = { Text("Note") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fc,
            shape         = RoundedCornerShape(10.dp),
            maxLines      = 3,
            minLines      = 2,
        )
        Button(
            onClick  = { onSubmit(subject.trim(), amount.toDoubleOrNull() ?: 0.0, note.trim()) },
            modifier = Modifier.fillMaxWidth().height(46.dp),
            enabled  = subject.isNotBlank(),
            colors   = ButtonDefaults.buttonColors(
                containerColor         = Amber500,
                disabledContainerColor = Amber500.copy(alpha = 0.30f),
            ),
            shape = RoundedCornerShape(10.dp),
        ) {
            Icon(Icons.Default.Receipt, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text("Send Quote", color = Color.White, fontWeight = FontWeight.Bold)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun InlineFormCard(isDark: Boolean, content: @Composable () -> Unit) {
    Column(
        verticalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(
                1.dp,
                MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.09f else 0.07f),
                RoundedCornerShape(14.dp),
            )
            .padding(14.dp),
    ) { content() }
}

@Composable
private fun FormHeader(title: String, onCancel: () -> Unit) {
    Row(
        modifier              = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment     = Alignment.CenterVertically,
    ) {
        Text(
            text       = title,
            color      = MaterialTheme.colorScheme.onSurface,
            fontSize   = 14.sp,
            fontWeight = FontWeight.Bold,
        )
        TextButton(onClick = onCancel) {
            Text(
                "Cancel",
                color    = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.65f),
                fontSize = 12.sp,
            )
        }
    }
}

@Composable
private fun SelectChip(
    text: String,
    isSelected: Boolean,
    accentColor: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(
                if (isSelected) accentColor.copy(alpha = 0.14f)
                else MaterialTheme.colorScheme.surfaceVariant,
            )
            .border(
                width = if (isSelected) 1.5.dp else 1.dp,
                color = if (isSelected) accentColor
                        else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                shape = RoundedCornerShape(8.dp),
            )
            .clickable { onClick() }
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text       = text,
            color      = if (isSelected) accentColor else MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize   = 11.sp,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
        )
    }
}

private fun buildInitialsFromName(name: String): String {
    val parts = name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
    return when {
        parts.isEmpty()  -> "?"
        parts.size == 1  -> parts[0].take(1).uppercase()
        else             -> "${parts[0][0]}${parts[1][0]}".uppercase()
    }
}
