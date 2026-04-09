package com.example.crm_caller_nxtgen.overlay.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.crm_caller_nxtgen.overlay.data.SessionTimerManager
import com.example.crm_caller_nxtgen.overlay.domain.ActiveSheet
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent
import com.example.crm_caller_nxtgen.overlay.domain.OverlayState
import com.example.crm_caller_nxtgen.overlay.state.OverlayStateMachine
import com.example.crm_caller_nxtgen.overlay.ui.components.MinimizedTopPill
import com.example.crm_caller_nxtgen.overlay.ui.components.ExpandedOverlayCard

// ─────────────────────────────────────────────────────────────────────────────
// Premium dark colour scheme — used consistently across all overlay surfaces
// ─────────────────────────────────────────────────────────────────────────────
val OverlayTheme = lightColorScheme(
    primary          = Color(0xFF6366F1), // Indigo 500
    secondary        = Color(0xFF38BDF8), // Light Blue
    tertiary         = Color(0xFF10B981), // Emerald 500
    error            = Color(0xFFEF4444), // Red 500
    background       = Color.Transparent, 
    surface          = Color(0xFFFFFFFF), // White
    surfaceVariant   = Color(0xFFF8FAFC), // Slight off-white
    onSurface        = Color(0xFF0F172A), // Dark text (Slate 900)
    onSurfaceVariant = Color(0xFF475569), // Slate 600
)

@Composable
fun OverlayRoot(
    stateMachine: OverlayStateMachine,
    timerManager: SessionTimerManager,
    onClose: () -> Unit,
    onDrag: (dx: Float, dy: Float) -> Unit,
    onDragEnd: () -> Unit,
) {
    val state        by stateMachine.state.collectAsState()
    val durationSecs by timerManager.durationSeconds.collectAsState()

    MaterialTheme(colorScheme = OverlayTheme) {
        AnimatedContent(
            targetState = state,
            transitionSpec = {
                androidx.compose.animation.slideInVertically(
                    animationSpec = tween(300),
                    initialOffsetY = { -it }
                ) + fadeIn(tween(200)) togetherWith androidx.compose.animation.slideOutVertically(
                    animationSpec = tween(250),
                    targetOffsetY = { -it }
                ) + fadeOut(tween(150))
            },
            label = "OverlayRoot",
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
                            isRecording  = currentState.isRecording,
                            onCollapse   = { stateMachine.handleEvent(OverlayEvent.ToggleExpand) },
                            onClose      = onClose,
                            onEvent      = { stateMachine.handleEvent(it) },
                        )
                    } else {
                        MinimizedTopPill(
                            state        = currentState,
                            durationSecs = durationSecs,
                            isRecording  = currentState.isRecording,
                            onExpand     = { stateMachine.handleEvent(OverlayEvent.ToggleExpand) },
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
                            isRecording  = currentState.isRecording,
                            onCollapse   = { stateMachine.handleEvent(OverlayEvent.ToggleExpand) },
                            onClose      = onClose,
                            onEvent      = { stateMachine.handleEvent(it) },
                        )
                    } else {
                        MinimizedTopPill(
                            state        = currentState,
                            durationSecs = durationSecs,
                            isRecording  = currentState.isRecording,
                            onExpand     = { stateMachine.handleEvent(OverlayEvent.ToggleExpand) },
                        )
                    }
                }

                // ── Action (opp/note) submitting ──────────────────────────────
                is OverlayState.SubmittingAction -> {
                    val label = when (currentState.action) {
                        ActiveSheet.OPPORTUNITY -> "Saving opportunity…"
                        ActiveSheet.ADD_LEAD    -> "Creating lead…"
                        ActiveSheet.ADD_NOTE    -> "Saving note…"
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
                            isRecording  = false,
                            onCollapse   = { stateMachine.handleEvent(OverlayEvent.ToggleExpand) },
                            onClose      = onClose,
                            onEvent      = { stateMachine.handleEvent(it) },
                        )
                    } else {
                        MinimizedTopPill(
                            state        = currentState,
                            durationSecs = durationSecs,
                            isRecording  = false,
                            onExpand     = { stateMachine.handleEvent(OverlayEvent.ToggleExpand) },
                        )
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared composables
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun LoadingBubble() {
    Surface(
        modifier       = Modifier.padding(16.dp),
        shape          = RoundedCornerShape(28.dp),
        color          = Color.White,
        tonalElevation = 6.dp,
        shadowElevation = 12.dp,
    ) {
        Row(
            modifier          = Modifier.padding(horizontal = 20.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CircularProgressIndicator(
                color       = Color(0xFF6366F1),
                modifier    = Modifier.size(18.dp),
                strokeWidth = 2.dp,
            )
            Spacer(Modifier.width(12.dp))
            Text("Looking up caller…", color = Color(0xFF0F172A), fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun SubmittingBubble(label: String) {
    Surface(
        modifier       = Modifier.padding(16.dp),
        shape          = RoundedCornerShape(28.dp),
        color          = Color.White,
        tonalElevation = 6.dp,
        shadowElevation = 12.dp,
    ) {
        Row(
            modifier          = Modifier.padding(horizontal = 20.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CircularProgressIndicator(
                color       = Color(0xFF6366F1),
                modifier    = Modifier.size(18.dp),
                strokeWidth = 2.dp,
            )
            Spacer(Modifier.width(12.dp))
            Text(label, color = Color(0xFF0F172A), fontWeight = FontWeight.SemiBold)
        }
    }
}
