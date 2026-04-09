package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.InfiniteRepeatableSpec
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
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
 * iOS Assistive Touch-style circular floating bubble — clean white frosted look.
 *
 * Tap → expands to full overlay card.
 * Drag → service handles position + snap to edge.
 */
@Composable
fun CircularBubble(
    state: OverlayState,
    durationSecs: Long,
    isRecording: Boolean,
    onExpand: () -> Unit,
    onDrag: (dx: Float, dy: Float) -> Unit,
    onDragEnd: () -> Unit,
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
            is CallerIdentity.Unknown  -> Color(0xFFF59E0B) // Amber 500
            is CallerIdentity.Customer -> Color(0xFF10B981) // Emerald 500
            is CallerIdentity.Lead     -> Color(0xFF6366F1) // Indigo 500
        },
        animationSpec = tween(300),
        label = "bubbleAccent",
    )

    val initials = when (identity) {
        is CallerIdentity.Unknown  -> "?"
        is CallerIdentity.Lead     -> identity.name.firstOrNull()?.uppercaseChar()?.toString() ?: "?"
        is CallerIdentity.Customer -> identity.name.firstOrNull()?.uppercaseChar()?.toString() ?: "?"
    }

    val infiniteTransition = rememberInfiniteTransition(label = "bubblePulse")

    // Ringing pulse
    val pulseScale by infiniteTransition.animateFloat(
        initialValue  = 1f,
        targetValue   = 1.4f,
        animationSpec = InfiniteRepeatableSpec(
            animation  = tween(1000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulseScale",
    )
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue  = 0.35f,
        targetValue   = 0f,
        animationSpec = InfiniteRepeatableSpec(
            animation  = tween(1000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulseAlpha",
    )

    // Recording dot pulse
    val recAlpha by infiniteTransition.animateFloat(
        initialValue  = 0.55f,
        targetValue   = 1f,
        animationSpec = InfiniteRepeatableSpec(
            animation  = tween(600),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "recDotAlpha",
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.padding(14.dp),
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
            // Ringing pulse ring
            if (callPhase == CallPhase.RINGING) {
                Box(
                    modifier = Modifier
                        .size((64 * pulseScale).dp)
                        .clip(CircleShape)
                        .background(accentColor.copy(alpha = pulseAlpha)),
                )
            }

            // Main circle — white frosted
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .shadow(
                        elevation  = 16.dp,
                        shape      = CircleShape,
                        clip       = false,
                        ambientColor = accentColor.copy(alpha = 0.25f),
                        spotColor    = accentColor.copy(alpha = 0.35f),
                    )
                    .size(64.dp)
                    .clip(CircleShape)
                    .background(Color.White)
                    .border(2.dp, accentColor.copy(alpha = 0.7f), CircleShape),
            ) {
                Text(
                    text       = initials,
                    color      = accentColor,
                    fontSize   = 24.sp,
                    fontWeight = FontWeight.ExtraBold,
                    textAlign  = TextAlign.Center,
                )
            }

            // Recording dot — top right
            if (isRecording) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(4.dp)
                        .size(12.dp)
                        .clip(CircleShape)
                        .background(Color(0xFFEF4444).copy(alpha = recAlpha)),
                )
            }
        }

        // Post-call label
        if (isPostCall) {
            Text(
                text          = "ENDED · ${SessionTimerManager.formatDuration(durationSecs)}",
                color         = Color(0xFF94A3B8),
                fontSize      = 9.sp,
                fontWeight    = FontWeight.Bold,
                letterSpacing = 0.5.sp,
                modifier      = Modifier.padding(top = 5.dp),
            )
        }
    }
}
