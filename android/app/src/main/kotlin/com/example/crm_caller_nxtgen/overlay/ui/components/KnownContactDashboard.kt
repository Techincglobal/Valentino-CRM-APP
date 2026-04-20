package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
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

// ─────────────────────────────────────────────────────────────────────────────
// Light palette
// ─────────────────────────────────────────────────────────────────────────────
private val Indigo500     = Color(0xFF6366F1)
private val Blue400       = Color(0xFF60A5FA)
private val Emerald500    = Color(0xFF10B981)
private val Amber500      = Color(0xFFF59E0B)
private val Red500        = Color(0xFFEF4444)
private val TextPrimary   = Color(0xFF0F172A)
private val TextSecondary = Color(0xFF64748B)
private val TextMuted     = Color(0xFF94A3B8)
private val BorderLight   = Color(0xFFE2E8F0)
private val SurfaceLight  = Color(0xFFF8FAFC)
private val White         = Color(0xFFFFFFFF)

@Composable
fun KnownContactDashboard(
    identity: CallerIdentity,
    callPhase: CallPhase,
    activeSheet: ActiveSheet,
    isRecording: Boolean,
    onEvent: (OverlayEvent) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {

        // Read-only contact card
        ContactReadOnlyCard(identity)

        // Call-ended banner
        if (callPhase == CallPhase.ENDED) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color(0xFFF0FDF4))
                    .border(1.dp, Color(0xFF86EFAC), RoundedCornerShape(10.dp))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            ) {
                Text(
                    text       = "Call ended — you can still take actions below",
                    color      = Emerald500,
                    fontSize   = 11.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }

        // Quick Actions label
        Text(
            text          = "QUICK ACTIONS",
            color         = TextMuted,
            fontSize      = 10.sp,
            fontWeight    = FontWeight.Bold,
            letterSpacing = 1.sp,
        )

        // Quick action row: Opportunity | Note | Quote
        Row(
            modifier              = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            QuickActionCard(
                label       = "Opportunity",
                icon        = Icons.Default.CheckCircle,
                accentColor = Indigo500,
                modifier    = Modifier.weight(1f),
                onClick     = { onEvent(OverlayEvent.OpenOpportunityForm) },
            )
            QuickActionCard(
                label       = "Add Note",
                icon        = Icons.Default.Edit,
                accentColor = Emerald500,
                modifier    = Modifier.weight(1f),
                onClick     = { onEvent(OverlayEvent.OpenAddNoteForm) },
            )
            QuickActionCard(
                label       = "Quote",
                icon        = Icons.Default.Receipt,
                accentColor = Amber500,
                modifier    = Modifier.weight(1f),
                onClick     = { onEvent(OverlayEvent.OpenQuoteForm) },
            )
        }

        // Inline expanded forms
        AnimatedVisibility(
            visible = activeSheet == ActiveSheet.OPPORTUNITY,
            enter   = expandVertically() + fadeIn(),
            exit    = shrinkVertically() + fadeOut(),
        ) {
            OpportunityForm(
                onCancel = { onEvent(OverlayEvent.CancelSheet) },
                onSubmit = { value, stage, note ->
                    onEvent(OverlayEvent.SubmitOpportunity(value, stage, note))
                },
            )
        }

        AnimatedVisibility(
            visible = activeSheet == ActiveSheet.ADD_NOTE,
            enter   = expandVertically() + fadeIn(),
            exit    = shrinkVertically() + fadeOut(),
        ) {
            AddNoteInlineForm(
                onCancel = { onEvent(OverlayEvent.CancelSheet) },
                onSubmit = { note -> onEvent(OverlayEvent.SubmitNote(note)) },
            )
        }

        AnimatedVisibility(
            visible = activeSheet == ActiveSheet.QUOTE,
            enter   = expandVertically() + fadeIn(),
            exit    = shrinkVertically() + fadeOut(),
        ) {
            QuoteForm(
                callerName = identity.displayName,
                onCancel   = { onEvent(OverlayEvent.CancelSheet) },
                onSubmit   = { subject, amount, note ->
                    onEvent(OverlayEvent.SubmitQuote(subject, amount, note))
                },
            )
        }

        HorizontalDivider(color = BorderLight, thickness = 1.dp)

        // Record toggle
        RecordToggleButton(
            isRecording = isRecording,
            onClick     = { onEvent(OverlayEvent.ToggleRecording) },
        )

        // Log Complaint
        OutlinedButton(
            onClick  = { onEvent(OverlayEvent.OpenComplaintPopup) },
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .border(1.dp, Red500.copy(alpha = 0.45f), RoundedCornerShape(12.dp)),
            colors = ButtonDefaults.outlinedButtonColors(contentColor = Red500),
            shape  = RoundedCornerShape(12.dp),
        ) {
            Icon(
                imageVector        = Icons.Default.Warning,
                contentDescription = null,
                tint               = Red500,
                modifier           = Modifier.size(16.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text       = "Log Complaint",
                color      = Red500,
                fontWeight = FontWeight.SemiBold,
                fontSize   = 13.sp,
            )
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
// Read-only contact card
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun ContactReadOnlyCard(identity: CallerIdentity) {
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

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(SurfaceLight)
            .border(1.dp, BorderLight, RoundedCornerShape(14.dp))
            .padding(14.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Row(
                modifier              = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment     = Alignment.CenterVertically,
            ) {
                Text(
                    text       = identity.displayName,
                    color      = TextPrimary,
                    fontSize   = 15.sp,
                    fontWeight = FontWeight.Bold,
                    modifier   = Modifier.weight(1f),
                )
                Row(
                    verticalAlignment     = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    Icon(
                        imageVector        = Icons.Default.Lock,
                        contentDescription = null,
                        tint               = TextMuted,
                        modifier           = Modifier.size(11.dp),
                    )
                    Text("Edit in app", color = TextMuted, fontSize = 10.sp)
                }
            }
            if (email.isNotBlank()) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Email", color = TextMuted, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                    Text(email, color = TextSecondary, fontSize = 11.sp)
                }
            }
            if (phone.isNotBlank()) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Phone", color = TextMuted, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                    Text(phone, color = TextSecondary, fontSize = 11.sp)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline forms
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun AddNoteInlineForm(onCancel: () -> Unit, onSubmit: (String) -> Unit) {
    var note by remember { mutableStateOf("") }
    val fc = lightFieldColors(Emerald500)
    Column(
        verticalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(SurfaceLight)
            .border(1.dp, BorderLight, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        FormHeader("Add Note", onCancel)
        OutlinedTextField(value = note, onValueChange = { note = it }, label = { Text("Note") },
            modifier = Modifier.fillMaxWidth(), colors = fc, shape = RoundedCornerShape(10.dp),
            maxLines = 4, minLines = 3)
        Button(
            onClick  = { onSubmit(note.trim()) },
            modifier = Modifier.fillMaxWidth().height(46.dp),
            enabled  = note.isNotBlank(),
            colors   = ButtonDefaults.buttonColors(
                containerColor = Emerald500,
                disabledContainerColor = Emerald500.copy(alpha = 0.35f),
            ),
            shape = RoundedCornerShape(10.dp),
        ) { Text("Save Note", color = Color.White, fontWeight = FontWeight.Bold) }
    }
}

@Composable
private fun OpportunityForm(onCancel: () -> Unit, onSubmit: (Double, String, String) -> Unit) {
    var expectedValue by remember { mutableStateOf("") }
    var stage         by remember { mutableStateOf("Prospecting") }
    var note          by remember { mutableStateOf("") }
    val stages = listOf("Prospecting", "Qualification", "Proposal", "Negotiation", "Closed Won")
    val fc = lightFieldColors(Blue400)

    Column(
        verticalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(SurfaceLight)
            .border(1.dp, BorderLight, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        FormHeader("Create Opportunity", onCancel)
        OutlinedTextField(
            value = expectedValue,
            onValueChange = { if (it.isEmpty() || it.toDoubleOrNull() != null) expectedValue = it },
            label = { Text("Expected value (Rs.)") },
            modifier = Modifier.fillMaxWidth(), colors = fc, shape = RoundedCornerShape(10.dp),
            singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
        Text("Stage", color = TextMuted, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.5.sp)
        stages.chunked(3).forEach { rowStages ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                rowStages.forEach { s ->
                    SelectChip(text = s, isSelected = stage == s, accentColor = Blue400,
                        modifier = Modifier.weight(1f), onClick = { stage = s })
                }
                repeat(3 - rowStages.size) { Spacer(Modifier.weight(1f)) }
            }
        }
        OutlinedTextField(value = note, onValueChange = { note = it }, label = { Text("Note") },
            modifier = Modifier.fillMaxWidth(), colors = fc, shape = RoundedCornerShape(10.dp), maxLines = 2)
        Button(
            onClick  = { onSubmit(expectedValue.toDoubleOrNull() ?: 0.0, stage, note.trim()) },
            modifier = Modifier.fillMaxWidth().height(46.dp),
            enabled  = expectedValue.isNotBlank(),
            colors   = ButtonDefaults.buttonColors(
                containerColor = Blue400,
                disabledContainerColor = Blue400.copy(alpha = 0.35f),
            ),
            shape = RoundedCornerShape(10.dp),
        ) { Text("Save Opportunity", fontWeight = FontWeight.Bold, color = Color.White) }
    }
}

@Composable
private fun QuoteForm(
    callerName: String,
    onCancel: () -> Unit,
    onSubmit: (String, Double, String) -> Unit,
) {
    var subject by remember { mutableStateOf(callerName) }
    var amount  by remember { mutableStateOf("") }
    var note    by remember { mutableStateOf("") }
    val fc = lightFieldColors(Amber500)

    Column(
        verticalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(SurfaceLight)
            .border(1.dp, BorderLight, RoundedCornerShape(12.dp))
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
            label         = { Text("Amount (Rs.)") },
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
                disabledContainerColor = Amber500.copy(alpha = 0.35f),
            ),
            shape = RoundedCornerShape(10.dp),
        ) {
            Icon(
                imageVector        = Icons.Default.Receipt,
                contentDescription = null,
                tint               = Color.White,
                modifier           = Modifier.size(16.dp),
            )
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
        Text(title, color = TextPrimary, fontSize = 14.sp, fontWeight = FontWeight.Bold)
        TextButton(onClick = onCancel) {
            Text("Cancel", color = TextMuted, fontSize = 12.sp)
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
            .padding(horizontal = 10.dp, vertical = 4.dp),
    ) {
        Text(label, color = accentColor, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun QuickActionCard(
    label: String,
    icon: ImageVector,
    accentColor: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(accentColor.copy(alpha = 0.07f))
            .border(1.dp, accentColor.copy(alpha = 0.25f), RoundedCornerShape(12.dp))
            .clickable { onClick() }
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(accentColor.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = accentColor, modifier = Modifier.size(18.dp))
            }
            Text(label, color = accentColor, fontSize = 10.sp, fontWeight = FontWeight.Bold)
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
            .background(if (isSelected) accentColor.copy(alpha = 0.12f) else White)
            .border(
                width = if (isSelected) 1.5.dp else 1.dp,
                color = if (isSelected) accentColor else BorderLight,
                shape = RoundedCornerShape(8.dp),
            )
            .clickable { onClick() }
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text       = text,
            color      = if (isSelected) accentColor else TextSecondary,
            fontSize   = 11.sp,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
        )
    }
}

@Composable
private fun lightFieldColors(accent: Color) = OutlinedTextFieldDefaults.colors(
    focusedBorderColor      = accent,
    unfocusedBorderColor    = BorderLight,
    focusedTextColor        = TextPrimary,
    unfocusedTextColor      = TextPrimary,
    disabledTextColor       = TextMuted,
    disabledBorderColor     = BorderLight,
    disabledLabelColor      = TextMuted,
    focusedLabelColor       = accent,
    unfocusedLabelColor     = TextSecondary,
    cursorColor             = accent,
    focusedContainerColor   = White,
    unfocusedContainerColor = White,
    disabledContainerColor  = SurfaceLight,
)

// displayName is defined publicly in Models.kt
