package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.core.InfiniteRepeatableSpec
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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

// ─────────────────────────────────────────────────────────────────────────────
// Light palette
// ─────────────────────────────────────────────────────────────────────────────
private val TextPrimary   = Color(0xFF0F172A)
private val TextSecondary = Color(0xFF64748B)
private val BorderLight   = Color(0xFFE2E8F0)
private val SurfaceLight  = Color(0xFFF8FAFC)
private val White         = Color(0xFFFFFFFF)

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

    val accentColor = when (identity) {
        is CallerIdentity.Unknown  -> Color(0xFFF59E0B) // Amber 500
        is CallerIdentity.Customer -> Color(0xFF10B981) // Emerald 500
        is CallerIdentity.Lead     -> Color(0xFF6366F1) // Indigo 500
    }

    Surface(
        modifier = Modifier
            .padding(horizontal = 10.dp, vertical = 8.dp)
            .shadow(
                elevation     = 24.dp,
                shape         = RoundedCornerShape(20.dp),
                ambientColor  = Color.Black.copy(alpha = 0.08f),
                spotColor     = Color.Black.copy(alpha = 0.14f),
            ),
        shape          = RoundedCornerShape(20.dp),
        color          = White,
        tonalElevation = 0.dp,
    ) {
        Column(modifier = Modifier.heightIn(max = 720.dp)) {

            // Coloured accent bg strip behind header
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(accentColor.copy(alpha = 0.06f)),
            ) {
                CardHeader(
                    identity     = identity,
                    phone        = phone,
                    callPhase    = callPhase,
                    durationSecs = durationSecs,
                    isRecording  = isRecording,
                    isPostCall   = isPostCall,
                    accentColor  = accentColor,
                    onCollapse   = onCollapse,
                    onClose      = onClose,
                )
            }

            HorizontalDivider(color = BorderLight, thickness = 1.dp)

            Column(
                modifier = Modifier
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 18.dp, vertical = 16.dp),
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
// Header
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun CardHeader(
    identity: CallerIdentity,
    phone: String,
    callPhase: CallPhase,
    durationSecs: Long,
    isRecording: Boolean,
    isPostCall: Boolean,
    accentColor: Color,
    onCollapse: () -> Unit,
    onClose: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment     = Alignment.CenterVertically,
    ) {
        // Avatar circle with initial
        Box(
            modifier = Modifier
                .size(46.dp)
                .clip(CircleShape)
                .background(accentColor.copy(alpha = 0.12f))
                .border(1.5.dp, accentColor.copy(alpha = 0.35f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            val initials = when (identity) {
                is CallerIdentity.Unknown  -> "?"
                is CallerIdentity.Lead     -> identity.name.firstOrNull()?.uppercaseChar()?.toString() ?: "?"
                is CallerIdentity.Customer -> identity.name.firstOrNull()?.uppercaseChar()?.toString() ?: "?"
            }
            Text(
                text       = initials,
                color      = accentColor,
                fontSize   = 18.sp,
                fontWeight = FontWeight.ExtraBold,
            )
        }

        // Identity info
        Column(modifier = Modifier.weight(1f)) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(accentColor.copy(alpha = 0.12f))
                    .padding(horizontal = 7.dp, vertical = 2.dp),
            ) {
                Text(
                    text = when (identity) {
                        is CallerIdentity.Unknown  -> if (isPostCall) "Post Call" else "Unknown Caller"
                        is CallerIdentity.Customer -> if (isPostCall) "Post Call" else "Customer"
                        is CallerIdentity.Lead     -> if (isPostCall) "Post Call" else identity.status.ifBlank { "Lead" }
                    },
                    color         = accentColor,
                    fontSize      = 10.sp,
                    fontWeight    = FontWeight.Bold,
                    letterSpacing = 0.5.sp,
                )
            }
            Spacer(Modifier.height(3.dp))
            Text(
                text       = if (identity is CallerIdentity.Unknown) phone else identity.displayName,
                color      = TextPrimary,
                fontSize   = 16.sp,
                fontWeight = FontWeight.Bold,
            )
            if (identity.displayCompany.isNotBlank()) {
                Text(text = identity.displayCompany, color = TextSecondary, fontSize = 12.sp)
            }
        }

        // Right: timer + recording dot + action buttons
        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                // Chevron — minimise
                IconButton(
                    onClick  = onCollapse,
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(SurfaceLight)
                        .border(1.dp, BorderLight, CircleShape),
                ) {
                    Icon(
                        imageVector        = Icons.Default.KeyboardArrowDown,
                        contentDescription = "Minimise",
                        tint               = TextSecondary,
                        modifier           = Modifier.size(18.dp),
                    )
                }
                // X — full dismiss, PostCall only
                if (isPostCall) {
                    IconButton(
                        onClick  = onClose,
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(Color(0xFFFEE2E2))
                            .border(1.dp, Color(0xFFFCA5A5), CircleShape),
                    ) {
                        Icon(
                            imageVector        = Icons.Default.Close,
                            contentDescription = "Close overlay",
                            tint               = Color(0xFFEF4444),
                            modifier           = Modifier.size(15.dp),
                        )
                    }
                }
            }

            if (isRecording) RecordingDot()

            TimerChip(callPhase, durationSecs, accentColor)
        }
    }
}

@Composable
private fun TimerChip(callPhase: CallPhase, durationSecs: Long, accentColor: Color) {
    val label = when (callPhase) {
        CallPhase.RINGING -> "Ringing…"
        CallPhase.ENDED   -> "Ended · ${SessionTimerManager.formatDuration(durationSecs)}"
        CallPhase.ACTIVE  -> SessionTimerManager.formatDuration(durationSecs)
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(accentColor.copy(alpha = 0.10f))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    ) {
        Text(
            text       = label,
            color      = accentColor,
            fontSize   = 11.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun RecordingDot() {
    val infiniteTransition = rememberInfiniteTransition(label = "recDotPulse")
    val alpha by infiniteTransition.animateFloat(
        initialValue  = 0.6f,
        targetValue   = 1f,
        animationSpec = InfiniteRepeatableSpec(tween(550), RepeatMode.Reverse),
        label         = "recDotAlpha",
    )
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(Color(0xFFEF4444).copy(alpha = 0.10f))
            .padding(horizontal = 6.dp, vertical = 3.dp),
    ) {
        Row(
            verticalAlignment     = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(7.dp)
                    .clip(CircleShape)
                    .background(Color(0xFFEF4444).copy(alpha = alpha)),
            )
            Text(
                text          = "REC",
                color         = Color(0xFFEF4444).copy(alpha = alpha),
                fontSize      = 10.sp,
                fontWeight    = FontWeight.Bold,
                letterSpacing = 0.5.sp,
            )
        }
    }
}
