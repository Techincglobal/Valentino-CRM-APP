package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.animateColorAsState
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
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.data.SessionTimerManager
import com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity
import com.example.crm_caller_nxtgen.overlay.domain.CallPhase
import com.example.crm_caller_nxtgen.overlay.domain.OverlayState
import com.example.crm_caller_nxtgen.overlay.domain.displayName

/**
 * Clean circular floating bubble — no animations, crisp design.
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
    val isPostCall  = state is OverlayState.PostCall
    val isRinging   = callPhase == CallPhase.RINGING
    val isActive    = callPhase == CallPhase.ACTIVE

    val accentColor by animateColorAsState(
        targetValue = when (identity) {
            is CallerIdentity.Unknown  -> Color(0xFFF59E0B) // Amber
            is CallerIdentity.Customer -> Color(0xFF2490EF) // brand blue
            is CallerIdentity.Lead     -> Color(0xFF8B5CF6) // lead violet
        },
        animationSpec = tween(300),
        label = "bubbleAccent",
    )

    val initials = when (identity) {
        is CallerIdentity.Unknown  -> "?"
        is CallerIdentity.Lead     -> buildInitials(identity.name)
        is CallerIdentity.Customer -> buildInitials(identity.name)
    }

    // Display name shown below bubble — truncated to fit
    val displayLabel = when (identity) {
        is CallerIdentity.Unknown  -> when (val s = state) {
            is OverlayState.UnknownCaller -> formatPhone(s.phoneNumber)
            else -> "Unknown"
        }
        is CallerIdentity.Lead     -> identity.name.ifBlank { identity.phone }
        is CallerIdentity.Customer -> identity.name.ifBlank { identity.phone }
    }

    val phaseLabel = when {
        isPostCall -> "Ended · ${SessionTimerManager.formatDuration(durationSecs)}"
        isRinging  -> "Ringing…"
        isActive   -> SessionTimerManager.formatDuration(durationSecs)
        else       -> ""
    }

    // Phase background accent (light tint behind bubble when ringing)
    val ringColor = if (isRinging) accentColor.copy(alpha = 0.12f) else Color.Transparent

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.padding(10.dp),
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
            // Static outer ring when ringing (no animation — clean)
            if (isRinging) {
                Box(
                    modifier = Modifier
                        .size(84.dp)
                        .clip(CircleShape)
                        .background(accentColor.copy(alpha = 0.10f))
                        .border(1.5.dp, accentColor.copy(alpha = 0.25f), CircleShape),
                )
            }

            // Main circle
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .shadow(
                        elevation     = 14.dp,
                        shape         = CircleShape,
                        clip          = false,
                        ambientColor  = accentColor.copy(alpha = 0.20f),
                        spotColor     = accentColor.copy(alpha = 0.30f),
                    )
                    .size(68.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF1E293B))          // dark slate — visible on any background
                    .border(2.dp, accentColor.copy(alpha = 0.80f), CircleShape),
            ) {
                Text(
                    text       = initials,
                    color      = accentColor,
                    fontSize   = 22.sp,
                    fontWeight = FontWeight.ExtraBold,
                    textAlign  = TextAlign.Center,
                )
            }

            // Active call — small green dot bottom-right
            if (isActive) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(4.dp)
                        .size(14.dp)
                        .clip(CircleShape)
                        .background(Color(0xFF1E293B))
                        .padding(2.dp)
                        .clip(CircleShape)
                        .background(Color(0xFF22C55E)),   // Green 500
                )
            }

            // Recording indicator — red dot top-right
            if (isRecording) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(4.dp)
                        .size(12.dp)
                        .clip(CircleShape)
                        .background(Color(0xFF1E293B))
                        .padding(2.dp)
                        .clip(CircleShape)
                        .background(Color(0xFFEF4444)),   // Red 500
                )
            }
        }

        // Display name pill
        if (displayLabel.isNotBlank()) {
            Box(
                modifier = Modifier
                    .padding(top = 5.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(Color(0xFF1E293B).copy(alpha = 0.80f))
                    .padding(horizontal = 8.dp, vertical = 3.dp),
            ) {
                Text(
                    text       = displayLabel,
                    color      = Color(0xFFCBD5E1),   // Slate 300
                    fontSize   = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines   = 1,
                    overflow   = TextOverflow.Ellipsis,
                )
            }
        }

        // Phase/timer label
        if (phaseLabel.isNotBlank()) {
            Text(
                text          = phaseLabel,
                color         = accentColor.copy(alpha = 0.85f),
                fontSize      = 9.sp,
                fontWeight    = FontWeight.Bold,
                letterSpacing = 0.4.sp,
                modifier      = Modifier.padding(top = 2.dp),
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

private fun buildInitials(name: String): String {
    val parts = name.trim().split(Regex("\\s+")).filter { it.isNotBlank() }
    return when {
        parts.isEmpty()  -> "?"
        parts.size == 1  -> parts[0].take(1).uppercase()
        else             -> "${parts[0][0]}${parts[1][0]}".uppercase()
    }
}

private fun formatPhone(phone: String): String {
    if (phone == "Hidden") return "Hidden"
    // Show last 4 digits for privacy, e.g. "···· 4321"
    val digits = phone.filter { it.isDigit() }
    return if (digits.length >= 4) "···· ${digits.takeLast(4)}" else phone
}
