package com.example.crm_caller_nxtgen.overlay.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.domain.ComplaintPopupState
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent

private val Red400     = Color(0xFFEF4444)
private val Emerald400 = Color(0xFF10B981)
private val Amber400   = Color(0xFFFBBF24)
private val BlueFrappe = Color(0xFF2490EF)
private val Slate900   = Color(0xFF0F172A)
private val Slate800   = Color(0xFFFFFFFF)
private val Slate700   = Color(0xFFE2E8F0)
private val Slate400   = Color(0xFF64748B)
private val SlateText  = Color(0xFF0F172A)

/**
 * Root composable for the second WindowManager window — complaint popup.
 *
 * Renders on top of the main overlay (which has minimised to the bubble).
 * After submit or cancel the popup closes and the main overlay re-expands.
 */
@Composable
fun ComplaintPopupRoot(
    complaintState: ComplaintPopupState,
    onEvent: (OverlayEvent) -> Unit,
) {
    MaterialTheme(colorScheme = OverlayTheme) {
        AnimatedVisibility(
            visible = complaintState !is ComplaintPopupState.Hidden,
            enter   = slideInVertically(initialOffsetY = { it / 4 }) + fadeIn(),
            exit    = slideOutVertically(targetOffsetY = { it / 4 }) + fadeOut(),
        ) {
            when (complaintState) {
                is ComplaintPopupState.Hidden     -> { /* animated out */ }
                is ComplaintPopupState.Visible    -> ComplaintCard(complaintState, onEvent)
                is ComplaintPopupState.Submitting -> SubmittingCard()
            }
        }
    }
}

@Composable
private fun ComplaintCard(
    state: ComplaintPopupState.Visible,
    onEvent: (OverlayEvent) -> Unit,
) {
    var category by remember { mutableStateOf("") }
    var details  by remember { mutableStateOf("") }
    var priority by remember { mutableStateOf("Medium") }

    val fieldColors = OutlinedTextFieldDefaults.colors(
        focusedBorderColor   = BlueFrappe,
        unfocusedBorderColor = Slate700,
        focusedTextColor     = SlateText,
        unfocusedTextColor   = SlateText,
        focusedLabelColor    = BlueFrappe,
        unfocusedLabelColor  = Slate400,
        cursorColor          = BlueFrappe,
    )

    Surface(
        modifier = Modifier
            .width(320.dp)
            .shadow(32.dp, RoundedCornerShape(12.dp), spotColor = Color.Black.copy(alpha = 0.25f)),
        shape         = RoundedCornerShape(12.dp),
        color         = Slate800,
        tonalElevation = 0.dp,
    ) {
        Column(modifier = Modifier.padding(20.dp)) {

            // ── Header ────────────────────────────────────────────────────────
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment     = Alignment.CenterVertically,
            ) {
                Column {
                    Text(
                        text       = "Log Complaint",
                        color      = SlateText,
                        fontSize   = 18.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text     = if (state.identity is com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity.Unknown) state.phoneNumber else state.identity.displayNameShort,
                        color    = Slate400,
                        fontSize = 12.sp,
                    )
                }
                IconButton(
                    onClick  = { onEvent(OverlayEvent.CloseComplaintPopup) },
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(Color(0xFFF1F5F9)),
                ) {
                    Icon(
                        imageVector        = Icons.Default.Close,
                        contentDescription = "Cancel complaint",
                        tint               = Slate400,
                        modifier           = Modifier.size(16.dp),
                    )
                }
            }

            androidx.compose.material3.HorizontalDivider(
                modifier  = Modifier.padding(vertical = 12.dp),
                color     = Slate700,
                thickness = 1.dp,
            )

            // ── Priority chips ────────────────────────────────────────────────
            Text("Priority", color = Slate400, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.5.sp)
            Spacer(Modifier.height(8.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("Low" to Emerald400, "Medium" to Amber400, "High" to Red400).forEach { (p, color) ->
                    PriorityChip(
                        text       = p,
                        isSelected = priority == p,
                        color      = color,
                        modifier   = Modifier.weight(1f),
                        onClick    = { priority = p },
                    )
                }
            }

            Spacer(Modifier.height(12.dp))

            // ── Category ──────────────────────────────────────────────────────
            OutlinedTextField(
                value         = category,
                onValueChange = { category = it },
                label         = { Text("Category / Reason", fontSize = 13.sp) },
                modifier      = Modifier.fillMaxWidth().height(56.dp),
                colors        = fieldColors,
                shape         = RoundedCornerShape(6.dp),
                singleLine    = true,
            )

            Spacer(Modifier.height(10.dp))

            // ── Details ───────────────────────────────────────────────────────
            OutlinedTextField(
                value         = details,
                onValueChange = { details = it },
                label         = { Text("Details", fontSize = 13.sp) },
                modifier      = Modifier.fillMaxWidth(),
                colors        = fieldColors,
                shape         = RoundedCornerShape(6.dp),
                maxLines      = 3,
                minLines      = 3,
            )

            Spacer(Modifier.height(16.dp))

            // ── Actions ───────────────────────────────────────────────────────
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                TextButton(
                    onClick  = { onEvent(OverlayEvent.CloseComplaintPopup) },
                    modifier = Modifier.weight(1f).height(46.dp),
                ) {
                    Text("Cancel", color = Slate400, fontWeight = FontWeight.Medium)
                }

                Button(
                    onClick  = {
                        onEvent(OverlayEvent.SubmitComplaint(
                            category = category.trim(),
                            details  = details.trim(),
                            priority = priority,
                        ))
                    },
                    modifier = Modifier
                        .weight(2f)
                        .height(46.dp),
                    enabled  = category.isNotBlank() && details.isNotBlank(),
                    colors   = ButtonDefaults.buttonColors(
                        containerColor         = Red400,
                        disabledContainerColor = Red400.copy(alpha = 0.4f),
                    ),
                    shape = RoundedCornerShape(6.dp),
                ) {
                    Text("Submit Complaint", color = Color.White, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun SubmittingCard() {
    Surface(
        modifier = Modifier.width(280.dp).shadow(16.dp, RoundedCornerShape(20.dp)),
        shape    = RoundedCornerShape(20.dp),
        color    = Slate800,
    ) {
        Row(
            modifier             = Modifier.padding(24.dp),
            verticalAlignment    = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            CircularProgressIndicator(color = Red400, modifier = Modifier.size(22.dp), strokeWidth = 2.5.dp)
            Text("Submitting complaint…", color = SlateText, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun PriorityChip(
    text: String,
    isSelected: Boolean,
    color: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(6.dp))
            .background(if (isSelected) color.copy(alpha = 0.15f) else Color(0xFFF8FAFC))
            .border(
                width = if (isSelected) 1.5.dp else 1.dp,
                color = if (isSelected) color else Slate700,
                shape = RoundedCornerShape(6.dp),
            )
            .clickable { onClick() }
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text       = text,
            color      = if (isSelected) color else Slate400,
            fontSize   = 12.sp,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
        )
    }
}

// Helper
private val com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity.displayNameShort: String
    get() = when (this) {
        is com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity.Unknown  -> "Unknown caller"
        is com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity.Lead     -> name
        is com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity.Customer -> name
    }
