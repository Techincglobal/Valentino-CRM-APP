package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.graphics.Brush
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
    val dotAlpha by animateFloatAsState(
        targetValue   = if (pulseState) 1f else 0.25f,
        animationSpec = tween(600),
        label         = "pulse",
    )

    val isDark = isSystemInDarkTheme()

    val (titleText, dotColor, badgeText) = when (state) {
        is OverlayState.LoadingIdentity -> Triple("Identifying…",       Color(0xFF60A5FA), "")
        is OverlayState.UnknownCaller   -> Triple(state.phoneNumber,     Color(0xFFF59E0B), "UNKNOWN")
        is OverlayState.KnownCaller     -> Triple(state.identity.displayName, Color(0xFF10B981), "CRM")
        is OverlayState.PostCall        -> Triple("Call Ended",          Color(0xFF94A3B8), "ENDED")
        else                            -> Triple("CRM Overlay",         Color(0xFF94A3B8), "")
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
                elevation    = 16.dp,
                shape        = RoundedCornerShape(40.dp),
                ambientColor = if (isDark) Color.Black.copy(alpha = 0.35f) else Color.Black.copy(alpha = 0.10f),
                spotColor    = dotColor.copy(alpha = if (isDark) 0.20f else 0.08f),
            )
            .clip(RoundedCornerShape(40.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(
                1.dp,
                MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.12f else 0.07f),
                RoundedCornerShape(40.dp),
            )
            .clickable(onClick = onExpand)
            .padding(end = 4.dp),
    ) {
        // Subtle top specular in dark mode only
        if (isDark) {
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .clip(RoundedCornerShape(topStart = 40.dp, topEnd = 40.dp))
                    .background(
                        Brush.verticalGradient(
                            0f   to Color.White.copy(alpha = 0.06f),
                            0.5f to Color.Transparent,
                        )
                    ),
            )
        }

        Row(
            modifier              = Modifier.padding(start = 14.dp, top = 9.dp, bottom = 9.dp),
            verticalAlignment     = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            // Pulsing status dot
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(dotColor)
                    .alpha(dotAlpha),
            )

            Spacer(Modifier.width(10.dp))

            // Caller name / number
            Text(
                text       = titleText,
                color      = MaterialTheme.colorScheme.onSurface,
                fontSize   = 14.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines   = 1,
            )

            Spacer(Modifier.width(8.dp))

            // Timer or "Ringing"
            val timerLabel = if (durationSecs > 0 || state is OverlayState.PostCall)
                SessionTimerManager.formatDuration(durationSecs)
            else
                "Ringing…"

            Text(
                text       = timerLabel,
                color      = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize   = 13.sp,
                fontWeight = FontWeight.Medium,
            )

            Spacer(Modifier.width(10.dp))

            // Type badge
            if (badgeText.isNotBlank()) {
                PillBadge(label = badgeText, color = dotColor)
                Spacer(Modifier.width(8.dp))
            }

            // Vertical rule
            Box(
                modifier = Modifier
                    .size(1.dp, 18.dp)
                    .background(MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.12f else 0.07f)),
            )

            Spacer(Modifier.width(2.dp))

            // Close button
            IconButton(
                onClick  = onClose,
                modifier = Modifier.size(32.dp),
            ) {
                Icon(
                    imageVector        = Icons.Default.Close,
                    contentDescription = "Close",
                    tint               = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier           = Modifier.size(16.dp),
                )
            }
        }
    }
}

@Composable
private fun PillBadge(label: String, color: Color) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color.copy(alpha = 0.12f))
            .border(1.dp, color.copy(alpha = 0.28f), RoundedCornerShape(6.dp))
            .padding(horizontal = 6.dp, vertical = 2.dp),
    ) {
        Text(
            text       = label,
            color      = color,
            fontSize   = 10.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}
