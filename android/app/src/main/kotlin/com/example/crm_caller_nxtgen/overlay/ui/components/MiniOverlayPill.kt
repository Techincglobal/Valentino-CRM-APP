package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import com.example.crm_caller_nxtgen.overlay.domain.displayCompany
import com.example.crm_caller_nxtgen.overlay.domain.displayName

// ─────────────────────────────────────────────────────────────────────────────
// MiniOverlayPill — the floating draggable bubble
//
// Receives both UnknownCaller and KnownCaller states.
// Accepts OnDragEnd so the service can snap it to the edge.
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun MiniOverlayPill(
    state: OverlayState,
    durationSecs: Long,
    onExpand: () -> Unit,
    onClose: () -> Unit,
    onDrag: (dx: Float, dy: Float) -> Unit,
    onDragEnd: () -> Unit,
) {
    // ── Resolve display values from state ─────────────────────────────────────
    val identity = when (state) {
        is OverlayState.KnownCaller  -> state.identity
        is OverlayState.UnknownCaller -> CallerIdentity.Unknown
        else -> CallerIdentity.Unknown
    }
    val callPhase = when (state) {
        is OverlayState.KnownCaller   -> state.callPhase
        is OverlayState.UnknownCaller -> state.callPhase
        else -> CallPhase.RINGING
    }

    val accentColor by animateColorAsState(
        targetValue = when (identity) {
            is CallerIdentity.Unknown  -> Color(0xFFFBBF24) // Amber — caution
            is CallerIdentity.Customer -> Color(0xFF34D399) // Emerald — VIP
            is CallerIdentity.Lead     -> Color(0xFF6366F1) // Indigo — known lead
        },
        animationSpec = tween(300),
        label = "accentColor",
    )

    val title   = identity.displayName
    val subtitle = when (identity) {
        is CallerIdentity.Unknown  -> when (state) {
            is OverlayState.UnknownCaller -> state.phoneNumber
            else -> ""
        }
        else -> identity.displayCompany.ifBlank {
            when (state) {
                is OverlayState.KnownCaller -> state.phoneNumber
                else -> ""
            }
        }
    }

    val timerText = when (callPhase) {
        CallPhase.RINGING -> "Ringing…"
        CallPhase.ENDED   -> "Ended  ${SessionTimerManager.formatDuration(durationSecs)}"
        CallPhase.ACTIVE  -> SessionTimerManager.formatDuration(durationSecs)
    }

    // ── Ring pulse on ringing state ───────────────────────────────────────────
    val ringAlpha by animateFloatAsState(
        targetValue = if (callPhase == CallPhase.RINGING) 0.35f else 0f,
        animationSpec = spring(stiffness = 200f),
        label = "ringAlpha",
    )

    Box(
        modifier = Modifier
            .padding(12.dp)
            .shadow(elevation = 12.dp, shape = RoundedCornerShape(28.dp), clip = false)
            .clip(RoundedCornerShape(28.dp))
            .background(Color(0xF01E293B))          // Slate 800, near-opaque
            .border(1.dp, accentColor.copy(alpha = 0.4f), RoundedCornerShape(28.dp))
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragEnd   = { onDragEnd() },
                    onDragCancel = { onDragEnd() },
                    onDrag      = { change, amount ->
                        change.consume()
                        onDrag(amount.x, amount.y)
                    },
                )
            }
            .clickable { onExpand() }
            .padding(horizontal = 14.dp, vertical = 10.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {

            // ── Avatar ring ───────────────────────────────────────────────────
            Box(contentAlignment = Alignment.Center) {
                // Outer glow ring (ringing pulse)
                if (ringAlpha > 0f) {
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .clip(CircleShape)
                            .background(accentColor.copy(alpha = ringAlpha)),
                    )
                }
                // Icon circle
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(accentColor.copy(alpha = 0.18f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = if (identity is CallerIdentity.Unknown)
                            Icons.Default.Warning else Icons.Default.Person,
                        contentDescription = null,
                        tint     = accentColor,
                        modifier = Modifier.size(20.dp),
                    )
                }
            }

            // ── Text block ────────────────────────────────────────────────────
            Column(modifier = Modifier.widthIn(max = 150.dp)) {
                Text(
                    text       = title,
                    color      = Color(0xFFF8FAFC),
                    fontWeight = FontWeight.Bold,
                    fontSize   = 13.sp,
                    maxLines   = 1,
                    overflow   = TextOverflow.Ellipsis,
                )
                if (subtitle.isNotBlank()) {
                    Text(
                        text     = subtitle,
                        color    = Color(0xFF94A3B8),
                        fontSize = 11.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }

            // ── Live timer ────────────────────────────────────────────────────
            Text(
                text       = timerText,
                color      = accentColor,
                fontWeight = FontWeight.Bold,
                fontSize   = 13.sp,
            )

            Spacer(Modifier.width(2.dp))

            // ── Close button ──────────────────────────────────────────────────
            IconButton(
                onClick  = onClose,
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF334155)),
            ) {
                Icon(
                    imageVector     = Icons.Default.Close,
                    contentDescription = "Close overlay",
                    tint            = Color(0xFF94A3B8),
                    modifier        = Modifier.size(14.dp),
                )
            }
        }
    }
}
