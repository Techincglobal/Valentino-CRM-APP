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
import androidx.compose.foundation.isSystemInDarkTheme
import com.example.crm_caller_nxtgen.overlay.domain.ComplaintPopupState
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent

// Light palette
private val Red500        = Color(0xFFEF4444)
private val Emerald500    = Color(0xFF10B981)
private val Amber500      = Color(0xFFF59E0B)
private val TextPrimary   = Color(0xFF0F172A)
private val TextSecondary = Color(0xFF64748B)
private val TextMuted     = Color(0xFF94A3B8)
private val BorderLight   = Color(0xFFE2E8F0)
private val SurfaceLight  = Color(0xFFF8FAFC)
private val White         = Color(0xFFFFFFFF)

/**
 * Root composable for the second WindowManager window — complaint popup.
 * Light white design with red accent. Appears centred with dim behind.
 */
@Composable
fun ComplaintPopupRoot(
    complaintState: ComplaintPopupState,
    onEvent: (OverlayEvent) -> Unit,
) {
    val isDark = isSystemInDarkTheme()
    MaterialTheme(colorScheme = if (isDark) OverlayThemeDark else OverlayThemeLight) {
        AnimatedVisibility(
            visible = complaintState !is ComplaintPopupState.Hidden,
            enter   = slideInVertically(initialOffsetY = { it / 5 }) + fadeIn(),
            exit    = slideOutVertically(targetOffsetY = { it / 5 }) + fadeOut(),
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

    val isDark = isSystemInDarkTheme()
    val fieldColors = OutlinedTextFieldDefaults.colors(
        focusedBorderColor      = Red500,
        unfocusedBorderColor    = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f),
        focusedTextColor        = MaterialTheme.colorScheme.onSurface,
        unfocusedTextColor      = MaterialTheme.colorScheme.onSurface,
        focusedLabelColor       = Red500,
        unfocusedLabelColor     = MaterialTheme.colorScheme.onSurfaceVariant,
        cursorColor             = Red500,
        focusedContainerColor   = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = if (isDark) 0.5f else 0.7f),
        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = if (isDark) 0.3f else 0.5f),
    )

    Surface(
        modifier = Modifier
            .fillMaxWidth(0.92f)
            .shadow(
                elevation    = 32.dp,
                shape        = RoundedCornerShape(28.dp),
                ambientColor = Color.Black.copy(alpha = 0.40f),
                spotColor    = Red500.copy(alpha = 0.25f),
            ),
        shape           = RoundedCornerShape(28.dp),
        color           = MaterialTheme.colorScheme.surface.copy(alpha = if (isDark) 0.95f else 0.98f),
        tonalElevation  = 0.dp,
        border          = androidx.compose.foundation.BorderStroke(
            1.5.dp,
            androidx.compose.ui.graphics.Brush.linearGradient(
                listOf(
                    MaterialTheme.colorScheme.onSurface.copy(alpha = if (isDark) 0.20f else 0.12f),
                    MaterialTheme.colorScheme.onSurface.copy(alpha = 0.04f)
                )
            )
        )
    ) {
        Column(modifier = Modifier.padding(20.dp)) {

            // Header
            Row(
                modifier              = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment     = Alignment.CenterVertically,
            ) {
                Column {
                    // Red accent strip
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(4.dp))
                            .background(Red500.copy(alpha = 0.10f))
                            .padding(horizontal = 8.dp, vertical = 3.dp),
                    ) {
                        Text(
                            "SUPPORT TICKET",
                            color         = Red500,
                            fontSize      = 10.sp,
                            fontWeight    = FontWeight.Bold,
                            letterSpacing = 1.sp,
                        )
                    }
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text       = "Log a Ticket",
                        color      = MaterialTheme.colorScheme.onSurface,
                        fontSize   = 18.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text     = state.identity.displayNameShort,
                        color    = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 12.sp,
                    )
                }
                IconButton(
                    onClick  = { onEvent(OverlayEvent.CloseComplaintPopup) },
                    modifier = Modifier
                        .size(34.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f))
                        .border(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f), CircleShape),
                ) {
                    Icon(
                        imageVector        = Icons.Default.Close,
                        contentDescription = "Cancel",
                        tint               = TextSecondary,
                        modifier           = Modifier.size(16.dp),
                    )
                }
            }

            HorizontalDivider(
                modifier  = Modifier.padding(vertical = 14.dp),
                color     = BorderLight,
                thickness = 1.dp,
            )

            // Priority chips
            Text(
                "Priority",
                color         = TextMuted,
                fontSize      = 11.sp,
                fontWeight    = FontWeight.Bold,
                letterSpacing = 0.5.sp,
            )
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("Low" to Emerald500, "Medium" to Amber500, "High" to Red500).forEach { (p, color) ->
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

            // Category
            OutlinedTextField(
                value         = category,
                onValueChange = { category = it },
                label         = { Text("Subject / Category") },
                modifier      = Modifier.fillMaxWidth(),
                colors        = fieldColors,
                shape         = RoundedCornerShape(12.dp),
                singleLine    = true,
            )

            Spacer(Modifier.height(10.dp))

            // Details
            OutlinedTextField(
                value         = details,
                onValueChange = { details = it },
                label         = { Text("Details") },
                modifier      = Modifier.fillMaxWidth(),
                colors        = fieldColors,
                shape         = RoundedCornerShape(12.dp),
                maxLines      = 3,
                minLines      = 3,
            )

            Spacer(Modifier.height(16.dp))

            // Actions
            Row(
                modifier              = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                TextButton(
                    onClick  = { onEvent(OverlayEvent.CloseComplaintPopup) },
                    modifier = Modifier.weight(1f),
                ) {
                    Text("Cancel", color = TextMuted, fontWeight = FontWeight.Medium)
                }

                Button(
                    onClick  = {
                        onEvent(
                            OverlayEvent.SubmitComplaint(
                                category = category.trim(),
                                details  = details.trim(),
                                priority = priority,
                            )
                        )
                    },
                    modifier = Modifier
                        .weight(2f)
                        .height(48.dp),
                    enabled  = category.isNotBlank() && details.isNotBlank(),
                    colors   = ButtonDefaults.buttonColors(
                        containerColor         = Red500,
                        disabledContainerColor = Red500.copy(alpha = 0.35f),
                    ),
                    shape = RoundedCornerShape(12.dp),
                ) {
                    Text("Submit", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                }
            }
        }
    }
}

@Composable
private fun SubmittingCard() {
    Surface(
        modifier = Modifier
            .width(260.dp)
            .shadow(
                elevation    = 24.dp,
                shape        = RoundedCornerShape(24.dp),
                ambientColor = Color.Black.copy(alpha = 0.30f),
                spotColor    = Color.Black.copy(alpha = 0.35f),
            ),
        shape          = RoundedCornerShape(24.dp),
        color          = MaterialTheme.colorScheme.surface.copy(alpha = 0.85f),
        tonalElevation = 0.dp,
        border         = androidx.compose.foundation.BorderStroke(
            1.5.dp,
            androidx.compose.ui.graphics.Brush.linearGradient(
                listOf(
                    MaterialTheme.colorScheme.onSurface.copy(alpha = 0.25f),
                    MaterialTheme.colorScheme.onSurface.copy(alpha = 0.05f)
                )
            )
        )
    ) {
        Row(
            modifier              = Modifier.padding(24.dp),
            verticalAlignment     = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            CircularProgressIndicator(color = Red500, modifier = Modifier.size(22.dp), strokeWidth = 2.5.dp)
            Text("Submitting complaint…", color = TextPrimary, fontWeight = FontWeight.SemiBold)
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
            .clip(RoundedCornerShape(10.dp))
            .background(if (isSelected) color.copy(alpha = 0.12f) else SurfaceLight)
            .border(
                width = if (isSelected) 1.5.dp else 1.dp,
                color = if (isSelected) color else BorderLight,
                shape = RoundedCornerShape(10.dp),
            )
            .clickable { onClick() }
            .padding(vertical = 9.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text       = text,
            color      = if (isSelected) color else TextSecondary,
            fontSize   = 12.sp,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
        )
    }
}

private val com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity.displayNameShort: String
    get() = when (this) {
        is com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity.Unknown  -> "Unknown caller"
        is com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity.Lead     -> name
        is com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity.Customer -> name
    }
