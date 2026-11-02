package com.example.crm_caller_nxtgen.overlay.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.data.SessionTimerManager
import com.example.crm_caller_nxtgen.overlay.domain.ActiveSheet
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent
import com.example.crm_caller_nxtgen.overlay.domain.OverlayState
import com.example.crm_caller_nxtgen.overlay.state.OverlayStateMachine
import com.example.crm_caller_nxtgen.overlay.ui.components.MinimizedTopPill
import com.example.crm_caller_nxtgen.overlay.ui.components.ExpandedOverlayCard
import androidx.compose.material3.Text

// ─────────────────────────────────────────────────────────────────────────────
// Colour schemes — dark and light, chosen at runtime via isSystemInDarkTheme()
// ─────────────────────────────────────────────────────────────────────────────
val OverlayThemeDark = darkColorScheme(
    primary          = Color(0xFF5BAAFF),
    secondary        = Color(0xFF60A5FA),
    tertiary         = Color(0xFF34D399),
    error            = Color(0xFFEF4444),
    background       = Color(0xFF0D1117),
    surface          = Color(0xFF1A2235),
    surfaceVariant   = Color(0xFF1E293B),
    onSurface        = Color(0xFFF8FAFC),
    onSurfaceVariant = Color(0xFF94A3B8),
)

val OverlayThemeLight = lightColorScheme(
    primary          = Color(0xFF2490EF),
    secondary        = Color(0xFF3B82F6),
    tertiary         = Color(0xFF10B981),
    error            = Color(0xFFEF4444),
    background       = Color(0xFFF8FAFC),
    surface          = Color(0xFFFFFFFF),
    surfaceVariant   = Color(0xFFF1F5F9),
    onSurface        = Color(0xFF0F172A),
    onSurfaceVariant = Color(0xFF64748B),
)

@Composable
fun OverlayRoot(
    stateMachine: OverlayStateMachine,
    timerManager: SessionTimerManager,
    onClose: () -> Unit,
    onDrag: (dx: Float, dy: Float) -> Unit,
    onDragEnd: () -> Unit,
) {
    val state             by stateMachine.state.collectAsState()
    val durationSecs      by timerManager.durationSeconds.collectAsState()
    val itemSearchResults by stateMachine.itemSearchResults.collectAsState()

    val isDark = isSystemInDarkTheme()
    MaterialTheme(colorScheme = if (isDark) OverlayThemeDark else OverlayThemeLight) {
        AnimatedContent(
            targetState   = state,
            transitionSpec = { fadeIn(tween(80)) togetherWith fadeOut(tween(80)) },
            label          = "OverlayRoot",
        ) { currentState ->
            when (currentState) {

                // ── Hidden ────────────────────────────────────────────────────
                is OverlayState.Idle -> { /* nothing */ }

                // ── Looking up caller ─────────────────────────────────────────
                is OverlayState.LoadingIdentity -> LoadingBubble()

                // ── Unknown caller ────────────────────────────────────────────
                is OverlayState.UnknownCaller -> {
                    if (currentState.isExpanded) {
                        ExpandedOverlayCard(
                            state        = currentState,
                            durationSecs = durationSecs,
                            itemSearchResults = itemSearchResults,
                            onCollapse   = { stateMachine.handleEvent(OverlayEvent.ToggleExpand) },
                            onClose      = onClose,
                            onEvent      = { stateMachine.handleEvent(it) },
                        )
                    } else {
                        MinimizedTopPill(
                            state        = currentState,
                            durationSecs = durationSecs,
                                                        onExpand     = { stateMachine.handleEvent(OverlayEvent.ToggleExpand) },
                            onClose      = onClose,
                            onDrag       = onDrag,
                            onDragEnd    = onDragEnd,
                        )
                    }
                }

                // ── Lead being submitted ──────────────────────────────────────
                is OverlayState.SubmittingLead -> SubmittingBubble("Creating lead…")

                // ── Known caller ──────────────────────────────────────────────
                is OverlayState.KnownCaller -> {
                    if (currentState.isExpanded) {
                        ExpandedOverlayCard(
                            state        = currentState,
                            durationSecs = durationSecs,
                            itemSearchResults = itemSearchResults,
                            onCollapse   = { stateMachine.handleEvent(OverlayEvent.ToggleExpand) },
                            onClose      = onClose,
                            onEvent      = { stateMachine.handleEvent(it) },
                        )
                    } else {
                        MinimizedTopPill(
                            state        = currentState,
                            durationSecs = durationSecs,
                                                        onExpand     = { stateMachine.handleEvent(OverlayEvent.ToggleExpand) },
                            onClose      = onClose,
                            onDrag       = onDrag,
                            onDragEnd    = onDragEnd,
                        )
                    }
                }

                // ── Action (opp/note) submitting ──────────────────────────────
                is OverlayState.SubmittingAction -> {
                    val label = when (currentState.action) {
                        ActiveSheet.OPPORTUNITY -> "Saving opportunity…"
                        ActiveSheet.ADD_LEAD    -> "Creating lead…"
                        ActiveSheet.ADD_NOTE    -> "Saving note…"
                        ActiveSheet.QUOTE       -> "Sending quote…"
                        else                    -> "Syncing…"
                    }
                    SubmittingBubble(label)
                }

                // ── Post call — persists until user closes ────────────────────
                is OverlayState.PostCall -> {
                    if (currentState.isExpanded) {
                        ExpandedOverlayCard(
                            state        = currentState,
                            durationSecs = durationSecs,
                            itemSearchResults = itemSearchResults,
                            onCollapse   = { stateMachine.handleEvent(OverlayEvent.ToggleExpand) },
                            onClose      = onClose,
                            onEvent      = { stateMachine.handleEvent(it) },
                        )
                    } else {
                        MinimizedTopPill(
                            state        = currentState,
                            durationSecs = durationSecs,
                                                        onExpand     = { stateMachine.handleEvent(OverlayEvent.ToggleExpand) },
                            onClose      = onClose,
                            onDrag       = onDrag,
                            onDragEnd    = onDragEnd,
                        )
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared loading composables — dark glass surface
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun LoadingBubble() {
    Box(
        modifier = Modifier
            .padding(top = 10.dp)
            .shadow(
                elevation    = 20.dp,
                shape        = RoundedCornerShape(32.dp),
                ambientColor = Color.Black.copy(alpha = 0.50f),
            )
            .clip(RoundedCornerShape(32.dp))
            .background(Color(0xFF0A0A0C))
            .border(0.75.dp, Color.White.copy(alpha = 0.16f), RoundedCornerShape(32.dp))
            .padding(horizontal = 16.dp, vertical = 9.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            CircularProgressIndicator(
                color       = Color(0xFF38BDF8),
                modifier    = Modifier.size(15.dp),
                strokeWidth = 2.dp,
            )
            Spacer(Modifier.width(10.dp))
            Text(
                text          = "Valentino CRM • Identifying…",
                color         = Color(0xFFF5F5F7),
                fontSize      = 12.5.sp,
                fontWeight    = FontWeight.SemiBold,
                letterSpacing = (-0.1).sp,
            )
        }
    }
}

@Composable
private fun SubmittingBubble(label: String) {
    Box(
        modifier = Modifier
            .padding(top = 10.dp)
            .shadow(
                elevation    = 20.dp,
                shape        = RoundedCornerShape(32.dp),
                ambientColor = Color.Black.copy(alpha = 0.50f),
            )
            .clip(RoundedCornerShape(32.dp))
            .background(Color(0xFF0A0A0C))
            .border(0.75.dp, Color.White.copy(alpha = 0.16f), RoundedCornerShape(32.dp))
            .padding(horizontal = 16.dp, vertical = 9.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            CircularProgressIndicator(
                color       = Color(0xFF38BDF8),
                modifier    = Modifier.size(15.dp),
                strokeWidth = 2.dp,
            )
            Spacer(Modifier.width(10.dp))
            Text(
                text          = label,
                color         = Color(0xFFF5F5F7),
                fontSize      = 12.5.sp,
                fontWeight    = FontWeight.SemiBold,
                letterSpacing = (-0.1).sp,
            )
        }
    }
}
