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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.data.SessionTimerManager
import com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity
import com.example.crm_caller_nxtgen.overlay.domain.CallPhase
import com.example.crm_caller_nxtgen.overlay.domain.OverlayState
import com.example.crm_caller_nxtgen.overlay.domain.displayName

/**
 * A beautiful, true floating notification banner (iOS/Truecaller style).
 * Replaces the old "Circular Bubble" for a vastly superior modern pop-up feel.
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

    val phoneOrTitle = when (state) {
        is OverlayState.UnknownCaller -> state.phoneNumber
        is OverlayState.KnownCaller -> {
            val i = state.identity
            if (i is CallerIdentity.Lead) i.company.ifBlank { i.phone }
            else if (i is CallerIdentity.Customer) i.company.ifBlank { i.phone }
            else "Known Caller"
        }
        else -> ""
    }

    val accentColor by animateColorAsState(
        targetValue = when (identity) {
            is CallerIdentity.Unknown  -> Color(0xFF38BDF8) // Light Blue
            is CallerIdentity.Customer -> Color(0xFF10B981) // Emerald
            is CallerIdentity.Lead     -> Color(0xFF6366F1) // Indigo
        },
        animationSpec = tween(300),
        label = "bannerAccent",
    )

    val initials = when (identity) {
        is CallerIdentity.Unknown  -> "?"
        is CallerIdentity.Lead     -> identity.name.firstOrNull()?.uppercaseChar()?.toString() ?: "?"
        is CallerIdentity.Customer -> identity.name.firstOrNull()?.uppercaseChar()?.toString() ?: "?"
    }

    // Ringing pulse animation
    val infiniteTransition = rememberInfiniteTransition(label = "bannerPulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue  = 1.5f,
        animationSpec = InfiniteRepeatableSpec(
            animation  = tween(1000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulseScale",
    )
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.5f,
        targetValue  = 0f,
        animationSpec = InfiniteRepeatableSpec(
            animation  = tween(1000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulseAlpha",
    )

    // A sleek, horizontal floating banner
    Row(
        modifier = Modifier
            .padding(horizontal = 16.dp, vertical = 24.dp) // Allows edge breathing room
            .shadow(
                elevation = 20.dp, 
                shape = RoundedCornerShape(24.dp), 
                spotColor = Color.Black.copy(alpha = 0.15f), 
                clip = false
            )
            .width(300.dp) // Wide true notification size
            .clip(RoundedCornerShape(24.dp))
            .background(Color.White)
            .border(1.dp, Color(0xFFE2E8F0), RoundedCornerShape(24.dp))
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
            .clickable { onExpand() }
            .padding(12.dp)
            .padding(end = 4.dp), // Extra padding for the close button
        verticalAlignment = Alignment.CenterVertically
    ) {
        // 1. Caller Avatar with pulse
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(48.dp)
        ) {
            if (callPhase == CallPhase.RINGING) {
                Box(
                    modifier = Modifier
                        .size((40 * pulseScale).dp)
                        .clip(CircleShape)
                        .background(accentColor.copy(alpha = pulseAlpha))
                )
            }
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(accentColor.copy(alpha = 0.15f))
                    .border(1.dp, accentColor.copy(alpha = 0.4f), CircleShape)
            ) {
                Text(
                    text = initials,
                    color = accentColor,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.ExtraBold
                )
            }
        }

        Spacer(modifier = Modifier.width(14.dp))

        // 2. Caller Info
        Column(
            modifier = Modifier.weight(1f),
            horizontalAlignment = Alignment.Start
        ) {
            Text(
                text = identity.displayName,
                color = Color(0xFF0F172A),
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(2.dp))
            
            // Subtitle logic
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (isPostCall) {
                    Text(
                        text = "Call Ended · ${SessionTimerManager.formatDuration(durationSecs)}",
                        color = Color(0xFF64748B),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium
                    )
                } else {
                    // Ringing or Active indicator dot
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .clip(CircleShape)
                            .background(if (callPhase == CallPhase.RINGING) accentColor else Color(0xFF10B981))
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = if (callPhase == CallPhase.RINGING) "Incoming Call..." else "Call Active · ${SessionTimerManager.formatDuration(durationSecs)}",
                        color = Color(0xFF64748B),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }

        Spacer(modifier = Modifier.width(8.dp))

        // 3. Compact Dismiss Button
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(Color(0xFFF1F5F9))
                .clickable { onClose() },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = "Dismiss",
                tint = Color(0xFF475569),
                modifier = Modifier.size(16.dp)
            )
        }
    }
}
