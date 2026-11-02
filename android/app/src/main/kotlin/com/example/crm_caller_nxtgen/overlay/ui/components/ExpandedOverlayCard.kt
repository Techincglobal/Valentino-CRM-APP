package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.data.SessionTimerManager
import com.example.crm_caller_nxtgen.overlay.domain.ActiveSheet
import com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity
import com.example.crm_caller_nxtgen.overlay.domain.CallPhase
import com.example.crm_caller_nxtgen.overlay.domain.ItemSearchResult
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent
import com.example.crm_caller_nxtgen.overlay.domain.OverlayState
import com.example.crm_caller_nxtgen.overlay.domain.displayCompany
import com.example.crm_caller_nxtgen.overlay.domain.displayName

private val Red500   = Color(0xFFEF4444)
private val Green500 = Color(0xFF10B981)

@Composable
fun ExpandedOverlayCard(
    state: OverlayState,
    durationSecs: Long,
    itemSearchResults: List<ItemSearchResult>,
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
            activeSheet = state.activeSheet
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
            activeSheet = state.activeSheet
            isPostCall  = true
        }
        else -> return
    }

    // Matches the type-color legend used app-wide (see AppColors in app_theme.dart)
    val accentColor = when {
        identity is CallerIdentity.Unknown              -> Color(0xFFF59E0B) // amber
        identity is CallerIdentity.Lead && identity.isSupplier -> Color(0xFFE67E22) // orange
        identity is CallerIdentity.Customer             -> Color(0xFF14B8A6) // teal
        else                                            -> Color(0xFF2490EF) // brand blue (Lead)
    }

    val isDark = isSystemInDarkTheme()

    Box(
        modifier = Modifier
            .padding(horizontal = 12.dp, vertical = 6.dp)
            .shadow(
                elevation    = 28.dp,
                shape        = RoundedCornerShape(28.dp),
                ambientColor = if (isDark) Color.Black.copy(alpha = 0.60f) else Color.Black.copy(alpha = 0.15f),
                spotColor    = accentColor.copy(alpha = if (isDark) 0.25f else 0.12f),
            ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(28.dp))
                .background(if (isDark) Color(0xFF0F0F14) else Color(0xFFFFFFFF))
                .border(
                    0.75.dp,
                    Brush.verticalGradient(
                        listOf(
                            if (isDark) Color.White.copy(alpha = 0.18f) else Color.Black.copy(alpha = 0.10f),
                            if (isDark) Color.White.copy(alpha = 0.04f) else Color.Black.copy(alpha = 0.02f),
                        )
                    ),
                    RoundedCornerShape(28.dp),
                )
                .heightIn(max = 680.dp),
        ) {
            // Accent gradient header band
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                accentColor.copy(alpha = if (isDark) 0.14f else 0.08f),
                                accentColor.copy(alpha = 0f),
                            )
                        )
                    ),
            ) {
                CardHeader(
                    identity     = identity,
                    phone        = phone,
                    callPhase    = callPhase,
                    durationSecs = durationSecs,
                    isPostCall   = isPostCall,
                    accentColor  = accentColor,
                    isDark       = isDark,
                    onCollapse   = onCollapse,
                    onClose      = onClose,
                    onAnswer     = { onEvent(OverlayEvent.AnswerCall) },
                )
            }

            HorizontalDivider(
                color     = MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.08f else 0.06f),
                thickness = 1.dp,
            )

            Column(
                modifier = Modifier
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 18.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(0.dp),
            ) {
                when (identity) {
                    is CallerIdentity.Unknown -> {
                        UnknownCallerForm(
                            phone             = phone,
                            activeSheet       = activeSheet,
                            onEvent           = onEvent,
                            onSubmit          = { name, email, company, note ->
                                onEvent(OverlayEvent.SubmitLead(name, email, company, note))
                            },
                            onSubmitContact   = { name, email, company, note ->
                                onEvent(OverlayEvent.SubmitContact(name, email, company, note))
                            },
                            onSubmitSupplier  = { name, email ->
                                onEvent(OverlayEvent.SubmitSupplier(name, email))
                            },
                        )
                    }
                    is CallerIdentity.Lead,
                    is CallerIdentity.Customer -> {
                        KnownContactDashboard(
                            identity          = identity,
                            callPhase         = callPhase,
                            activeSheet       = activeSheet,
                            accentColor       = accentColor,
                            itemSearchResults = itemSearchResults,
                            onEvent           = onEvent,
                        )
                    }
                }
                // Extra space so content clears the Android navigation bar when the
                // overlay is dragged near the bottom of the screen.
                Spacer(modifier = Modifier.height(72.dp))
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
    isPostCall: Boolean,
    accentColor: Color,
    isDark: Boolean,
    onCollapse: () -> Unit,
    onClose: () -> Unit,
    onAnswer: () -> Unit,
) {
  Column {
    // Top subtle grab handle
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .width(36.dp)
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.35f)),
        )
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment     = Alignment.CenterVertically,
    ) {
        // Avatar
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(
                    Brush.linearGradient(
                        listOf(accentColor.copy(alpha = 0.20f), accentColor.copy(alpha = 0.08f))
                    )
                )
                .border(1.5.dp, accentColor.copy(alpha = 0.40f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            val initials = when (identity) {
                is CallerIdentity.Unknown  -> "?"
                is CallerIdentity.Lead     -> buildInitials(identity.name)
                is CallerIdentity.Customer -> buildInitials(identity.name)
            }
            Text(
                text       = initials,
                color      = accentColor,
                fontSize   = if (initials.length == 1) 20.sp else 16.sp,
                fontWeight = FontWeight.ExtraBold,
            )
        }

        // Name + badge
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            // Type badge
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(accentColor.copy(alpha = if (isDark) 0.18f else 0.12f))
                    .padding(horizontal = 8.dp, vertical = 2.dp),
            ) {
                Text(
                    text = when {
                        isPostCall -> "VALENTINO • POST CALL"
                        identity is CallerIdentity.Unknown -> "VALENTINO • NEW CALLER"
                        identity is CallerIdentity.Customer -> "VALENTINO CUSTOMER"
                        identity is CallerIdentity.Lead && identity.isSupplier -> "VALENTINO SUPPLIER"
                        identity is CallerIdentity.Lead && identity.isCustomer -> "VALENTINO CUSTOMER"
                        identity is CallerIdentity.Lead -> "VALENTINO " + identity.status.uppercase().ifBlank { "LEAD" }
                        else -> "VALENTINO CRM"
                    },
                    color         = accentColor,
                    fontSize      = 9.sp,
                    fontWeight    = FontWeight.ExtraBold,
                    letterSpacing = 0.8.sp,
                )
            }
            Text(
                text       = if (identity is CallerIdentity.Unknown) phone else identity.displayName,
                color      = MaterialTheme.colorScheme.onSurface,
                fontSize   = 16.sp,
                fontWeight = FontWeight.Bold,
                maxLines   = 1,
            )
            if (identity.displayCompany.isNotBlank()) {
                Text(
                    text     = identity.displayCompany,
                    color    = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 12.sp,
                    maxLines = 1,
                )
            }
        }

        // Right column — timer, recording dot, buttons
        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                // Minimise
                IconButton(
                    onClick  = onCollapse,
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                        .border(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f), CircleShape),
                ) {
                    Icon(
                        imageVector        = Icons.Default.KeyboardArrowDown,
                        contentDescription = "Minimise",
                        tint               = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier           = Modifier.size(18.dp),
                    )
                }
                // Close button — always available so user can dismiss anytime
                IconButton(
                    onClick  = onClose,
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                        .border(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f), CircleShape),
                ) {
                    Icon(
                        imageVector        = Icons.Default.Close,
                        contentDescription = "Close overlay",
                        tint               = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier           = Modifier.size(15.dp),
                    )
                }
            }

            TimerChip(callPhase, durationSecs, accentColor)
        }
    }

    // Prominent full-width Answer button — only while the phone is ringing.
    if (callPhase == CallPhase.RINGING) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, end = 16.dp, bottom = 14.dp)
                .height(46.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(Green500)
                .clickable { onAnswer() },
            horizontalArrangement = Arrangement.Center,
            verticalAlignment     = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.Call, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text("Answer", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
        }
    }
  }
}

private fun buildInitials(name: String): String {
    val parts = name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
    return when {
        parts.isEmpty()  -> "?"
        parts.size == 1  -> parts[0].take(1).uppercase()
        else             -> "${parts[0][0]}${parts[1][0]}".uppercase()
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
            .border(1.dp, accentColor.copy(alpha = 0.22f), RoundedCornerShape(20.dp))
            .padding(horizontal = 9.dp, vertical = 4.dp),
    ) {
        Text(
            text       = label,
            color      = accentColor,
            fontSize   = 11.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}


