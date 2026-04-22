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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent

// ─────────────────────────────────────────────────────────────────────────────
// Dark glass palette
// ─────────────────────────────────────────────────────────────────────────────
private val AccentIndigo  = Color(0xFF6366F1)
private val AccentAmber   = Color(0xFFF59E0B)
private val AccentRed     = Color(0xFFEF4444)
private val TextPrimary   = Color(0xFFF8FAFC)
private val TextSecondary = Color(0xFF94A3B8)
private val TextMuted     = Color(0xFF64748B)
private val DarkInput     = Color(0xFF1E293B)  // Field background
private val GlassBorder   = Color(0x1AFFFFFF)  // White 10%
private val DividerColor  = Color(0x14FFFFFF)  // White 8%

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

    val fieldColors = darkFieldColors(AccentIndigo)

    Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {

        // ── Phone number banner ───────────────────────────────────────────────
        PhoneNumberBanner(phone)

        Spacer(Modifier.height(14.dp))
        HorizontalDivider(color = DividerColor, thickness = 1.dp)
        Spacer(Modifier.height(14.dp))

        // ── Section label ─────────────────────────────────────────────────────
        Row(
            verticalAlignment     = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(width = 3.dp, height = 14.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(AccentIndigo),
            )
            Text(
                text          = "NEW LEAD",
                color         = AccentIndigo,
                fontSize      = 11.sp,
                fontWeight    = FontWeight.Bold,
                letterSpacing = 1.2.sp,
            )
        }

        Spacer(Modifier.height(10.dp))

        // ── Full name ─────────────────────────────────────────────────────────
        OutlinedTextField(
            value         = name,
            onValueChange = { name = it },
            label         = { Text("Full name *") },
            leadingIcon   = {
                Icon(Icons.Default.Person, contentDescription = null, modifier = Modifier.size(18.dp))
            },
            modifier   = Modifier.fillMaxWidth(),
            colors     = fieldColors,
            shape      = RoundedCornerShape(12.dp),
            singleLine = true,
        )

        Spacer(Modifier.height(8.dp))

        // ── Email ─────────────────────────────────────────────────────────────
        OutlinedTextField(
            value           = email,
            onValueChange   = { email = it },
            label           = { Text("Email") },
            leadingIcon     = {
                Icon(Icons.Default.Email, contentDescription = null, modifier = Modifier.size(18.dp))
            },
            modifier        = Modifier.fillMaxWidth(),
            colors          = fieldColors,
            shape           = RoundedCornerShape(12.dp),
            singleLine      = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
        )

        Spacer(Modifier.height(8.dp))

        // ── Company ───────────────────────────────────────────────────────────
        OutlinedTextField(
            value         = company,
            onValueChange = { company = it },
            label         = { Text("Company") },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors,
            shape         = RoundedCornerShape(12.dp),
            singleLine    = true,
        )

        Spacer(Modifier.height(8.dp))

        // ── Quick note ────────────────────────────────────────────────────────
        OutlinedTextField(
            value         = note,
            onValueChange = { note = it },
            label         = { Text("Quick note") },
            placeholder   = { Text("What's this call about?", color = TextMuted) },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors,
            shape         = RoundedCornerShape(12.dp),
            maxLines      = 3,
            minLines      = 2,
        )

        Spacer(Modifier.height(12.dp))

        // ── Record toggle ─────────────────────────────────────────────────────
        RecordToggleButton(isRecording = isRecording, onClick = { onEvent(OverlayEvent.ToggleRecording) })

        Spacer(Modifier.height(10.dp))

        // ── Save as Lead button ───────────────────────────────────────────────
        Button(
            onClick  = { onSubmit(name.trim(), email.trim(), company.trim(), note.trim()) },
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp),
            enabled  = name.isNotBlank(),
            colors   = ButtonDefaults.buttonColors(
                containerColor         = AccentIndigo,
                disabledContainerColor = AccentIndigo.copy(alpha = 0.30f),
            ),
            shape = RoundedCornerShape(12.dp),
        ) {
            Text(
                text          = "Create Lead & Save",
                fontWeight    = FontWeight.Bold,
                color         = Color.White,
                fontSize      = 14.sp,
                letterSpacing = 0.3.sp,
            )
        }

        // ── Log Complaint — secondary text button ─────────────────────────────
        TextButton(
            onClick  = { onEvent(OverlayEvent.OpenComplaintPopup) },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(
                imageVector        = Icons.Default.Warning,
                contentDescription = null,
                tint               = AccentRed.copy(alpha = 0.8f),
                modifier           = Modifier.size(14.dp),
            )
            Spacer(Modifier.width(6.dp))
            Text(
                text       = "Log a Complaint",
                color      = AccentRed.copy(alpha = 0.8f),
                fontSize   = 12.sp,
                fontWeight = FontWeight.Medium,
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phone number banner — dark glass style
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun PhoneNumberBanner(phone: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(AccentAmber.copy(alpha = 0.08f))
            .border(1.dp, AccentAmber.copy(alpha = 0.22f), RoundedCornerShape(14.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(
            verticalAlignment     = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(42.dp)
                    .clip(CircleShape)
                    .background(AccentAmber.copy(alpha = 0.12f))
                    .border(1.5.dp, AccentAmber.copy(alpha = 0.35f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector        = Icons.Default.Phone,
                    contentDescription = null,
                    tint               = AccentAmber,
                    modifier           = Modifier.size(20.dp),
                )
            }
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text       = if (phone == "Hidden") "Hidden Number" else phone,
                    color      = TextPrimary,
                    fontSize   = 16.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text     = "Not in your CRM",
                    color    = TextSecondary,
                    fontSize = 12.sp,
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark-themed field colours
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun darkFieldColors(accent: Color) = OutlinedTextFieldDefaults.colors(
    focusedBorderColor        = accent,
    unfocusedBorderColor      = GlassBorder,
    focusedTextColor          = TextPrimary,
    unfocusedTextColor        = TextPrimary,
    disabledTextColor         = TextMuted,
    disabledBorderColor       = GlassBorder,
    disabledLabelColor        = TextMuted,
    focusedLabelColor         = accent,
    unfocusedLabelColor       = TextSecondary,
    cursorColor               = accent,
    focusedContainerColor     = DarkInput,
    unfocusedContainerColor   = DarkInput,
    disabledContainerColor    = DarkInput.copy(alpha = 0.6f),
    focusedLeadingIconColor   = accent,
    unfocusedLeadingIconColor = TextSecondary,
    disabledLeadingIconColor  = TextMuted,
)
