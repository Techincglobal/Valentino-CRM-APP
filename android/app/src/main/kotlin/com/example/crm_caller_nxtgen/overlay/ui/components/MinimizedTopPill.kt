package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.domain.OverlayState
import kotlinx.coroutines.delay

@Composable
fun MinimizedTopPill(
    state: OverlayState,
    durationSecs: Long,
    isRecording: Boolean,
    onExpand: () -> Unit,
) {
    // Pulse animation for the recording/active dot
    var pulseState by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        while (true) {
            pulseState = !pulseState
            delay(800)
        }
    }
    val dotAlpha by animateFloatAsState(targetValue = if (pulseState) 1f else 0.3f, animationSpec = tween(600), label = "pulse")

    val (titleText, dotColor, badgeText) = when (state) {
        is OverlayState.LoadingIdentity -> Triple("Identifying...", Color(0xFF38BDF8), "")
        is OverlayState.UnknownCaller -> Triple(state.phoneNumber, Color(0xFFEF4444), "UNKNOWN")
        is OverlayState.KnownCaller -> Triple(state.identity.displayName, Color(0xFF10B981), "CRM")
        is OverlayState.PostCall -> Triple("Post Call Status", Color(0xFF64748B), "CLOSED")
        else -> Triple("CRM Overlay", Color.White, "")
    }

    Surface(
        modifier = Modifier
            .padding(top = 8.dp)
            .shadow(16.dp, CircleShape, spotColor = Color.Black.copy(alpha = 0.25f))
            .clickable(onClick = onExpand),
        shape = CircleShape,
        color = Color(0xFF1E293B), // Premium dark theme for the pill
        tonalElevation = 0.dp,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            // Pulsing status dot
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(dotColor)
                    .alpha(dotAlpha)
            )

            Spacer(modifier = Modifier.width(10.dp))

            // Main caller identity text
            Text(
                text = titleText,
                color = Color.White,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
            )

            if (durationSecs > 0) {
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "• ${formatDuration(durationSecs)}",
                    color = Color(0xFF94A3B8),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                )
            }

            if (isRecording) {
                Spacer(modifier = Modifier.width(8.dp))
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(Color(0xFFEF4444).copy(alpha = 0.2f))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Text("REC", color = Color(0xFFEF4444), fontSize = 9.sp, fontWeight = FontWeight.Bold)
                }
            } else if (badgeText.isNotBlank()) {
                Spacer(modifier = Modifier.width(8.dp))
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.1f))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Text(badgeText, color = Color.White, fontSize = 9.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

private fun formatDuration(secs: Long): String {
    val m = secs / 60
    val s = secs % 60
    return String.format("%02d:%02d", m, s)
}
