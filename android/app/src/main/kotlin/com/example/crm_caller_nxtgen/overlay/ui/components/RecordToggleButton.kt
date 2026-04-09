package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.core.InfiniteRepeatableSpec
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val RecRed   = Color(0xFFF87171) // Red 400
private val Slate400 = Color(0xFF94A3B8)

/**
 * Toggle button for call recording.
 *
 * - Not recording: outlined, mic icon, "Record Call", slate text
 * - Recording: filled red, stop icon, "Recording…" + pulsing alpha
 */
@Composable
fun RecordToggleButton(
    isRecording: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val infiniteTransition = rememberInfiniteTransition(label = "recBtnPulse")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 0.75f,
        targetValue  = 1f,
        animationSpec = InfiniteRepeatableSpec(
            animation  = tween(600),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "recBtnAlpha",
    )

    if (isRecording) {
        Button(
            onClick  = onClick,
            modifier = modifier
                .fillMaxWidth()
                .height(44.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = RecRed.copy(alpha = alpha),
            ),
            shape = RoundedCornerShape(10.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector        = Icons.Default.Close,
                    contentDescription = "Stop recording",
                    tint               = Color.White,
                    modifier           = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(8.dp))
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
                .height(44.dp),
            colors = ButtonDefaults.outlinedButtonColors(
                contentColor = Slate400,
            ),
            shape = RoundedCornerShape(10.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector        = Icons.Default.Warning,
                    contentDescription = "Record call",
                    tint               = Slate400,
                    modifier           = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text       = "Record Call",
                    color      = Slate400,
                    fontSize   = 13.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }
    }
}
