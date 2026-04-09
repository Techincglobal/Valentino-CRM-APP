package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent

// ─────────────────────────────────────────────────────────────────────────────
// Light palette
// ─────────────────────────────────────────────────────────────────────────────
private val AccentIndigo  = Color(0xFF6366F1)
private val AccentRed     = Color(0xFFEF4444)
private val TextPrimary   = Color(0xFF0F172A)
private val TextSecondary = Color(0xFF64748B)
private val TextMuted     = Color(0xFF94A3B8)
private val BorderLight   = Color(0xFFE2E8F0)
private val SectionLabel  = Color(0xFF6366F1)

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
        unfocusedBorderColor = BorderLight,
        focusedTextColor     = TextPrimary,
        unfocusedTextColor   = TextPrimary,
        disabledTextColor    = TextMuted,
        disabledBorderColor  = BorderLight,
        disabledLabelColor   = TextMuted,
        focusedLabelColor    = AccentIndigo,
        unfocusedLabelColor  = TextSecondary,
        cursorColor          = AccentIndigo,
        focusedContainerColor   = Color.White,
        unfocusedContainerColor = Color.White,
        disabledContainerColor  = Color(0xFFF8FAFC),
    )

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {

        // Section label
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(3.dp, 14.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(AccentIndigo),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text          = "NEW LEAD",
                color         = SectionLabel,
                fontSize      = 11.sp,
                fontWeight    = FontWeight.Bold,
                letterSpacing = 1.2.sp,
            )
        }

        Spacer(Modifier.height(2.dp))

        // Phone — locked
        OutlinedTextField(
            value         = phone,
            onValueChange = {},
            label         = { Text("Phone number") },
            enabled       = false,
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors,
            shape         = RoundedCornerShape(12.dp),
            singleLine    = true,
        )

        // Full name — required
        OutlinedTextField(
            value         = name,
            onValueChange = { name = it },
            label         = { Text("Full name *") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors,
            shape         = RoundedCornerShape(12.dp),
            singleLine    = true,
        )

        // Email
        OutlinedTextField(
            value           = email,
            onValueChange   = { email = it },
            label           = { Text("Email") },
            modifier        = Modifier.fillMaxWidth(),
            colors          = fieldColors,
            shape           = RoundedCornerShape(12.dp),
            singleLine      = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
        )

        // Company
        OutlinedTextField(
            value         = company,
            onValueChange = { company = it },
            label         = { Text("Company") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors,
            shape         = RoundedCornerShape(12.dp),
            singleLine    = true,
        )

        // Quick note
        OutlinedTextField(
            value         = note,
            onValueChange = { note = it },
            label         = { Text("Quick note") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors,
            shape         = RoundedCornerShape(12.dp),
            maxLines      = 3,
            minLines      = 2,
        )

        Spacer(Modifier.height(4.dp))

        // Record toggle
        RecordToggleButton(
            isRecording = isRecording,
            onClick     = { onEvent(OverlayEvent.ToggleRecording) },
        )

        // Log Complaint — can always be pressed (even without saving lead first)
        OutlinedButton(
            onClick  = { onEvent(OverlayEvent.OpenComplaintPopup) },
            modifier = Modifier
                .fillMaxWidth()
                .height(46.dp)
                .border(1.dp, AccentRed.copy(alpha = 0.5f), RoundedCornerShape(12.dp)),
            colors = ButtonDefaults.outlinedButtonColors(
                contentColor = AccentRed,
            ),
            shape = RoundedCornerShape(12.dp),
        ) {
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
                fontWeight = FontWeight.SemiBold,
            )
        }

        Spacer(Modifier.height(2.dp))

        // Create lead button
        Button(
            onClick  = { onSubmit(name.trim(), email.trim(), company.trim(), note.trim()) },
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp),
            enabled  = name.isNotBlank(),
            colors   = ButtonDefaults.buttonColors(
                containerColor         = AccentIndigo,
                disabledContainerColor = AccentIndigo.copy(alpha = 0.35f),
            ),
            shape = RoundedCornerShape(12.dp),
        ) {
            Text(
                text       = "Create Lead & Save",
                fontWeight = FontWeight.Bold,
                color      = Color.White,
                fontSize   = 14.sp,
            )
        }
    }
}
