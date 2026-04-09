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
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Edit
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

// ─────────────────────────────────────────────────────────────────────────────
// Colour palette (keep consistent with OverlayTheme)
// ─────────────────────────────────────────────────────────────────────────────

private val Indigo500  = Color(0xFF6366F1)
private val Blue400    = Color(0xFF38BDF8)
private val Emerald400 = Color(0xFF10B981)
private val Red400     = Color(0xFFEF4444)
private val Amber400   = Color(0xFFFBBF24)
private val Slate700   = Color(0xFFF1F5F9) // Slate 100
private val Slate400   = Color(0xFF64748B) // Slate 500
private val SlateText  = Color(0xFF0F172A) // Slate 900

// ─────────────────────────────────────────────────────────────────────────────
// KnownContactDashboard
//
// activeSheet == NONE        → main dashboard (contact card + action row)
// activeSheet == OPPORTUNITY → inline opportunity form (AnimatedVisibility)
// activeSheet == ADD_LEAD    → inline simplified new-lead form
// activeSheet == ADD_NOTE    → inline quick note form
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun KnownContactDashboard(
    identity: CallerIdentity,
    callPhase: CallPhase,
    activeSheet: ActiveSheet,
    isRecording: Boolean,
    onEvent: (OverlayEvent) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {

        // ── Read-only contact card ────────────────────────────────────────────
        ContactReadOnlyCard(identity)

        // ── Call-ended banner ─────────────────────────────────────────────────
        if (callPhase == CallPhase.ENDED) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(Slate700)
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            ) {
                Text(
                    text       = "Call ended · You can still take actions below",
                    color      = Slate400,
                    fontSize   = 11.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }

        // ── Quick action row ──────────────────────────────────────────────────
        Text("Quick Actions", color = Slate400, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.8.sp)

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            QuickActionCard(
                label       = "Opportunity",
                icon        = Icons.Default.Add,
                accentColor = Indigo500,
                modifier    = Modifier.weight(1f),
                onClick     = { onEvent(OverlayEvent.OpenOpportunityForm) },
            )
            QuickActionCard(
                label       = "New Lead",
                icon        = Icons.Default.Add,
                accentColor = Blue400,
                modifier    = Modifier.weight(1f),
                onClick     = { onEvent(OverlayEvent.OpenAddLeadForm) },
            )
            QuickActionCard(
                label       = "Add Note",
                icon        = Icons.Default.Edit,
                accentColor = Emerald400,
                modifier    = Modifier.weight(1f),
                onClick     = { onEvent(OverlayEvent.OpenAddNoteForm) },
            )
        }

        // ── Inline expanded forms (AnimatedVisibility) ────────────────────────
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
            visible = activeSheet == ActiveSheet.ADD_LEAD,
            enter   = expandVertically() + fadeIn(),
            exit    = shrinkVertically() + fadeOut(),
        ) {
            AddLeadInlineForm(
                phone    = identity.displayPhoneInline,
                onCancel = { onEvent(OverlayEvent.CancelSheet) },
                onSubmit = { name, email, company, note ->
                    onEvent(OverlayEvent.SubmitLead(name, email, company, note))
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

        HorizontalDivider(color = Slate700, thickness = 0.5.dp)

        // ── Record call toggle ────────────────────────────────────────────────
        RecordToggleButton(
            isRecording = isRecording,
            onClick     = { onEvent(OverlayEvent.ToggleRecording) },
        )

        // ── Complaint button (full width, red) ────────────────────────────────
        OutlinedButton(
            onClick  = { onEvent(OverlayEvent.OpenComplaintPopup) },
            modifier = Modifier.fillMaxWidth().height(46.dp),
            colors   = ButtonDefaults.outlinedButtonColors(contentColor = Red400),
            shape    = RoundedCornerShape(10.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector        = Icons.Default.Warning,
                    contentDescription = null,
                    tint               = Red400,
                    modifier           = Modifier.size(16.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text("Log Complaint", color = Red400, fontWeight = FontWeight.SemiBold)
            }
        }

        // ── Status chips ──────────────────────────────────────────────────────
        if (identity is CallerIdentity.Lead && identity.hasOpportunity) {
            StatusChip("Opportunity on record", Blue400)
        }
        if (identity is CallerIdentity.Customer) {
            StatusChip("Converted Customer — opportunities still available", Emerald400)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Read-only contact card — name, email, phone cannot be edited in overlay
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
            .clip(RoundedCornerShape(12.dp))
            .background(Slate700.copy(alpha = 0.6f))
            .border(0.5.dp, Slate700, RoundedCornerShape(12.dp))
            .padding(12.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text       = identity.displayName,
                    color      = SlateText,
                    fontSize   = 15.sp,
                    fontWeight = FontWeight.Bold,
                    modifier   = Modifier.weight(1f),
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector        = Icons.Default.Lock,
                        contentDescription = null,
                        tint               = Slate400,
                        modifier           = Modifier.size(12.dp),
                    )
                    Spacer(Modifier.width(4.dp))
                    Text("Edit in app", color = Slate400, fontSize = 10.sp)
                }
            }
            if (email.isNotBlank()) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Email", color = Slate400, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                    Text(email, color = SlateText, fontSize = 11.sp)
                }
            }
            if (phone.isNotBlank()) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Phone", color = Slate400, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                    Text(phone, color = SlateText, fontSize = 11.sp)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline new-lead form (for known callers creating an additional lead)
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun AddLeadInlineForm(
    phone: String,
    onCancel: () -> Unit,
    onSubmit: (String, String, String, String) -> Unit,
) {
    var name    by remember { mutableStateOf("") }
    var email   by remember { mutableStateOf("") }
    var company by remember { mutableStateOf("") }
    var note    by remember { mutableStateOf("") }

    val fieldColors = fieldColorScheme(Indigo500)

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        FormHeader("Create Lead", onCancel)

        OutlinedTextField(
            value = phone, onValueChange = {}, label = { Text("Phone") },
            enabled = false, modifier = Modifier.fillMaxWidth(),
            colors = fieldColors, shape = RoundedCornerShape(10.dp), singleLine = true,
        )
        OutlinedTextField(
            value = name, onValueChange = { name = it }, label = { Text("Full name *") },
            modifier = Modifier.fillMaxWidth(), colors = fieldColors,
            shape = RoundedCornerShape(10.dp), singleLine = true,
        )
        OutlinedTextField(
            value = email, onValueChange = { email = it }, label = { Text("Email") },
            modifier = Modifier.fillMaxWidth(), colors = fieldColors,
            shape = RoundedCornerShape(10.dp), singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
        )
        OutlinedTextField(
            value = company, onValueChange = { company = it }, label = { Text("Company") },
            modifier = Modifier.fillMaxWidth(), colors = fieldColors,
            shape = RoundedCornerShape(10.dp), singleLine = true,
        )
        OutlinedTextField(
            value = note, onValueChange = { note = it }, label = { Text("Note") },
            modifier = Modifier.fillMaxWidth(), colors = fieldColors,
            shape = RoundedCornerShape(10.dp), maxLines = 2,
        )
        Button(
            onClick = { onSubmit(name.trim(), email.trim(), company.trim(), note.trim()) },
            modifier = Modifier.fillMaxWidth().height(44.dp),
            enabled = name.isNotBlank(),
            colors = ButtonDefaults.buttonColors(
                containerColor = Indigo500,
                disabledContainerColor = Indigo500.copy(alpha = 0.4f),
            ),
            shape = RoundedCornerShape(10.dp),
        ) {
            Text("Create Lead", color = Color.White, fontWeight = FontWeight.Bold)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline quick-note form
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun AddNoteInlineForm(
    onCancel: () -> Unit,
    onSubmit: (String) -> Unit,
) {
    var note by remember { mutableStateOf("") }
    val fieldColors = fieldColorScheme(Emerald400)

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        FormHeader("Add Note", onCancel)
        OutlinedTextField(
            value = note, onValueChange = { note = it }, label = { Text("Note") },
            modifier = Modifier.fillMaxWidth(), colors = fieldColors,
            shape = RoundedCornerShape(10.dp), maxLines = 4, minLines = 3,
        )
        Button(
            onClick  = { onSubmit(note.trim()) },
            modifier = Modifier.fillMaxWidth().height(44.dp),
            enabled  = note.isNotBlank(),
            colors   = ButtonDefaults.buttonColors(
                containerColor = Emerald400,
                disabledContainerColor = Emerald400.copy(alpha = 0.4f),
            ),
            shape = RoundedCornerShape(10.dp),
        ) {
            Text("Save Note", color = Color.White, fontWeight = FontWeight.Bold)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Opportunity Form (unchanged logic, now used inline via AnimatedVisibility)
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun OpportunityForm(
    onCancel: () -> Unit,
    onSubmit: (Double, String, String) -> Unit,
) {
    var expectedValue by remember { mutableStateOf("") }
    var stage         by remember { mutableStateOf("Prospecting") }
    var note          by remember { mutableStateOf("") }

    val stages = listOf("Prospecting", "Qualification", "Proposal", "Negotiation", "Closed Won")
    val fieldColors = fieldColorScheme(Blue400)

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        FormHeader("Create Opportunity", onCancel)

        OutlinedTextField(
            value         = expectedValue,
            onValueChange = { if (it.isEmpty() || it.toDoubleOrNull() != null) expectedValue = it },
            label         = { Text("Expected value (₹)") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors,
            shape         = RoundedCornerShape(10.dp),
            singleLine    = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        )

        Text("Stage", color = Slate400, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.5.sp)

        val rows = stages.chunked(3)
        rows.forEach { rowStages ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
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
            value = note, onValueChange = { note = it }, label = { Text("Note") },
            modifier = Modifier.fillMaxWidth(), colors = fieldColors,
            shape = RoundedCornerShape(10.dp), maxLines = 2,
        )

        Button(
            onClick  = { onSubmit(expectedValue.toDoubleOrNull() ?: 0.0, stage, note.trim()) },
            modifier = Modifier.fillMaxWidth().height(46.dp),
            enabled  = expectedValue.isNotBlank(),
            colors   = ButtonDefaults.buttonColors(
                containerColor         = Blue400,
                disabledContainerColor = Blue400.copy(alpha = 0.4f),
            ),
            shape = RoundedCornerShape(10.dp),
        ) {
            Text("Save Opportunity", fontWeight = FontWeight.Bold, color = Color.White)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared micro-components
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun FormHeader(title: String, onCancel: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment     = Alignment.CenterVertically,
    ) {
        Text(title, color = SlateText, fontSize = 15.sp, fontWeight = FontWeight.Bold)
        TextButton(onClick = onCancel) {
            Text("Cancel", color = Slate400, fontSize = 12.sp)
        }
    }
}

@Composable
private fun StatusChip(label: String, accentColor: Color) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(accentColor.copy(alpha = 0.15f))
            .border(0.5.dp, accentColor.copy(alpha = 0.35f), RoundedCornerShape(6.dp))
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
            .background(Slate700)
            .border(0.5.dp, accentColor.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
            .clickable { onClick() }
            .padding(vertical = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Icon(icon, contentDescription = null, tint = accentColor, modifier = Modifier.size(20.dp))
            Text(label, color = SlateText, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
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
            .background(if (isSelected) accentColor.copy(alpha = 0.2f) else Slate700)
            .border(
                width = if (isSelected) 1.dp else 0.5.dp,
                color = if (isSelected) accentColor else Slate700,
                shape = RoundedCornerShape(8.dp),
            )
            .clickable { onClick() }
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text       = text,
            color      = if (isSelected) accentColor else Slate400,
            fontSize   = 12.sp,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
        )
    }
}

@Composable
private fun fieldColorScheme(accent: Color) = OutlinedTextFieldDefaults.colors(
    focusedBorderColor   = accent,
    unfocusedBorderColor = Slate700,
    focusedTextColor     = SlateText,
    unfocusedTextColor   = SlateText,
    disabledTextColor    = Slate400,
    disabledBorderColor  = Slate700.copy(alpha = 0.5f),
    disabledLabelColor   = Slate400,
    focusedLabelColor    = accent,
    unfocusedLabelColor  = Slate400,
    cursorColor          = accent,
)

// Extension for display in the inline new-lead form (phone from identity)
private val CallerIdentity.displayPhoneInline: String
    get() = when (this) {
        is CallerIdentity.Lead     -> phone
        is CallerIdentity.Customer -> phone
        else -> ""
    }

// Extension for displayName (keep consistent)
private val CallerIdentity.displayName: String
    get() = when (this) {
        is CallerIdentity.Unknown  -> "Unknown Caller"
        is CallerIdentity.Lead     -> name
        is CallerIdentity.Customer -> name
    }
