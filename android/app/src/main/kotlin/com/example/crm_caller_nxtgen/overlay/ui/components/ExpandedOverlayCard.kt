package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.core.InfiniteRepeatableSpec
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity
import com.example.crm_caller_nxtgen.overlay.domain.CallPhase
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent
import com.example.crm_caller_nxtgen.overlay.domain.OverlayState
import com.example.crm_caller_nxtgen.overlay.domain.displayCompany
import com.example.crm_caller_nxtgen.overlay.domain.displayName

/**
 * The expanded overlay card.
 *
 * - onCollapse: minimise to bubble (chevron button — safe during live call)
 * - onClose: fully dismiss overlay (X button — only shown in PostCall)
 */
@Composable
fun ExpandedOverlayCard(
    state: OverlayState,
    durationSecs: Long,
    isRecording: Boolean,
    onCollapse: () -> Unit,
    onClose: () -> Unit,
    onEvent: (OverlayEvent) -> Unit,
) {
    val phone      : String
    val identity   : CallerIdentity
    val callPhase  : CallPhase
    val activeSheet: ActiveSheet
    val isPostCall : Boolean

    when (state) {
        is OverlayState.UnknownCaller -> {
            phone       = state.phoneNumber
            identity    = CallerIdentity.Unknown
            callPhase   = state.callPhase
            activeSheet = ActiveSheet.NONE
            isPostCall  = false
        }
        is OverlayState.KnownCaller -> {
            phone       = state.phoneNumber
            identity    = state.identity
            callPhase   = state.callPhase
            activeSheet = state.activeSheet
            isPostCall  = false
        }
        is OverlayState.PostCall -> {
            phone       = state.phoneNumber
            identity    = state.identity
            callPhase   = CallPhase.ENDED
            activeSheet = ActiveSheet.NONE
            isPostCall  = true
        }
        else -> return
    }

    Surface(
        modifier = Modifier
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .shadow(24.dp, RoundedCornerShape(20.dp), spotColor = Color.Black.copy(alpha = 0.2f)),
        shape          = RoundedCornerShape(20.dp),
        color          = Color.White,
        tonalElevation = 8.dp,
    ) {
        Column(modifier = Modifier.heightIn(max = 560.dp)) {

            CardHeader(
                identity     = identity,
                phone        = phone,
                callPhase    = callPhase,
                durationSecs = durationSecs,
                isRecording  = isRecording,
                isPostCall   = isPostCall,
                onCollapse   = onCollapse,
                onClose      = onClose,
            )

            HorizontalDivider(color = Color(0xFFE2E8F0), thickness = 0.5.dp)

            Column(
                modifier = Modifier
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(0.dp),
            ) {
                when (identity) {
                    is CallerIdentity.Unknown -> {
                        UnknownCallerForm(
                            phone       = phone,
                            isRecording = isRecording,
                            onEvent     = onEvent,
                            onSubmit    = { name, email, company, note ->
                                onEvent(OverlayEvent.SubmitLead(name, email, company, note))
                            },
                        )
                    }
                    is CallerIdentity.Lead,
                    is CallerIdentity.Customer -> {
                        KnownContactDashboard(
                            identity    = identity,
                            callPhase   = callPhase,
                            activeSheet = activeSheet,
                            isRecording = isRecording,
                            onEvent     = onEvent,
                        )
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header strip
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun CardHeader(
    identity: CallerIdentity,
    phone: String,
    callPhase: CallPhase,
    durationSecs: Long,
    isRecording: Boolean,
    isPostCall: Boolean,
    onCollapse: () -> Unit,
    onClose: () -> Unit,
) {
    val accentColor = when (identity) {
        is CallerIdentity.Unknown  -> Color(0xFF38BDF8)
        is CallerIdentity.Customer -> Color(0xFF10B981)
        is CallerIdentity.Lead     -> Color(0xFF6366F1)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment     = Alignment.CenterVertically,
    ) {
        // Left: identity info
        Column(modifier = Modifier.weight(1f)) {
            // Status badge
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(accentColor.copy(alpha = 0.15f))
                    .padding(horizontal = 8.dp, vertical = 3.dp),
            ) {
                Text(
                    text = when (identity) {
                        is CallerIdentity.Unknown  -> if (isPostCall) "Post Call" else "Unknown Caller"
                        is CallerIdentity.Customer -> if (isPostCall) "Post Call" else "Customer"
                        is CallerIdentity.Lead     -> if (isPostCall) "Post Call" else identity.status.ifBlank { "Lead" }
                    },
                    color      = accentColor,
                    fontSize   = 10.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 0.5.sp,
                )
            }
            Spacer(Modifier.height(4.dp))
            Text(
                text       = if (identity is CallerIdentity.Unknown) phone else identity.displayName,
                color      = Color(0xFF0F172A),
                fontSize   = 17.sp,
                fontWeight = FontWeight.Bold,
            )
            if (identity.displayCompany.isNotBlank()) {
                Text(text = identity.displayCompany, color = Color(0xFF64748B), fontSize = 12.sp)
            }
        }

        // Right: recording indicator + timer + buttons
        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            // Button row: chevron-down + X
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                // Chevron — minimise to bubble
                IconButton(
                    onClick  = onCollapse,
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(Color(0xFFF1F5F9)),
                ) {
                    Icon(
                        imageVector        = Icons.Default.KeyboardArrowDown,
                        contentDescription = "Minimise",
                        tint               = Color(0xFF475569),
                        modifier           = Modifier.size(18.dp),
                    )
                }
                // X — full dismiss, available anytime
                IconButton(
                    onClick  = onClose,
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(Color(0xFFF1F5F9)),
                ) {
                    Icon(
                        imageVector        = Icons.Default.Close,
                        contentDescription = "Close overlay",
                        tint               = Color(0xFFEF4444), // Make it a subtle red to indicate destructive action
                        modifier           = Modifier.size(16.dp),
                    )
                }
            }

            // Recording indicator
            if (isRecording) {
                RecordingDot()
            }

            // Timer chip
            TimerChip(callPhase, durationSecs, accentColor)
        }
    }
}

@Composable
private fun TimerChip(callPhase: CallPhase, durationSecs: Long, accentColor: Color) {
    Row(
        verticalAlignment     = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            text = when (callPhase) {
                CallPhase.RINGING -> "Ringing"
                CallPhase.ENDED   -> "Ended · ${SessionTimerManager.formatDuration(durationSecs)}"
                CallPhase.ACTIVE  -> SessionTimerManager.formatDuration(durationSecs)
            },
            color      = accentColor,
            fontSize   = 12.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun RecordingDot() {
    val infiniteTransition = rememberInfiniteTransition(label = "recDotPulse")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 0.5f,
        targetValue  = 1f,
        animationSpec = InfiniteRepeatableSpec(tween(600), RepeatMode.Reverse),
        label = "recDotAlpha",
    )
    Row(
        verticalAlignment     = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(Color(0xFFF87171).copy(alpha = alpha)),
        )
        Text(
            text       = "REC",
            color      = Color(0xFFF87171).copy(alpha = alpha),
            fontSize   = 10.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 0.5.sp,
        )
    }
}
