package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent

// ─────────────────────────────────────────────────────────────────────────────
// UnknownCallerForm — create-lead form during a call
//
// Design goals:
//  - Phone pre-filled and locked (can't be edited — it came from the OS)
//  - Only required field is Full Name
//  - Email, company, note are optional
//  - "Create Lead & Save" enabled once name is non-blank
//  - Record Call toggle below notes
//  - Log Complaint button (toasts "Save lead first" if no identity yet)
// ─────────────────────────────────────────────────────────────────────────────

private val AccentIndigo = Color(0xFF6366F1)
private val AccentRed    = Color(0xFFF87171)
private val SurfaceDark  = Color(0xFF334155)
private val TextPrimary  = Color(0xFFF8FAFC)
private val TextMuted    = Color(0xFF94A3B8)

@Composable
fun UnknownCallerForm(
    phone: String,
    isRecording: Boolean,
    onEvent: (OverlayEvent) -> Unit,
    onSubmit: (name: String, email: String, company: String, note: String) -> Unit,
) {
    var name    by remember { mutableStateOf("") }
    var email   by remember { mutableStateOf("") }
    var company by remember { mutableStateOf("") }
    var note    by remember { mutableStateOf("") }

    val fieldColors = OutlinedTextFieldDefaults.colors(
        focusedBorderColor   = AccentIndigo,
        unfocusedBorderColor = SurfaceDark,
        focusedTextColor     = TextPrimary,
        unfocusedTextColor   = TextPrimary,
        disabledTextColor    = TextMuted,
        disabledBorderColor  = SurfaceDark.copy(alpha = 0.6f),
        disabledLabelColor   = TextMuted,
        focusedLabelColor    = AccentIndigo,
        unfocusedLabelColor  = TextMuted,
        cursorColor          = AccentIndigo,
    )

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {

        // Section label
        Text(
            text       = "New Lead",
            color      = TextMuted,
            fontSize   = 11.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.sp,
        )

        // Phone — auto-filled from call, locked
        OutlinedTextField(
            value         = phone,
            onValueChange = {},
            label         = { Text("Phone number") },
            enabled       = false,
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors,
            shape         = RoundedCornerShape(10.dp),
            singleLine    = true,
        )

        // Full name — required
        OutlinedTextField(
            value         = name,
            onValueChange = { name = it },
            label         = { Text("Full name *") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors,
            shape         = RoundedCornerShape(10.dp),
            singleLine    = true,
        )

        // Email
        OutlinedTextField(
            value         = email,
            onValueChange = { email = it },
            label         = { Text("Email") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors,
            shape         = RoundedCornerShape(10.dp),
            singleLine    = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
        )

        // Company
        OutlinedTextField(
            value         = company,
            onValueChange = { company = it },
            label         = { Text("Company") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors,
            shape         = RoundedCornerShape(10.dp),
            singleLine    = true,
        )

        // Call note
        OutlinedTextField(
            value         = note,
            onValueChange = { note = it },
            label         = { Text("Quick note") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors,
            shape         = RoundedCornerShape(10.dp),
            maxLines      = 3,
            minLines      = 2,
        )

        Spacer(Modifier.height(2.dp))

        // Record toggle
        RecordToggleButton(
            isRecording = isRecording,
            onClick     = { onEvent(OverlayEvent.ToggleRecording) },
        )

        // Complaint button — state machine will toast "Save lead first" if no identity
        OutlinedButton(
            onClick  = { onEvent(OverlayEvent.OpenComplaintPopup) },
            modifier = Modifier.fillMaxWidth().height(44.dp),
            colors   = ButtonDefaults.outlinedButtonColors(contentColor = AccentRed),
            shape    = RoundedCornerShape(10.dp),
        ) {
            Row {
                Icon(
                    imageVector        = Icons.Default.Warning,
                    contentDescription = null,
                    tint               = AccentRed,
                    modifier           = Modifier.size(16.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text       = "Log Complaint",
                    color      = AccentRed,
                    fontSize   = 13.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }

        Spacer(Modifier.height(2.dp))

        // Create lead
        Button(
            onClick  = { onSubmit(name.trim(), email.trim(), company.trim(), note.trim()) },
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            enabled  = name.isNotBlank(),
            colors   = ButtonDefaults.buttonColors(
                containerColor         = AccentIndigo,
                disabledContainerColor = AccentIndigo.copy(alpha = 0.4f),
            ),
            shape = RoundedCornerShape(10.dp),
        ) {
            Text("Create Lead & Save", fontWeight = FontWeight.Bold, color = Color.White)
        }
    }
}
