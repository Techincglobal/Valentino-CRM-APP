import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// CRM Caller — Adaptive Design System  (Light + Dark)
// ============================================================================

// ── Brand tokens (never change between themes) ───────────────────────────────
const _kPrimary     = Color(0xFF6366F1); // Indigo
const _kPrimaryDark = Color(0xFF4F46E5);
const _kPrimaryLight = Color(0xFF818CF8);
const _kAccent      = Color(0xFF8B5CF6); // Violet
const _kAccentLight = Color(0xFFA78BFA);
const _kSuccess     = Color(0xFF10B981);
const _kDanger      = Color(0xFFEF4444);
const _kWarning     = Color(0xFFF59E0B);

class AppColors {
  AppColors._();

  // Brand
  static const primary       = _kPrimary;
  static const primaryDark   = _kPrimaryDark;
  static const primaryLight  = _kPrimaryLight;
  static const primaryGlow   = Color(0x336366F1);
  static const primarySurface = Color(0x1A6366F1);

  // Accent
  static const accent      = _kAccent;
  static const accentLight = _kAccentLight;

  // Dark palette
  static const bgBase     = Color(0xFF0A0F1E);
  static const bgCard     = Color(0xFF111827);
  static const bgCardAlt  = Color(0xFF1A2235);
  static const bgInput    = Color(0xFF1E293B);
  static const border     = Color(0xFF1E293B);
  static const borderLight = Color(0xFF2D3748);
  static const divider    = Color(0xFF1E293B);
  static const textPrimary   = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textTertiary  = Color(0xFF475569);
  static const textMuted     = Color(0xFF334155);

  // Semantic
  static const success        = _kSuccess;
  static const successSurface = Color(0x1A10B981);
  static const danger         = _kDanger;
  static const dangerSurface  = Color(0x1AEF4444);
  static const warning        = _kWarning;
  static const warningSurface = Color(0x1AF59E0B);

  // Type chips
  static const lead        = Color(0xFF8B5CF6);
  static const opportunity = _kSuccess;
  static const customer    = _kPrimary;

  // Surfaces / legacy aliases
  static const surface    = bgCard;
  static const glassBg    = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x26FFFFFF);
}

// ── Adaptive color helper ────────────────────────────────────────────────────
// LIGHT equivalents accessed via Theme.of(context).extension<AdaptiveColors>()

class AdaptiveColors extends ThemeExtension<AdaptiveColors> {
  final Color bgBase;
  final Color bgCard;
  final Color bgCardAlt;
  final Color bgInput;
  final Color border;
  final Color borderLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;

  const AdaptiveColors({
    required this.bgBase,
    required this.bgCard,
    required this.bgCardAlt,
    required this.bgInput,
    required this.border,
    required this.borderLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
  });

  static const dark = AdaptiveColors(
    bgBase:        Color(0xFF0A0F1E),
    bgCard:        Color(0xFF111827),
    bgCardAlt:     Color(0xFF1A2235),
    bgInput:       Color(0xFF1E293B),
    border:        Color(0xFF1E293B),
    borderLight:   Color(0xFF2D3748),
    textPrimary:   Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textTertiary:  Color(0xFF64748B),
    textMuted:     Color(0xFF334155),
  );

  static const light = AdaptiveColors(
    bgBase:        Color(0xFFF1F5F9),
    bgCard:        Color(0xFFFFFFFF),
    bgCardAlt:     Color(0xFFF8FAFC),
    bgInput:       Color(0xFFF1F5F9),
    border:        Color(0xFFE2E8F0),
    borderLight:   Color(0xFFCBD5E1),
    textPrimary:   Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textTertiary:  Color(0xFF94A3B8),
    textMuted:     Color(0xFFCBD5E1),
  );

  @override
  AdaptiveColors copyWith({
    Color? bgBase, Color? bgCard, Color? bgCardAlt, Color? bgInput,
    Color? border, Color? borderLight,
    Color? textPrimary, Color? textSecondary, Color? textTertiary, Color? textMuted,
  }) {
    return AdaptiveColors(
      bgBase:        bgBase        ?? this.bgBase,
      bgCard:        bgCard        ?? this.bgCard,
      bgCardAlt:     bgCardAlt     ?? this.bgCardAlt,
      bgInput:       bgInput       ?? this.bgInput,
      border:        border        ?? this.border,
      borderLight:   borderLight   ?? this.borderLight,
      textPrimary:   textPrimary   ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary:  textTertiary  ?? this.textTertiary,
      textMuted:     textMuted     ?? this.textMuted,
    );
  }

  @override
  AdaptiveColors lerp(AdaptiveColors? other, double t) {
    if (other == null) return this;
    return AdaptiveColors(
      bgBase:        Color.lerp(bgBase, other.bgBase, t)!,
      bgCard:        Color.lerp(bgCard, other.bgCard, t)!,
      bgCardAlt:     Color.lerp(bgCardAlt, other.bgCardAlt, t)!,
      bgInput:       Color.lerp(bgInput, other.bgInput, t)!,
      border:        Color.lerp(border, other.border, t)!,
      borderLight:   Color.lerp(borderLight, other.borderLight, t)!,
      textPrimary:   Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary:  Color.lerp(textTertiary, other.textTertiary, t)!,
      textMuted:     Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

// Quick convenience getter
extension AdaptiveColorsX on BuildContext {
  AdaptiveColors get ac =>
      Theme.of(this).extension<AdaptiveColors>() ?? AdaptiveColors.dark;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ── ThemeData factories ───────────────────────────────────────────────────────

class CrmTheme {
  CrmTheme._();

  static ThemeData dark() => _build(Brightness.dark, AdaptiveColors.dark);
  static ThemeData light() => _build(Brightness.light, AdaptiveColors.light);

  static ThemeData _build(Brightness brightness, AdaptiveColors ac) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _kPrimary,
        brightness: brightness,
        primary:   _kPrimary,
        onPrimary: Colors.white,
        surface:   ac.bgCard,
        onSurface: ac.textPrimary,
      ),
      scaffoldBackgroundColor: ac.bgBase,
      splashFactory:    NoSplash.splashFactory,
      highlightColor:   Colors.transparent,
      popupMenuTheme: PopupMenuThemeData(
        color: ac.bgCard,
        textStyle: TextStyle(color: ac.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
      ),
      dividerTheme: DividerThemeData(color: ac.border),
      extensions: [ac],
    );
  }
}

// ── System UI ─────────────────────────────────────────────────────────────────

void setSystemUIOverlay(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: isDark ? AppColors.bgBase : const Color(0xFFF1F5F9),
    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
  ));
}

// ── GradientScaffold ──────────────────────────────────────────────────────────

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
    return Scaffold(
      backgroundColor: context.ac.bgBase,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

// ── GlassCard ─────────────────────────────────────────────────────────────────

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
    final ac = context.ac;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? ac.bgCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: ac.borderLight, width: 1.0),
        boxShadow: context.isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: child,
    );
  }
}

// ── AppButton ─────────────────────────────────────────────────────────────────

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
    final c1 = widget.color ?? _kPrimary;
    final c2 = widget.colorEnd ?? _kPrimaryDark;
    final isDisabled = widget.onTap == null && !widget.loading;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp:   (_) => setState(() => _pressed = false),
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
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
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

// ── AppOutlineButton ──────────────────────────────────────────────────────────

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
    final c = color ?? context.ac.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.ac.bgInput,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.ac.borderLight),
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
              Text(label,
                  style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AppTextField ──────────────────────────────────────────────────────────────

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
    final ac = context.ac;
    return TextField(
      controller: controller,
      maxLines: obscureText ? 1 : maxLines,
      autofocus: autofocus,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: ac.textPrimary,
        fontSize: 15,
        letterSpacing: -0.2,
      ),
      cursorColor: _kPrimary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: ac.textTertiary, fontSize: 14),
        prefixIcon: icon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon, color: ac.textTertiary, size: 20),
              )
            : null,
        prefixIconConstraints: icon != null
            ? const BoxConstraints(minWidth: 44, minHeight: 0)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: ac.bgInput,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: maxLines > 1 ? 16 : 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ac.borderLight, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
      ),
    );
  }
}

// ── AppFieldLabel ─────────────────────────────────────────────────────────────

class AppFieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const AppFieldLabel({super.key, required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: context.ac.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
        children: required
            ? [
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: _kDanger, fontWeight: FontWeight.w700),
                ),
              ]
            : [],
      ),
    );
  }
}

// ── AppTypeChip ───────────────────────────────────────────────────────────────

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

// ── AppSheetContainer ─────────────────────────────────────────────────────────

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
    final ac = context.ac;
    return Container(
      decoration: BoxDecoration(
        color: ac.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: ac.borderLight)),
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
          color: context.ac.textMuted,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color typeColor(String type) {
  switch (type.toLowerCase()) {
    case 'lead':        return AppColors.lead;
    case 'opportunity': return AppColors.opportunity;
    case 'customer':    return AppColors.customer;
    default:            return AppColors.textSecondary;
  }
}

String initials(String name) {
  if (name.isEmpty) return '?';
  final parts = name.trim().split(' ');
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
