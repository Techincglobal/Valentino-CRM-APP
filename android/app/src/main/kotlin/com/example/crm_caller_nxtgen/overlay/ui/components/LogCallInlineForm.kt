package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val LcBlue    = Color(0xFF3B82F6)
private val LcGreen   = Color(0xFF22C55E)
private val LcIndigo  = Color(0xFF6366F1)

@Composable
fun LogCallInlineForm(
    isDark: Boolean,
    isWhatsApp: Boolean,
    onCancel: () -> Unit,
    onSubmit: (notes: String, callType: String) -> Unit,
) {
    var notes    by remember { mutableStateOf("") }
    var callType by remember { mutableStateOf(if (isWhatsApp) "WhatsApp" else "Regular") }

    val onSurface        = MaterialTheme.colorScheme.onSurface
    val surfaceVariant   = MaterialTheme.colorScheme.surfaceVariant
    val onSurfaceVariant = MaterialTheme.colorScheme.onSurfaceVariant

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(if (isDark) LcBlue.copy(alpha = 0.06f) else LcBlue.copy(alpha = 0.04f))
            .border(1.dp, LcBlue.copy(alpha = 0.20f), RoundedCornerShape(14.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // Header
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Default.Phone, null, tint = LcBlue, modifier = Modifier.size(14.dp))
            Text(
                text          = "LOG CALL",
                color         = LcBlue,
                fontSize      = 10.sp,
                fontWeight    = FontWeight.ExtraBold,
                letterSpacing = 1.2.sp,
            )
        }

        // Call type toggle
        Row(
            modifier              = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            CallTypeChip(
                label    = "Regular",
                icon     = Icons.Default.Phone,
                selected = callType == "Regular",
                color    = LcBlue,
                modifier = Modifier.weight(1f),
                onClick  = { callType = "Regular" },
            )
            CallTypeChip(
                label    = "WhatsApp",
                icon     = Icons.Default.PhoneAndroid,
                selected = callType == "WhatsApp",
                color    = LcGreen,
                modifier = Modifier.weight(1f),
                onClick  = { callType = "WhatsApp" },
            )
        }

        // Notes field
        OutlinedTextField(
            value         = notes,
            onValueChange = { notes = it },
            label         = { Text("Call notes (optional)", color = onSurfaceVariant, fontSize = 12.sp) },
            placeholder   = { Text("What was discussed?", color = onSurfaceVariant.copy(alpha = 0.5f), fontSize = 12.sp) },
            modifier      = Modifier.fillMaxWidth(),
            colors        = fieldColors(LcBlue),
            shape         = RoundedCornerShape(10.dp),
            maxLines      = 3,
            minLines      = 2,
        )

        // Action row
        Row(
            modifier              = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            TextButton(onClick = onCancel, modifier = Modifier.weight(1f)) {
                Text("Cancel", color = onSurfaceVariant, fontSize = 13.sp)
            }
            Button(
                onClick  = { onSubmit(notes.trim(), callType) },
                modifier = Modifier.weight(2f).height(40.dp),
                colors   = ButtonDefaults.buttonColors(containerColor = LcBlue),
                shape    = RoundedCornerShape(10.dp),
            ) {
                Icon(Icons.Default.Phone, null, tint = Color.White, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(6.dp))
                Text("Save Log", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            }
        }
    }
}

@Composable
private fun CallTypeChip(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    selected: Boolean,
    color: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val bg     = if (selected) color.copy(alpha = 0.12f) else Color.Transparent
    val border = if (selected) color.copy(alpha = 0.50f) else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(bg)
            .border(1.dp, border, RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment     = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Icon(icon, null, tint = if (selected) color else MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(13.dp))
        Spacer(Modifier.width(5.dp))
        Text(
            text       = label,
            color      = if (selected) color else MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize   = 12.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
        )
    }
}
