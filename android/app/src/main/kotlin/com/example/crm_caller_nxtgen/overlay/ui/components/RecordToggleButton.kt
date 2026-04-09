package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.core.InfiniteRepeatableSpec
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val RecRed    = Color(0xFFEF4444)
private val SlateText = Color(0xFF64748B)
private val BorderL   = Color(0xFFE2E8F0)

/**
 * Toggle button for call recording.
 * - Idle: outlined with phone icon, slate text
 * - Recording: filled pulsing red button, "Recording… Tap to stop"
 */
@Composable
fun RecordToggleButton(
    isRecording: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val infiniteTransition = rememberInfiniteTransition(label = "recBtnPulse")
    val alpha by infiniteTransition.animateFloat(
        initialValue  = 0.80f,
        targetValue   = 1f,
        animationSpec = InfiniteRepeatableSpec(
            animation  = tween(650),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "recBtnAlpha",
    )

    if (isRecording) {
        Button(
            onClick  = onClick,
            modifier = modifier
                .fillMaxWidth()
                .height(48.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = RecRed.copy(alpha = alpha),
            ),
            shape = RoundedCornerShape(12.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                // Pulsing dot indicator
                androidx.compose.foundation.layout.Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = alpha)),
                )
                Spacer(Modifier.width(10.dp))
                Text(
                    text       = "Recording…  Tap to stop",
                    color      = Color.White,
                    fontSize   = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    } else {
        OutlinedButton(
            onClick  = onClick,
            modifier = modifier
                .fillMaxWidth()
                .height(48.dp)
                .border(1.dp, BorderL, RoundedCornerShape(12.dp)),
            colors = ButtonDefaults.outlinedButtonColors(
                contentColor = SlateText,
            ),
            shape = RoundedCornerShape(12.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector        = Icons.Default.Phone,
                    contentDescription = "Record call",
                    tint               = SlateText,
                    modifier           = Modifier.size(16.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text       = "Record Call",
                    color      = SlateText,
                    fontSize   = 13.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }
    }
}
