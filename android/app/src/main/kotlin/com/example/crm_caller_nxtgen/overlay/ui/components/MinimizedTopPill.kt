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
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
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
import com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity
import com.example.crm_caller_nxtgen.overlay.domain.CallPhase
import com.example.crm_caller_nxtgen.overlay.domain.OverlayState
import com.example.crm_caller_nxtgen.overlay.domain.displayName
import kotlinx.coroutines.delay

/**
 * Apple-style Dynamic Island pill for the CRM caller overlay.
 *
 * Designed with Apple's iconic industrial design language:
 * - Deep pitch-black continuous capsule shape with frosted glass specular rim.
 * - Live audio/call status indicators with smooth pulsing dynamics.
 * - Clean San Francisco typography hierarchy.
 * - Tap anywhere to expand into the full CRM card; tap ✕ to dismiss.
 */
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
            delay(850)
        }
    }
    val pulseAlpha by animateFloatAsState(
        targetValue   = if (pulseState) 1f else 0.35f,
        animationSpec = tween(700),
        label         = "applePulse",
    )

    val isDark = isSystemInDarkTheme()

    // Determine colors and labels based on caller state
    val (titleText, subtitleText, accentColor, badgeText) = when (state) {
        is OverlayState.LoadingIdentity -> {
            val phone = state.phoneNumber
            Quadruple(
                if (phone.isNotBlank()) phone else "Identifying…",
                "Valentino CRM",
                Color(0xFF38BDF8),
                ""
            )
        }
        is OverlayState.UnknownCaller -> {
            val sub = if (durationSecs > 0) SessionTimerManager.formatDuration(durationSecs) else "Incoming Call"
            Quadruple(
                state.phoneNumber,
                sub,
                Color(0xFFF59E0B),
                "NEW"
            )
        }
        is OverlayState.KnownCaller -> {
            val sub = if (durationSecs > 0) {
                SessionTimerManager.formatDuration(durationSecs)
            } else if (state.callPhase == CallPhase.RINGING) {
                "Incoming…"
            } else {
                state.identity.displayName
            }
            val badge = when {
                state.identity is CallerIdentity.Customer -> "CUSTOMER"
                state.identity is CallerIdentity.Lead && state.identity.isSupplier -> "SUPPLIER"
                state.identity is CallerIdentity.Lead -> "LEAD"
                else -> "VALENTINO"
            }
            val accent = when {
                state.identity is CallerIdentity.Customer -> Color(0xFF10B981) // emerald
                state.identity is CallerIdentity.Lead && state.identity.isSupplier -> Color(0xFFF97316) // orange
                else -> Color(0xFF3B82F6) // Apple blue
            }
            Quadruple(state.identity.displayName, sub, accent, badge)
        }
        is OverlayState.PostCall -> {
            val sub = "Call Ended • ${SessionTimerManager.formatDuration(durationSecs)}"
            val name = if (state.identity is CallerIdentity.Unknown) state.phoneNumber else state.identity.displayName
            Quadruple(
                name,
                sub,
                Color(0xFF94A3B8),
                "POST CALL"
            )
        }
        else -> Quadruple("Valentino CRM", "Connected", Color(0xFF94A3B8), "")
    }

    // Dynamic Island container
    Box(
        modifier = Modifier
            .padding(top = 10.dp)
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
                elevation    = 24.dp,
                shape        = RoundedCornerShape(32.dp),
                ambientColor = Color.Black.copy(alpha = if (isDark) 0.65f else 0.20f),
                spotColor    = Color.Black.copy(alpha = if (isDark) 0.45f else 0.15f),
            )
            .clip(RoundedCornerShape(32.dp))
            .background(if (isDark) Color(0xFF0A0A0C) else Color(0xFFFFFFFF))
            .border(
                0.75.dp,
                if (isDark) Color.White.copy(alpha = 0.16f) else Color.Black.copy(alpha = 0.08f),
                RoundedCornerShape(32.dp),
            )
            .clickable(onClick = onExpand),
    ) {
        // Specular top light rim (Apple glass effect)
        Box(
            modifier = Modifier
                .matchParentSize()
                .clip(RoundedCornerShape(32.dp))
                .background(
                    Brush.verticalGradient(
                        0f   to (if (isDark) Color.White.copy(alpha = 0.10f) else Color.White.copy(alpha = 0.60f)),
                        0.4f to Color.Transparent,
                    )
                ),
        )

        Row(
            modifier          = Modifier.padding(start = 12.dp, end = 8.dp, top = 8.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            // Left icon avatar / indicator
            when (state) {
                is OverlayState.LoadingIdentity -> {
                    CircularProgressIndicator(
                        color       = accentColor,
                        strokeWidth = 2.dp,
                        modifier    = Modifier.size(16.dp),
                    )
                }
                is OverlayState.KnownCaller -> {
                    Box(
                        modifier = Modifier
                            .size(28.dp)
                            .clip(CircleShape)
                            .background(accentColor.copy(alpha = 0.18f))
                            .border(1.dp, accentColor.copy(alpha = 0.40f), CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text       = (titleText.firstOrNull()?.uppercase() ?: "V"),
                            color      = accentColor,
                            fontSize   = 13.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
                is OverlayState.PostCall -> {
                    Box(
                        modifier = Modifier
                            .size(26.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.10f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector        = Icons.Default.Call,
                            contentDescription = null,
                            tint               = Color.Gray,
                            modifier           = Modifier.size(13.dp),
                        )
                    }
                }
                else -> {
                    // Unknown caller / ringing
                    Box(
                        modifier = Modifier
                            .size(28.dp)
                            .clip(CircleShape)
                            .background(accentColor.copy(alpha = 0.18f))
                            .border(1.dp, accentColor.copy(alpha = 0.35f), CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector        = Icons.Default.Call,
                            contentDescription = null,
                            tint               = accentColor,
                            modifier           = Modifier.size(14.dp),
                        )
                    }
                }
            }

            Spacer(Modifier.width(10.dp))

            // Center details: Name + Status / Duration
            Column(
                modifier = Modifier.padding(end = 6.dp),
                verticalArrangement = Arrangement.Center,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text          = titleText,
                        color         = if (isDark) Color(0xFFF5F5F7) else Color(0xFF1D1D1F),
                        fontSize      = 13.5.sp,
                        fontWeight    = FontWeight.SemiBold,
                        letterSpacing = (-0.2).sp,
                        maxLines      = 1,
                    )

                    if (badgeText.isNotBlank()) {
                        AppleBadge(label = badgeText, color = accentColor, isDark = isDark)
                    }
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    // Live pulsing green/amber dot when in call or ringing
                    if (state !is OverlayState.PostCall && state !is OverlayState.Idle) {
                        val dotColor = if (durationSecs > 0) Color(0xFF10B981) else Color(0xFFF59E0B)
                        Box(
                            modifier = Modifier
                                .size(6.dp)
                                .clip(CircleShape)
                                .background(dotColor)
                                .alpha(pulseAlpha),
                        )
                    }

                    Text(
                        text       = subtitleText,
                        color      = if (isDark) Color(0xFF86868B) else Color(0xFF6E6E73),
                        fontSize   = 11.5.sp,
                        fontWeight = FontWeight.Medium,
                        maxLines   = 1,
                    )
                }
            }

            Spacer(Modifier.width(4.dp))

            // Expand hint icon
            Box(
                modifier = Modifier
                    .size(24.dp)
                    .clip(CircleShape)
                    .background(if (isDark) Color.White.copy(alpha = 0.08f) else Color.Black.copy(alpha = 0.05f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector        = Icons.Default.KeyboardArrowDown,
                    contentDescription = "Expand",
                    tint               = if (isDark) Color.White.copy(alpha = 0.70f) else Color.Black.copy(alpha = 0.60f),
                    modifier           = Modifier.size(15.dp),
                )
            }

            Spacer(Modifier.width(6.dp))

            // Apple circular close button (✕)
            Box(
                modifier = Modifier
                    .size(24.dp)
                    .clip(CircleShape)
                    .background(if (isDark) Color.White.copy(alpha = 0.12f) else Color.Black.copy(alpha = 0.07f))
                    .clickable(onClick = onClose),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector        = Icons.Default.Close,
                    contentDescription = "Dismiss",
                    tint               = if (isDark) Color.White.copy(alpha = 0.85f) else Color.Black.copy(alpha = 0.75f),
                    modifier           = Modifier.size(12.dp),
                )
            }
        }
    }
}

@Composable
private fun AppleBadge(label: String, color: Color, isDark: Boolean) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color.copy(alpha = if (isDark) 0.16f else 0.12f))
            .border(0.5.dp, color.copy(alpha = if (isDark) 0.35f else 0.25f), RoundedCornerShape(6.dp))
            .padding(horizontal = 5.dp, vertical = 1.dp),
    ) {
        Text(
            text          = label,
            color         = color,
            fontSize      = 9.5.sp,
            fontWeight    = FontWeight.Bold,
            letterSpacing = 0.3.sp,
        )
    }
}

private data class Quadruple<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)
