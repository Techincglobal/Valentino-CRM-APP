import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// CRM Caller — Premium Dark Design System
// ============================================================================

class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF6366F1); // Indigo
  static const primaryDark = Color(0xFF4F46E5);
  static const primaryLight = Color(0xFF818CF8);
  static const primaryGlow = Color(0x336366F1);
  static const primarySurface = Color(0x1A6366F1);

  // Accent
  static const accent = Color(0xFF8B5CF6); // Violet
  static const accentLight = Color(0xFFA78BFA);

  // Page background (dark)
  static const bgBase = Color(0xFF0A0F1E); // Very dark navy
  static const bgCard = Color(0xFF111827); // Card surface
  static const bgCardAlt = Color(0xFF1A2235); // Slightly lighter card
  static const bgInput = Color(0xFF1E293B); // Input background

  // Borders
  static const border = Color(0xFF1E293B);
  static const borderLight = Color(0xFF2D3748);
  static const divider = Color(0xFF1E293B);

  // Text
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textTertiary = Color(0xFF475569);
  static const textMuted = Color(0xFF334155);

  // Semantic
  static const success = Color(0xFF10B981);
  static const successSurface = Color(0x1A10B981);
  static const danger = Color(0xFFEF4444);
  static const dangerSurface = Color(0x1AEF4444);
  static const warning = Color(0xFFF59E0B);
  static const warningSurface = Color(0x1AF59E0B);

  // Type chips
  static const lead = Color(0xFF8B5CF6);
  static const opportunity = Color(0xFF10B981);
  static const customer = Color(0xFF6366F1);

  // Surfaces / Glass (kept for overlay_bubble compatibility)
  static const surface = bgCard;
  static const glassBg = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x26FFFFFF);
}

// ── System UI ----------------------------------------------------------------

void setSystemUIOverlay() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bgBase,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
}

// ── Base Scaffold ────────────────────────────────────────────────────────────

class GradientScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;

  const GradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    setSystemUIOverlay();
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

// ── Card ─────────────────────────────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.bgCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.borderLight, width: 1.0),
      ),
      child: child,
    );
  }
}

// ── Primary Button ────────────────────────────────────────────────────────────

class AppButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onTap;
  final Color? color;
  final Color? colorEnd;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.loading = false,
    this.onTap,
    this.color,
    this.colorEnd,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c1 = widget.color ?? AppColors.primary;
    final c2 = widget.colorEnd ?? AppColors.primaryDark;
    final isDisabled = widget.onTap == null && !widget.loading;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.loading ? null : widget.onTap,
      child: AnimatedScale(
        scale: _pressed && !widget.loading ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDisabled
                  ? [c1.withValues(alpha: 0.35), c2.withValues(alpha: 0.35)]
                  : [c1, c2],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: c1.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Outline Button ────────────────────────────────────────────────────────────

class AppOutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;

  const AppOutlineButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: c, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Text Field ────────────────────────────────────────────────────────────────

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final int maxLines;
  final bool autofocus;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.maxLines = 1,
    this.autofocus = false,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: obscureText ? 1 : maxLines,
      autofocus: autofocus,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        letterSpacing: -0.2,
      ),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
        prefixIcon: icon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon, color: AppColors.textTertiary, size: 20),
              )
            : null,
        prefixIconConstraints: icon != null
            ? const BoxConstraints(minWidth: 44, minHeight: 0)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.bgInput,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: maxLines > 1 ? 16 : 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ── Field Label ───────────────────────────────────────────────────────────────

class AppFieldLabel extends StatelessWidget {
  final String label;
  final bool required;

  const AppFieldLabel({super.key, required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
        children: required
            ? [
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
                ),
              ]
            : [],
      ),
    );
  }
}

// ── Type Chip ─────────────────────────────────────────────────────────────────

class AppTypeChip extends StatelessWidget {
  final String label;
  final Color color;

  const AppTypeChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Sheet Container ───────────────────────────────────────────────────────────

class AppSheetContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const AppSheetContainer({
    super.key,
    required this.child,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      padding: padding,
      child: child,
    );
  }
}

class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 20),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textMuted,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color typeColor(String type) {
  switch (type.toLowerCase()) {
    case 'lead':
      return AppColors.lead;
    case 'opportunity':
      return AppColors.opportunity;
    case 'customer':
      return AppColors.customer;
    default:
      return AppColors.textSecondary;
  }
}

String initials(String name) {
  if (name.isEmpty) return '?';
  final parts = name.trim().split(' ');
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
