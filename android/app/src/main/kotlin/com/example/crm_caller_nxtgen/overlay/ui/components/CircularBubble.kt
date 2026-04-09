package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.InfiniteRepeatableSpec
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.data.SessionTimerManager
import com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity
import com.example.crm_caller_nxtgen.overlay.domain.CallPhase
import com.example.crm_caller_nxtgen.overlay.domain.OverlayState
import com.example.crm_caller_nxtgen.overlay.domain.displayName

/**
 * iOS Assistive Touch-style circular floating bubble.
 *
 * - Draggable: service handles drag callbacks and snaps to edge.
 * - Tap: expands to the full overlay card.
 * - Shows initials (or "?") of the caller.
 * - Ringing pulse: animated expanding ring.
 * - Recording dot: small pulsing red dot at top-right.
 * - Post-call label: "ENDED" text below the circle.
 */
@Composable
fun CircularBubble(
    state: OverlayState,
    durationSecs: Long,
    isRecording: Boolean,
    onExpand: () -> Unit,
    onDrag: (dx: Float, dy: Float) -> Unit,
    onDragEnd: () -> Unit,
    onClose: () -> Unit,
) {
    val identity = when (state) {
        is OverlayState.KnownCaller   -> state.identity
        is OverlayState.UnknownCaller -> CallerIdentity.Unknown
        is OverlayState.PostCall      -> state.identity
        else -> CallerIdentity.Unknown
    }
    val callPhase = when (state) {
        is OverlayState.KnownCaller   -> state.callPhase
        is OverlayState.UnknownCaller -> state.callPhase
        is OverlayState.PostCall      -> CallPhase.ENDED
        else -> CallPhase.RINGING
    }
    val isPostCall = state is OverlayState.PostCall

    val accentColor by animateColorAsState(
        targetValue = when (identity) {
            is CallerIdentity.Unknown  -> Color(0xFF38BDF8) // Light Blue
            is CallerIdentity.Customer -> Color(0xFF34D399) // Emerald
            is CallerIdentity.Lead     -> Color(0xFF6366F1) // Indigo
        },
        animationSpec = tween(300),
        label = "bubbleAccent",
    )

    // Initials: first letter of display name, or "?" for unknown
    val initials = when (identity) {
        is CallerIdentity.Unknown  -> "?"
        is CallerIdentity.Lead     -> identity.name.firstOrNull()?.uppercaseChar()?.toString() ?: "?"
        is CallerIdentity.Customer -> identity.name.firstOrNull()?.uppercaseChar()?.toString() ?: "?"
    }

    // Ringing pulse animation
    val infiniteTransition = rememberInfiniteTransition(label = "bubblePulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue  = 1.35f,
        animationSpec = InfiniteRepeatableSpec(
            animation  = tween(900, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulseScale",
    )
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.45f,
        targetValue  = 0f,
        animationSpec = InfiniteRepeatableSpec(
            animation  = tween(900, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulseAlpha",
    )

    // Recording dot pulse
    val recAlpha by infiniteTransition.animateFloat(
        initialValue = 0.5f,
        targetValue  = 1f,
        animationSpec = InfiniteRepeatableSpec(
            animation  = tween(600),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "recDotAlpha",
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.padding(12.dp),
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
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
                .clickable { onExpand() },
        ) {
            // Ringing pulse ring (behind the circle)
            if (callPhase == CallPhase.RINGING) {
                Box(
                    modifier = Modifier
                        .size((60 * pulseScale).dp)
                        .clip(CircleShape)
                        .background(accentColor.copy(alpha = pulseAlpha)),
                )
            }

            // Main circle
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .shadow(elevation = 14.dp, shape = CircleShape, clip = false)
                    .size(60.dp)
                    .clip(CircleShape)
                    .background(Color(0xCC1E293B))  // 80% slate 800
                    .border(2.dp, accentColor, CircleShape),
            ) {
                Text(
                    text       = initials,
                    color      = accentColor,
                    fontSize   = 22.sp,
                    fontWeight = FontWeight.ExtraBold,
                    textAlign  = TextAlign.Center,
                )
            }

            // Recording dot (top-right corner)
            if (isRecording) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .size(12.dp)
                        .clip(CircleShape)
                        .background(Color(0xFFF87171).copy(alpha = recAlpha)),
                )
            }

            // Close button (top-left corner)
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .size(18.dp)
                    .clip(CircleShape)
                    .background(Color(0xE61E293B))
                    .border(1.dp, Color(0xFF475569), CircleShape)
                    .clickable { onClose() }
            ) {
                Text(
                    text = "×",
                    color = Color(0xFF94A3B8),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 2.dp)
                )
            }
        }

        // Post-call label below circle
        if (isPostCall) {
            Text(
                text      = "ENDED · ${SessionTimerManager.formatDuration(durationSecs)}",
                color     = Color(0xFF94A3B8),
                fontSize  = 9.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.5.sp,
                modifier  = Modifier.padding(top = 4.dp),
            )
        }
    }
}
