package com.example.crm_caller_nxtgen.overlay.ui.components

import android.app.DatePickerDialog
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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.OpenInNew
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.RequestQuote
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.IconButton
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
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import java.util.Calendar
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.domain.ActiveSheet
import com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity
import com.example.crm_caller_nxtgen.overlay.domain.CallPhase
import com.example.crm_caller_nxtgen.overlay.domain.ItemSearchResult
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent
import com.example.crm_caller_nxtgen.overlay.domain.QuoteLineItem
import com.example.crm_caller_nxtgen.overlay.domain.displayName

// A single accent (passed in from the card shell, matched to identity type)
// drives every action in this dashboard. Color is reserved for real meaning:
// green = positive/success, red = urgent/destructive. Everything else reads
// as neutral so the surface feels calm rather than a rainbow of buttons.
private val Emerald500 = Color(0xFF10B981)
private val Red500     = Color(0xFFEF4444)
private val Slate400   = Color(0xFF94A3B8)

@Composable
fun KnownContactDashboard(
    identity: CallerIdentity,
    callPhase: CallPhase,
    activeSheet: ActiveSheet,
    accentColor: Color,
    itemSearchResults: List<ItemSearchResult>,
    onEvent: (OverlayEvent) -> Unit,
) {
    val isDark = isSystemInDarkTheme()

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {

        // ── Lead / Customer summary card ──────────────────────────────────────
        LeadSummaryCard(identity, accentColor, isDark, onEvent)

        // ── Call-ended banner ─────────────────────────────────────────────────
        if (callPhase == CallPhase.ENDED) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(Emerald500.copy(alpha = if (isDark) 0.09f else 0.07f))
                    .border(1.dp, Emerald500.copy(alpha = 0.22f), RoundedCornerShape(12.dp))
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
            color         = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.55f),
            fontSize      = 10.sp,
            fontWeight    = FontWeight.Bold,
            letterSpacing = 1.2.sp,
        )

        Row(
            modifier              = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            QuickActionCard(
                label       = "Opportunity",
                icon        = Icons.Default.Star,
                accentColor = accentColor,
                isDark      = isDark,
                modifier    = Modifier.weight(1f),
                onClick     = { onEvent(OverlayEvent.OpenOpportunityForm) },
            )
            QuickActionCard(
                label       = "Add Note",
                icon        = Icons.Default.Edit,
                accentColor = accentColor,
                isDark      = isDark,
                modifier    = Modifier.weight(1f),
                onClick     = { onEvent(OverlayEvent.OpenAddNoteForm) },
            )
            QuickActionCard(
                label       = "Quote",
                icon        = Icons.Default.Receipt,
                accentColor = accentColor,
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
                accentColor = accentColor,
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
                accentColor = accentColor,
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
                identity          = identity,
                accentColor       = accentColor,
                isDark            = isDark,
                searchResults     = itemSearchResults,
                onSearch          = { query -> onEvent(OverlayEvent.SearchItems(query)) },
                onCancel          = { onEvent(OverlayEvent.CancelSheet) },
                onSubmit          = { items, note, currency, validTill ->
                    onEvent(OverlayEvent.SubmitQuote(items, note, currency, validTill))
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
                accentColor = Slate400,
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
    accentColor: Color,
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
                                accentColor = Emerald500,
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
                        .clip(RoundedCornerShape(12.dp))
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.05f else 0.035f))
                        .padding(horizontal = 11.dp, vertical = 9.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text          = "LAST NOTE",
                        color         = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.55f),
                        fontSize      = 9.sp,
                        fontWeight    = FontWeight.Bold,
                        letterSpacing = 0.8.sp,
                    )
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
                    else                   -> accentColor
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
                    .background(accentColor)
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
private fun AddNoteInlineForm(accentColor: Color, isDark: Boolean, onCancel: () -> Unit, onSubmit: (String) -> Unit) {
    var note by remember { mutableStateOf("") }
    val fc = darkFieldColors(accentColor)
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
                containerColor         = accentColor,
                disabledContainerColor = accentColor.copy(alpha = 0.30f),
            ),
            shape = RoundedCornerShape(10.dp),
        ) { Text("Save Note", color = Color.White, fontWeight = FontWeight.Bold) }
    }
}

@Composable
private fun OpportunityForm(accentColor: Color, isDark: Boolean, onCancel: () -> Unit, onSubmit: (Double, String, String) -> Unit) {
    var expectedValue by remember { mutableStateOf("") }
    var stage         by remember { mutableStateOf("Prospecting") }
    var note          by remember { mutableStateOf("") }
    val stages = listOf("Prospecting", "Qualification", "Proposal", "Negotiation", "Closed Won")
    val fc = darkFieldColors(accentColor)

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
                        accentColor = accentColor,
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
                containerColor         = accentColor,
                disabledContainerColor = accentColor.copy(alpha = 0.30f),
            ),
            shape = RoundedCornerShape(10.dp),
        ) { Text("Save Opportunity", fontWeight = FontWeight.Bold, color = Color.White) }
    }
}

// One editable line on the quotation being drafted. Plain mutableStateOf
// fields (not a data class) so editing one row only recomposes that row.
private class QuoteItemDraft(
    itemCode: String = "",
    itemName: String = "",
    qty: String = "1",
    rate: String = "",
) {
    var itemCode by mutableStateOf(itemCode)
    var itemName by mutableStateOf(itemName)
    var qty      by mutableStateOf(qty)
    var rate     by mutableStateOf(rate)
    val amount: Double get() = (qty.toDoubleOrNull() ?: 0.0) * (rate.toDoubleOrNull() ?: 0.0)
}

private fun formatMoney(v: Double): String =
    if (v == v.toLong().toDouble()) "%,d".format(v.toLong()) else "%,.2f".format(v)

private val CURRENCIES = listOf("USD", "LKR", "EUR", "GBP", "INR")

@Composable
private fun QuoteForm(
    identity: CallerIdentity,
    accentColor: Color,
    isDark: Boolean,
    searchResults: List<ItemSearchResult>,
    onSearch: (String) -> Unit,
    onCancel: () -> Unit,
    onSubmit: (List<QuoteLineItem>, String, String, String) -> Unit,
) {
    val quotationTo = if (identity is CallerIdentity.Customer) "Customer" else "Lead"
    val docname = when (identity) {
        is CallerIdentity.Lead     -> identity.docname
        is CallerIdentity.Customer -> identity.docname
        else -> ""
    }
    val company = when (identity) {
        is CallerIdentity.Lead     -> identity.company
        is CallerIdentity.Customer -> identity.company
        else -> ""
    }

    val context = LocalContext.current
    val items = remember { mutableStateListOf(QuoteItemDraft()) }
    var note      by remember { mutableStateOf("") }
    var currency  by remember { mutableStateOf("USD") }
    var validTill by remember { mutableStateOf("") }
    // Which row's search dropdown is currently open (identity-compared)
    var activeRow by remember { mutableStateOf<QuoteItemDraft?>(null) }
    val fc = darkFieldColors(accentColor)

    val validItems = items.filter { it.itemCode.isNotBlank() && (it.qty.toDoubleOrNull() ?: 0.0) > 0 }
    val totalQty   = validItems.sumOf { it.qty.toDoubleOrNull() ?: 0.0 }
    val grandTotal = validItems.sumOf { it.amount }

    fun pickValidTill() {
        val cal = Calendar.getInstance()
        DatePickerDialog(
            context,
            { _, year, month, day ->
                validTill = "%04d-%02d-%02d".format(year, month + 1, day)
            },
            cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH),
        ).show()
    }

    InlineFormCard(isDark) {
        FormHeader("Create Quotation", onCancel)

        // ── Quotation To / Party / Company — read-only context strip ─────────
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(accentColor.copy(alpha = if (isDark) 0.08f else 0.05f))
                .padding(horizontal = 11.dp, vertical = 9.dp),
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            InfoLine(label = "Quotation To", value = quotationTo, accentColor = accentColor)
            InfoLine(label = quotationTo, value = identity.displayName.ifBlank { docname }, accentColor = accentColor)
            if (company.isNotBlank()) {
                InfoLine(label = "Company", value = company, accentColor = accentColor)
            }
        }

        // ── Currency + Valid Till ──────────────────────────────────────────────
        Text(
            text          = "CURRENCY",
            color         = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.55f),
            fontSize      = 10.sp,
            fontWeight    = FontWeight.Bold,
            letterSpacing = 1.sp,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            CURRENCIES.forEach { code ->
                SelectChip(
                    text        = code,
                    isSelected  = currency == code,
                    accentColor = accentColor,
                    modifier    = Modifier.weight(1f),
                    onClick     = { currency = code },
                )
            }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .clickable { pickValidTill() }
                .padding(horizontal = 12.dp, vertical = 12.dp),
            verticalAlignment     = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(Icons.Default.CalendarToday, contentDescription = null, tint = accentColor, modifier = Modifier.size(15.dp))
            Column {
                Text("Valid Till", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                Text(
                    text  = validTill.ifBlank { "Tap to set an expiry date" },
                    color = if (validTill.isBlank()) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                    fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                )
            }
        }

        // ── Items — table-style like the desk Quotation form ───────────────────
        Text(
            text          = "ITEMS",
            color         = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.55f),
            fontSize      = 10.sp,
            fontWeight    = FontWeight.Bold,
            letterSpacing = 1.sp,
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .border(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.09f else 0.07f), RoundedCornerShape(12.dp)),
        ) {
            // Column header row: No. | Item Code | Qty | Rate (CUR) | Amount (CUR)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(horizontal = 10.dp, vertical = 7.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                TableHeaderCell("No.",              Modifier.width(20.dp))
                TableHeaderCell("Item Code",        Modifier.weight(1f))
                TableHeaderCell("Qty",              Modifier.width(48.dp))
                TableHeaderCell("Rate ($currency)", Modifier.width(70.dp))
                TableHeaderCell("Amount ($currency)", Modifier.width(74.dp))
            }

            items.forEachIndexed { index, draft ->
                if (index > 0) HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.06f else 0.05f))
                QuoteItemRow(
                    rowNumber     = index + 1,
                    draft         = draft,
                    accentColor   = accentColor,
                    fieldColors   = fc,
                    searchResults = if (activeRow === draft) searchResults else emptyList(),
                    onQueryChange = { q -> activeRow = draft; onSearch(q) },
                    onPick        = { result ->
                        draft.itemCode = result.itemCode
                        draft.itemName = result.itemName
                        if (result.rate > 0) draft.rate = formatMoney(result.rate)
                        activeRow = null
                    },
                    onRemove      = if (items.size > 1) ({ items.removeAt(index) }) else null,
                )
            }
        }

        TextButton(onClick = { items.add(QuoteItemDraft()) }) {
            Icon(Icons.Default.Add, contentDescription = null, tint = accentColor, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(4.dp))
            Text("Add Item", color = accentColor, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
        }

        HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.08f else 0.06f))

        // ── Totals ─────────────────────────────────────────────────────────────
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("Total Quantity", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 12.sp)
            Text(formatMoney(totalQty), color = MaterialTheme.colorScheme.onSurface, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        }
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("Total ($currency)", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 12.sp)
            Text(formatMoney(grandTotal), color = MaterialTheme.colorScheme.onSurface, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        }
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("Grand Total", color = MaterialTheme.colorScheme.onSurface, fontSize = 14.sp, fontWeight = FontWeight.Bold)
            Text("$currency ${formatMoney(grandTotal)}", color = accentColor, fontSize = 16.sp, fontWeight = FontWeight.ExtraBold)
        }

        OutlinedTextField(
            value         = note,
            onValueChange = { note = it },
            label         = { Text("Note (optional)") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fc,
            shape         = RoundedCornerShape(10.dp),
            maxLines      = 2,
        )

        Button(
            onClick  = {
                val lineItems = validItems.map {
                    QuoteLineItem(
                        itemCode = it.itemCode.trim(),
                        itemName = it.itemName.ifBlank { it.itemCode }.trim(),
                        qty      = it.qty.toDoubleOrNull() ?: 1.0,
                        rate     = it.rate.toDoubleOrNull() ?: 0.0,
                    )
                }
                onSubmit(lineItems, note.trim(), currency, validTill)
            },
            modifier = Modifier.fillMaxWidth().height(46.dp),
            enabled  = validItems.isNotEmpty(),
            colors   = ButtonDefaults.buttonColors(
                containerColor         = accentColor,
                disabledContainerColor = accentColor.copy(alpha = 0.30f),
            ),
            shape = RoundedCornerShape(10.dp),
        ) {
            Icon(Icons.Default.Receipt, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text("Send Quote", color = Color.White, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun InfoLine(label: String, value: String, accentColor: Color) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text       = label.uppercase(),
            color      = accentColor,
            fontSize   = 9.sp,
            fontWeight = FontWeight.ExtraBold,
            letterSpacing = 0.6.sp,
            modifier   = Modifier.width(78.dp),
        )
        Text(
            text       = value,
            color      = MaterialTheme.colorScheme.onSurface,
            fontSize   = 12.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines   = 1,
            overflow   = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun CompactCellField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    BasicTextField(
        value           = value,
        onValueChange   = onValueChange,
        modifier        = modifier
            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(6.dp))
            .padding(horizontal = 6.dp, vertical = 6.dp),
        textStyle       = TextStyle(color = MaterialTheme.colorScheme.onSurface, fontSize = 12.sp),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        singleLine      = true,
        cursorBrush     = SolidColor(MaterialTheme.colorScheme.primary),
    )
}

@Composable
private fun TableHeaderCell(text: String, modifier: Modifier = Modifier) {
    Text(
        text          = text,
        modifier      = modifier,
        color         = MaterialTheme.colorScheme.onSurfaceVariant,
        fontSize      = 9.sp,
        fontWeight    = FontWeight.Bold,
        letterSpacing = 0.3.sp,
        maxLines      = 1,
        overflow      = TextOverflow.Ellipsis,
    )
}

@Composable
private fun QuoteItemRow(
    rowNumber: Int,
    draft: QuoteItemDraft,
    accentColor: Color,
    fieldColors: androidx.compose.material3.TextFieldColors,
    searchResults: List<ItemSearchResult>,
    onQueryChange: (String) -> Unit,
    onPick: (ItemSearchResult) -> Unit,
    onRemove: (() -> Unit)?,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        // ── Table row: No. | Qty | Rate | Amount | Remove ─────────────────────
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                text     = "$rowNumber",
                color    = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 12.sp,
                modifier = Modifier.width(20.dp),
            )
            CompactCellField(
                value       = draft.qty,
                onValueChange = { if (it.isEmpty() || it.toDoubleOrNull() != null) draft.qty = it },
                modifier    = Modifier.width(48.dp),
            )
            CompactCellField(
                value       = draft.rate,
                onValueChange = { if (it.isEmpty() || it.toDoubleOrNull() != null) draft.rate = it },
                modifier    = Modifier.width(70.dp),
            )
            Box(modifier = Modifier.width(74.dp)) {
                Text(
                    text       = formatMoney(draft.amount),
                    color      = accentColor,
                    fontSize   = 13.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines   = 1,
                    overflow   = TextOverflow.Ellipsis,
                )
            }
            if (onRemove != null) {
                IconButton(onClick = onRemove, modifier = Modifier.size(22.dp)) {
                    Icon(Icons.Default.Close, contentDescription = "Remove item",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(14.dp))
                }
            }
        }

        // ── Item code — full width so search/typing is comfortable ───────────
        OutlinedTextField(
            value         = draft.itemCode,
            onValueChange = { draft.itemCode = it; onQueryChange(it) },
            label         = { Text("Item Code") },
            placeholder   = { Text(draft.itemName.ifBlank { "Search item…" }, fontSize = 12.sp) },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors,
            shape         = RoundedCornerShape(10.dp),
            singleLine    = true,
        )

        // Inline search suggestions
        if (searchResults.isNotEmpty()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .border(1.dp, accentColor.copy(alpha = 0.25f), RoundedCornerShape(10.dp)),
            ) {
                searchResults.take(5).forEach { result ->
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onPick(result) }
                            .padding(horizontal = 10.dp, vertical = 8.dp),
                    ) {
                        Text(result.itemCode, color = MaterialTheme.colorScheme.onSurface, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        Text(
                            text  = if (result.rate > 0) "${result.itemName} · ${formatMoney(result.rate)}" else result.itemName,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontSize = 11.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
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
