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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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

// ─────────────────────────────────────────────────────────────────────────────
// Dark glass palette
// ─────────────────────────────────────────────────────────────────────────────
private val DarkPillBg    = Color(0xFF1A2235)
private val GlassBorder   = Color(0x1AFFFFFF) // White 10%
private val DividerColor  = Color(0x14FFFFFF) // White 8%
private val TextPrimary   = Color(0xFFF8FAFC)
private val TextSecondary = Color(0xFF94A3B8)

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
        else -> Triple("CRM Overlay", TextSecondary, "")
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
                elevation    = 18.dp,
                shape        = RoundedCornerShape(40.dp),
                ambientColor = Color.Black.copy(alpha = 0.30f),
                spotColor    = Color.Black.copy(alpha = 0.40f),
            )
            .clip(RoundedCornerShape(40.dp))
            .background(DarkPillBg)
            .border(1.dp, GlassBorder, RoundedCornerShape(40.dp))
            .clickable(onClick = onExpand)
            .padding(end = 4.dp),
    ) {
        // Specular highlight strip at top of pill
        Box(
            modifier = Modifier
                .matchParentSize()
                .clip(RoundedCornerShape(topStart = 40.dp, topEnd = 40.dp))
                .background(
                    Brush.verticalGradient(
                        0f to Color.White.copy(alpha = 0.06f),
                        0.4f to Color.Transparent,
                    )
                ),
        )

        Row(
            modifier = Modifier.padding(start = 14.dp, top = 8.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
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

            // Main caller identity text
            Text(
                text       = titleText,
                color      = TextPrimary,
                fontSize   = 14.sp,
                fontWeight = FontWeight.Bold,
                maxLines   = 1,
            )

            Spacer(Modifier.width(8.dp))

            // Time or ringing
            if (durationSecs > 0 || state is OverlayState.PostCall) {
                Text(
                    text       = SessionTimerManager.formatDuration(durationSecs),
                    color      = TextSecondary,
                    fontSize   = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(Modifier.width(10.dp))
            } else {
                Text(
                    text       = "Ringing…",
                    color      = TextSecondary,
                    fontSize   = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(Modifier.width(10.dp))
            }

            // Badge: REC or type badge
            if (isRecording) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(Color(0xFFEF4444).copy(alpha = 0.15f))
                        .border(1.dp, Color(0xFFEF4444).copy(alpha = 0.30f), RoundedCornerShape(6.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                ) {
                    Text("REC", color = Color(0xFFEF4444), fontSize = 10.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.width(8.dp))
            } else if (badgeText.isNotBlank()) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(dotColor.copy(alpha = 0.12f))
                        .border(1.dp, dotColor.copy(alpha = 0.25f), RoundedCornerShape(6.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                ) {
                    Text(badgeText, color = dotColor, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.width(8.dp))
            }

            // Vertical divider
            Box(
                modifier = Modifier
                    .size(1.dp, 18.dp)
                    .background(DividerColor),
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
                    tint               = TextSecondary,
                    modifier           = Modifier.size(16.dp),
                )
            }
        }
    }
}
