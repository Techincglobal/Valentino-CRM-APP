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
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.domain.ActiveSheet
import com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity
import com.example.crm_caller_nxtgen.overlay.domain.CallPhase
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent
import com.example.crm_caller_nxtgen.overlay.domain.displayName

private val Indigo500  = Color(0xFF6366F1)
private val Blue400    = Color(0xFF60A5FA)
private val Blue500    = Color(0xFF3B82F6)
private val Emerald500 = Color(0xFF10B981)
private val Amber500   = Color(0xFFF59E0B)
private val Red500     = Color(0xFFEF4444)

@Composable
fun KnownContactDashboard(
    identity: CallerIdentity,
    callPhase: CallPhase,
    activeSheet: ActiveSheet,
    onEvent: (OverlayEvent) -> Unit,
) {
    val isDark = isSystemInDarkTheme()

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {

        ContactReadOnlyCard(identity, isDark)

        // Call-ended banner
        if (callPhase == CallPhase.ENDED) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Emerald500.copy(alpha = if (isDark) 0.08f else 0.06f))
                    .border(1.dp, Emerald500.copy(alpha = 0.22f), RoundedCornerShape(10.dp))
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

        // Quick actions header
        Text(
            text          = "QUICK ACTIONS",
            color         = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.55f),
            fontSize      = 10.sp,
            fontWeight    = FontWeight.ExtraBold,
            letterSpacing = 1.2.sp,
        )

        // Action cards
        Row(
            modifier              = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            QuickActionCard(
                label       = "Opportunity",
                icon        = Icons.Default.CheckCircle,
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

        // Inline expanded forms
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

        HorizontalDivider(
            color     = MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.08f else 0.06f),
            thickness = 1.dp,
        )

        // Secondary action row: Log a Ticket + Log Call
        Row(
            modifier              = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            OutlinedButton(
                onClick  = { onEvent(OverlayEvent.OpenComplaintPopup) },
                modifier = Modifier.weight(1f).height(44.dp),
                colors   = ButtonDefaults.outlinedButtonColors(contentColor = Red500),
                border   = androidx.compose.foundation.BorderStroke(1.dp, Red500.copy(alpha = 0.35f)),
                shape    = RoundedCornerShape(12.dp),
            ) {
                Icon(Icons.Default.Warning, null, tint = Red500, modifier = Modifier.size(15.dp))
                Spacer(Modifier.width(6.dp))
                Text("Log a Ticket", color = Red500, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
            }
            OutlinedButton(
                onClick  = { onEvent(OverlayEvent.OpenLogCallForm) },
                modifier = Modifier.weight(1f).height(44.dp),
                colors   = ButtonDefaults.outlinedButtonColors(contentColor = Blue500),
                border   = androidx.compose.foundation.BorderStroke(1.dp, Blue500.copy(alpha = 0.35f)),
                shape    = RoundedCornerShape(12.dp),
            ) {
                Icon(Icons.Default.Phone, null, tint = Blue500, modifier = Modifier.size(15.dp))
                Spacer(Modifier.width(6.dp))
                Text("Log Call", color = Blue500, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
            }
        }

        // Status chips
        if (identity is CallerIdentity.Lead && identity.hasOpportunity) {
            StatusChip("Opportunity on record", Indigo500)
        }
        if (identity is CallerIdentity.Customer) {
            StatusChip("Converted Customer", Emerald500)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contact info card
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun ContactReadOnlyCard(identity: CallerIdentity, isDark: Boolean) {
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
    val latestNote = when (identity) {
        is CallerIdentity.Lead     -> identity.latestNote
        is CallerIdentity.Customer -> identity.latestNote
        else -> ""
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .border(
                1.dp,
                MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.08f else 0.06f),
                RoundedCornerShape(16.dp),
            )
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // Name row
        Text(
            text       = identity.displayName,
            color      = MaterialTheme.colorScheme.onSurface,
            fontSize   = 16.sp,
            fontWeight = FontWeight.Bold,
        )

        // Contact detail rows
        if (phone.isNotBlank()) {
            Row(
                verticalAlignment     = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(
                    imageVector        = Icons.Default.Phone,
                    contentDescription = null,
                    tint               = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier           = Modifier.size(13.dp),
                )
                Text(
                    text     = phone,
                    color    = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 12.sp,
                )
            }
        }
        if (email.isNotBlank()) {
            Row(
                verticalAlignment     = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(
                    imageVector        = Icons.Default.Email,
                    contentDescription = null,
                    tint               = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier           = Modifier.size(13.dp),
                )
                Text(
                    text     = email,
                    color    = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 12.sp,
                    maxLines = 1,
                )
            }
        }

        // Last note amber banner
        if (latestNote.isNotBlank()) {
            HorizontalDivider(
                color     = MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.07f else 0.05f),
                thickness = 1.dp,
            )
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Amber500.copy(alpha = if (isDark) 0.08f else 0.05f))
                    .border(1.dp, Amber500.copy(alpha = 0.25f), RoundedCornerShape(10.dp))
                    .padding(horizontal = 11.dp, vertical = 9.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text          = "LAST NOTE",
                    color         = Amber500,
                    fontSize      = 9.sp,
                    fontWeight    = FontWeight.ExtraBold,
                    letterSpacing = 0.8.sp,
                )
                Text(
                    text       = latestNote,
                    color      = MaterialTheme.colorScheme.onSurface,
                    fontSize   = 12.sp,
                    maxLines   = 3,
                    lineHeight = 17.sp,
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline forms
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun AddNoteInlineForm(isDark: Boolean, onCancel: () -> Unit, onSubmit: (String) -> Unit) {
    var note by remember { mutableStateOf("") }
    val fc = darkFieldColors(Emerald500)
    Column(
        verticalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.08f else 0.06f), RoundedCornerShape(14.dp))
            .padding(14.dp),
    ) {
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

    Column(
        verticalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.08f else 0.06f), RoundedCornerShape(14.dp))
            .padding(14.dp),
    ) {
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
            color         = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.55f),
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
            label         = { Text("Note (optional)") },
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

    Column(
        verticalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.08f else 0.06f), RoundedCornerShape(14.dp))
            .padding(14.dp),
    ) {
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
            label         = { Text("Note (optional)") },
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
// Shared micro-components
// ─────────────────────────────────────────────────────────────────────────────

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
private fun StatusChip(label: String, accentColor: Color) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(accentColor.copy(alpha = 0.10f))
            .border(1.dp, accentColor.copy(alpha = 0.25f), RoundedCornerShape(8.dp))
            .padding(horizontal = 10.dp, vertical = 5.dp),
    ) {
        Text(label, color = accentColor, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
    }
}

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
                        accentColor.copy(alpha = if (isDark) 0.12f else 0.07f),
                        accentColor.copy(alpha = if (isDark) 0.06f else 0.03f),
                    )
                )
            )
            .border(1.dp, accentColor.copy(alpha = if (isDark) 0.25f else 0.18f), RoundedCornerShape(14.dp))
            .clickable { onClick() }
            .padding(vertical = 14.dp, horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(accentColor.copy(alpha = if (isDark) 0.20f else 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = accentColor, modifier = Modifier.size(19.dp))
        }
        Text(
            text       = label,
            color      = accentColor,
            fontSize   = 10.sp,
            fontWeight = FontWeight.ExtraBold,
            letterSpacing = 0.3.sp,
        )
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
