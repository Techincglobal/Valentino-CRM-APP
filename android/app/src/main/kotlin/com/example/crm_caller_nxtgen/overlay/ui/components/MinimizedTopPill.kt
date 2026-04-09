package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.data.SessionTimerManager
import com.example.crm_caller_nxtgen.overlay.domain.OverlayState
import com.example.crm_caller_nxtgen.overlay.domain.displayName
import kotlinx.coroutines.delay

@Composable
fun MinimizedTopPill(
    state: OverlayState,
    durationSecs: Long,
    isRecording: Boolean,
    onExpand: () -> Unit,
    onClose: () -> Unit,
    onDrag: (dx: Float, dy: Float) -> Unit,
    onDragEnd: () -> Unit,
) {
    var pulseState by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        while (true) {
            pulseState = !pulseState
            delay(800)
        }
    }
    val dotAlpha by animateFloatAsState(targetValue = if (pulseState) 1f else 0.3f, animationSpec = tween(600), label = "pulse")

    val (titleText, dotColor, badgeText) = when (state) {
        is OverlayState.LoadingIdentity -> Triple("Identifying...", Color(0xFF60A5FA), "")
        is OverlayState.UnknownCaller   -> Triple(state.phoneNumber, Color(0xFFF59E0B), "UNKNOWN")
        is OverlayState.KnownCaller     -> Triple(state.identity.displayName, Color(0xFF10B981), "CRM")
        is OverlayState.PostCall        -> Triple("Call Ended", Color(0xFF64748B), "CLOSED")
        else -> Triple("CRM Overlay", Color(0xFF0F172A), "")
    }

    Box(
        modifier = Modifier
            .padding(top = 12.dp)
            .wrapContentWidth()
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragEnd    = { onDragEnd() },
                    onDragCancel = { onDragEnd() },
                    onDrag       = { change, amount ->
                        change.consume()
                        onDrag(amount.x, amount.y)
                    },
                )
            }
            .shadow(
                elevation = 16.dp,
                shape = CircleShape,
                ambientColor = Color.Black.copy(alpha = 0.10f),
                spotColor = Color.Black.copy(alpha = 0.16f),
            )
            .clip(CircleShape)
            .background(Color.White)
            .border(1.dp, Color(0xFFE2E8F0), CircleShape)
            .clickable(onClick = onExpand)
            .padding(end = 6.dp) // extra padding for close button balance
    ) {
        Row(
            modifier = Modifier.padding(start = 16.dp, top = 8.dp, bottom = 8.dp),
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
                color = Color(0xFF0F172A),
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
            )

            Spacer(modifier = Modifier.width(8.dp))
            
            // Time Duration
            if (durationSecs > 0 || state is OverlayState.PostCall) {
                Text(
                    text = SessionTimerManager.formatDuration(durationSecs),
                    color = Color(0xFF64748B),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(modifier = Modifier.width(10.dp))
            } else {
                Text(
                    text = "Ringing…",
                    color = Color(0xFF64748B),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(modifier = Modifier.width(10.dp))
            }

            if (isRecording) {
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(Color(0xFFEF4444).copy(alpha = 0.1f))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Text("REC", color = Color(0xFFEF4444), fontSize = 10.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(modifier = Modifier.width(10.dp))
            } else if (badgeText.isNotBlank()) {
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(dotColor.copy(alpha = 0.1f))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Text(badgeText, color = dotColor, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(modifier = Modifier.width(10.dp))
            }
            
            // Vertical Divider
            Box(
                modifier = Modifier
                    .size(1.dp, 20.dp)
                    .background(Color(0xFFE2E8F0))
            )
            
            Spacer(modifier = Modifier.width(2.dp))

            // Close button (Dismiss overlay directly)
            IconButton(
                onClick = onClose,
                modifier = Modifier.size(32.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "Close",
                    tint = Color(0xFF64748B),
                    modifier = Modifier.size(17.dp)
                )
            }
        }
    }
}
