package com.example.crm_caller_nxtgen.overlay.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Notes
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
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
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.crm_caller_nxtgen.overlay.domain.ActiveSheet
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent

// ─────────────────────────────────────────────────────────────────────────────
// Brand accent colours (not theme-sensitive)
// ─────────────────────────────────────────────────────────────────────────────
private val AccentIndigo = Color(0xFF2490EF) // brand blue (kept name for minimal diff)
private val AccentAmber  = Color(0xFFF59E0B)
private val AccentRed    = Color(0xFFEF4444)
private val AccentGreen  = Color(0xFF22C55E)
private val AccentBlue   = AccentIndigo

// ─────────────────────────────────────────────────────────────────────────────
// Validation helpers
// ─────────────────────────────────────────────────────────────────────────────
private val EMAIL_RE = Regex("^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$")

private fun validateName(v: String): String? = when {
    v.isBlank()  -> "Name is required"
    v.length < 2 -> "Name must be at least 2 characters"
    else         -> null
}

private fun validateEmail(v: String): String? {
    if (v.isBlank()) return null          // email is optional
    if (!v.contains('@'))
        return "Missing @ — e.g. name@company.com"
    val parts = v.split('@')
    if (parts.size != 2 || parts[1].isBlank())
        return "Add the domain after @ — e.g. name@company.com"
    if (!parts[1].contains('.'))
        return "Add a domain extension — e.g. .com or .net"
    if (!EMAIL_RE.matches(v))
        return "Invalid email — e.g. name@company.com"
    return null
}

// ─────────────────────────────────────────────────────────────────────────────
// Main form
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun UnknownCallerForm(
    phone: String,
    activeSheet: ActiveSheet = ActiveSheet.NONE,
    onEvent: (OverlayEvent) -> Unit,
    onSubmit: (name: String, email: String, company: String, note: String) -> Unit,
) {
    var name    by remember { mutableStateOf("") }
    var email   by remember { mutableStateOf("") }
    var company by remember { mutableStateOf("") }
    var note    by remember { mutableStateOf("") }

    var nameError  by remember { mutableStateOf<String?>(null) }
    var emailError by remember { mutableStateOf<String?>(null) }

    // touched flags — only show errors after the user has left a field
    var nameTouched  by remember { mutableStateOf(false) }
    var emailTouched by remember { mutableStateOf(false) }

    fun submit() {
        // Force-touch both validated fields
        nameTouched  = true
        emailTouched = true
        nameError    = validateName(name.trim())
        emailError   = validateEmail(email.trim())
        if (nameError == null && emailError == null) {
            onSubmit(name.trim(), email.trim(), company.trim(), note.trim())
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {

        // ── Caller banner ─────────────────────────────────────────────────────
        CallerBanner(phone)

        Spacer(Modifier.height(14.dp))
        HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f), thickness = 1.dp)
        Spacer(Modifier.height(14.dp))

        // ── Section header ────────────────────────────────────────────────────
        Row(
            verticalAlignment     = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(width = 3.dp, height = 16.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(AccentIndigo),
            )
            Text(
                text          = "CREATE NEW LEAD",
                color         = AccentIndigo,
                fontSize      = 11.sp,
                fontWeight    = FontWeight.ExtraBold,
                letterSpacing = 1.4.sp,
            )
        }

        Spacer(Modifier.height(12.dp))

        // ── Full name (required) ──────────────────────────────────────────────
        val nameValid = nameTouched && nameError == null && name.isNotBlank()
        ValidatedField(
            value         = name,
            onValueChange = {
                name = it
                if (nameTouched) nameError = validateName(it.trim())
            },
            onFocusLost   = {
                nameTouched = true
                nameError   = validateName(name.trim())
            },
            label         = "Full name *",
            icon          = Icons.Default.Person,
            error         = if (nameTouched) nameError else null,
            isValid       = nameValid,
            keyboardOptions = KeyboardOptions(
                keyboardType    = KeyboardType.Text,
                capitalization  = KeyboardCapitalization.Words,
            ),
        )

        Spacer(Modifier.height(8.dp))

        // ── Email (optional, validated if entered) ────────────────────────────
        val emailValid = emailTouched && emailError == null && email.isNotBlank()
        ValidatedField(
            value         = email,
            onValueChange = {
                email = it
                if (emailTouched) emailError = validateEmail(it.trim())
            },
            onFocusLost   = {
                emailTouched = true
                emailError   = validateEmail(email.trim())
            },
            label         = "Email",
            icon          = Icons.Default.Email,
            error         = if (emailTouched) emailError else null,
            isValid       = emailValid,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            placeholder   = "e.g. name@company.com",
        )

        Spacer(Modifier.height(8.dp))

        // ── Company (optional, no validation) ────────────────────────────────
        ValidatedField(
            value         = company,
            onValueChange = { company = it },
            onFocusLost   = {},
            label         = "Company",
            icon          = Icons.Default.Business,
            error         = null,
            isValid       = company.isNotBlank(),
            keyboardOptions = KeyboardOptions(
                keyboardType   = KeyboardType.Text,
                capitalization = KeyboardCapitalization.Words,
            ),
        )

        Spacer(Modifier.height(8.dp))

        // ── Note (optional, no validation) ───────────────────────────────────
        OutlinedTextField(
            value         = note,
            onValueChange = { note = it },
            label         = { Text("Quick note", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp) },
            placeholder   = { Text("What's this call about?", color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f), fontSize = 13.sp) },
            leadingIcon   = {
                Icon(Icons.Default.Notes, contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(18.dp))
            },
            modifier  = Modifier.fillMaxWidth(),
            colors    = fieldColors(AccentIndigo),
            shape     = RoundedCornerShape(12.dp),
            maxLines  = 3,
            minLines  = 2,
        )

        Spacer(Modifier.height(12.dp))

        // ── Create Lead button ────────────────────────────────────────────────
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(
                    Brush.horizontalGradient(
                        listOf(AccentIndigo, Color(0xFF1A7FD4))
                    )
                )
                .then(
                    if (name.isBlank()) Modifier.background(AccentIndigo.copy(alpha = 0.35f))
                    else Modifier
                ),
        ) {
            Button(
                onClick  = ::submit,
                modifier = Modifier.fillMaxWidth().height(52.dp),
                enabled  = name.isNotBlank(),
                colors   = ButtonDefaults.buttonColors(
                    containerColor         = Color.Transparent,
                    disabledContainerColor = Color.Transparent,
                ),
                shape = RoundedCornerShape(14.dp),
            ) {
                Icon(
                    imageVector        = Icons.Default.Person,
                    contentDescription = null,
                    tint               = Color.White,
                    modifier           = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text          = "Create Lead & Save",
                    fontWeight    = FontWeight.Bold,
                    color         = Color.White,
                    fontSize      = 15.sp,
                    letterSpacing = 0.3.sp,
                )
            }
        }

        Spacer(Modifier.height(4.dp))

        // ── Secondary actions row ─────────────────────────────────────────────
        Row(
            modifier              = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            TextButton(
                onClick  = { onEvent(OverlayEvent.OpenComplaintPopup) },
                modifier = Modifier.weight(1f),
            ) {
                Icon(Icons.Default.Warning, null, tint = AccentRed.copy(alpha = 0.75f), modifier = Modifier.size(13.dp))
                Spacer(Modifier.width(4.dp))
                Text("Log a Ticket", color = AccentRed.copy(alpha = 0.75f), fontSize = 11.sp, fontWeight = FontWeight.Medium)
            }
            TextButton(
                onClick  = { onEvent(OverlayEvent.OpenLogCallForm) },
                modifier = Modifier.weight(1f),
            ) {
                Icon(Icons.Default.Phone, null, tint = AccentBlue.copy(alpha = 0.75f), modifier = Modifier.size(13.dp))
                Spacer(Modifier.width(4.dp))
                Text("Log Call", color = AccentBlue.copy(alpha = 0.75f), fontSize = 11.sp, fontWeight = FontWeight.Medium)
            }
        }

        // ── Log Call inline form ──────────────────────────────────────────────
        AnimatedVisibility(
            visible = activeSheet == ActiveSheet.LOG_CALL,
            enter   = fadeIn() + expandVertically(),
            exit    = fadeOut() + shrinkVertically(),
        ) {
            LogCallInlineForm(
                isDark      = false,
                isWhatsApp  = phone.startsWith("wa:"),
                onCancel    = { onEvent(OverlayEvent.CancelSheet) },
                onSubmit    = { notes, callType -> onEvent(OverlayEvent.SubmitCallLog(notes, callType)) },
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable validated field
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun ValidatedField(
    value: String,
    onValueChange: (String) -> Unit,
    onFocusLost: () -> Unit,
    label: String,
    icon: ImageVector,
    error: String?,
    isValid: Boolean,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    placeholder: String? = null,
) {
    val hasError = error != null
    val onSurfaceVariant = MaterialTheme.colorScheme.onSurfaceVariant
    val surfaceVariant   = MaterialTheme.colorScheme.surfaceVariant
    val onSurface        = MaterialTheme.colorScheme.onSurface
    val borderColor = when {
        hasError -> AccentRed
        isValid  -> AccentGreen
        else     -> onSurface.copy(alpha = 0.08f)
    }

    Column {
        OutlinedTextField(
            value         = value,
            onValueChange = onValueChange,
            label         = {
                Text(label, fontSize = 13.sp,
                    color = when {
                        hasError -> AccentRed
                        isValid  -> AccentGreen
                        else     -> onSurfaceVariant
                    })
            },
            placeholder = if (placeholder != null) {
                { Text(placeholder, color = onSurfaceVariant.copy(alpha = 0.6f), fontSize = 13.sp) }
            } else null,
            leadingIcon = {
                Icon(
                    imageVector        = icon,
                    contentDescription = null,
                    tint               = when {
                        hasError -> AccentRed
                        isValid  -> AccentGreen
                        else     -> onSurfaceVariant
                    },
                    modifier = Modifier.size(18.dp),
                )
            },
            trailingIcon = when {
                hasError -> { ->
                    Icon(Icons.Default.Warning, contentDescription = "Error",
                        tint = AccentRed, modifier = Modifier.size(18.dp))
                }
                isValid -> { ->
                    Icon(Icons.Default.Check, contentDescription = "Valid",
                        tint = AccentGreen, modifier = Modifier.size(18.dp))
                }
                else -> null
            },
            isError         = hasError,
            modifier        = Modifier
                .fillMaxWidth()
                .onFocusChanged { if (!it.isFocused) onFocusLost() },
            colors          = OutlinedTextFieldDefaults.colors(
                focusedBorderColor        = if (hasError) AccentRed else if (isValid) AccentGreen else AccentIndigo,
                unfocusedBorderColor      = borderColor,
                focusedTextColor          = onSurface,
                unfocusedTextColor        = onSurface,
                focusedLabelColor         = if (hasError) AccentRed else if (isValid) AccentGreen else AccentIndigo,
                unfocusedLabelColor       = if (hasError) AccentRed else if (isValid) AccentGreen else onSurfaceVariant,
                cursorColor               = if (hasError) AccentRed else AccentIndigo,
                focusedContainerColor     = surfaceVariant,
                unfocusedContainerColor   = surfaceVariant,
                errorBorderColor          = AccentRed,
                errorLabelColor           = AccentRed,
                errorLeadingIconColor     = AccentRed,
                errorCursorColor          = AccentRed,
                focusedLeadingIconColor   = if (hasError) AccentRed else if (isValid) AccentGreen else AccentIndigo,
                unfocusedLeadingIconColor = if (hasError) AccentRed else if (isValid) AccentGreen else onSurfaceVariant,
            ),
            shape           = RoundedCornerShape(12.dp),
            singleLine      = true,
            keyboardOptions = keyboardOptions,
        )

        // Animated error message
        AnimatedVisibility(
            visible = hasError,
            enter   = fadeIn() + expandVertically(),
            exit    = fadeOut() + shrinkVertically(),
        ) {
            Row(
                modifier              = Modifier.padding(start = 14.dp, top = 4.dp),
                verticalAlignment     = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(
                    imageVector        = Icons.Default.Warning,
                    contentDescription = null,
                    tint               = AccentRed,
                    modifier           = Modifier.size(12.dp),
                )
                Text(
                    text       = error ?: "",
                    color      = AccentRed,
                    fontSize   = 11.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Caller banner
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun CallerBanner(phone: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(AccentAmber.copy(alpha = 0.08f))
            .border(1.dp, AccentAmber.copy(alpha = 0.22f), RoundedCornerShape(14.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(
            verticalAlignment     = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(AccentAmber.copy(alpha = 0.12f))
                    .border(1.5.dp, AccentAmber.copy(alpha = 0.35f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector        = Icons.Default.Phone,
                    contentDescription = null,
                    tint               = AccentAmber,
                    modifier           = Modifier.size(20.dp),
                )
            }
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(
                    text       = if (phone == "Hidden") "Hidden Number" else phone,
                    color      = MaterialTheme.colorScheme.onSurface,
                    fontSize   = 16.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text     = "Not in your CRM — create a lead below",
                    color    = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 11.sp,
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field colour helper (used by the note field which has no validation state)
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun darkFieldColors(accent: Color, error: Color = AccentRed) = fieldColors(accent, error)

@Composable
fun fieldColors(accent: Color, error: Color = AccentRed) = OutlinedTextFieldDefaults.colors(
    focusedBorderColor        = accent,
    unfocusedBorderColor      = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
    focusedTextColor          = MaterialTheme.colorScheme.onSurface,
    unfocusedTextColor        = MaterialTheme.colorScheme.onSurface,
    disabledTextColor         = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
    disabledBorderColor       = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
    disabledLabelColor        = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
    focusedLabelColor         = accent,
    unfocusedLabelColor       = MaterialTheme.colorScheme.onSurfaceVariant,
    cursorColor               = accent,
    focusedContainerColor     = MaterialTheme.colorScheme.surfaceVariant,
    unfocusedContainerColor   = MaterialTheme.colorScheme.surfaceVariant,
    disabledContainerColor    = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
    focusedLeadingIconColor   = accent,
    unfocusedLeadingIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
    disabledLeadingIconColor  = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
    errorBorderColor          = error,
    errorLabelColor           = error,
    errorLeadingIconColor     = error,
    errorCursorColor          = error,
)
