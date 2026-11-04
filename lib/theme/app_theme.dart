import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.input,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.success,
    required this.warning,
    required this.danger,
    required this.onDanger,
  });

  final Color background, surface, surfaceElevated, input;
  final Color accent, accentSoft, onAccent;
  final Color textPrimary, textSecondary, border;
  final Color success, warning, danger, onDanger;

  static const dark = AppPalette(
    background: Color(0xFF101211),
    surface: Color(0xFF1A1D1B),
    surfaceElevated: Color(0xFF242824),
    input: Color(0xFF141715),
    accent: Color(0xFFE6B86A),
    accentSoft: Color(0xFF332819),
    onAccent: Color(0xFF241707),
    textPrimary: Color(0xFFF4F3EE),
    textSecondary: Color(0xFFACB1AA),
    border: Color(0xFF3B403B),
    success: Color(0xFF64D8A7),
    warning: Color(0xFFFFC96B),
    danger: Color(0xFFFF6B73),
    onDanger: Color(0xFF210004),
  );

  static const light = AppPalette(
    background: Color(0xFFF5F7F3),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEDF1EA),
    input: Color(0xFFF4F6F2),
    accent: Color(0xFF72501F),
    accentSoft: Color(0xFFF1E4CD),
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF20251F),
    textSecondary: Color(0xFF59645B),
    border: Color(0xFFD7DED5),
    success: Color(0xFF176348),
    warning: Color(0xFF8B5B08),
    danger: Color(0xFFB33C46),
    onDanger: Color(0xFFFFFFFF),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? dark;

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color blend(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: blend(background, other.background),
      surface: blend(surface, other.surface),
      surfaceElevated: blend(surfaceElevated, other.surfaceElevated),
      input: blend(input, other.input),
      accent: blend(accent, other.accent),
      accentSoft: blend(accentSoft, other.accentSoft),
      onAccent: blend(onAccent, other.onAccent),
      textPrimary: blend(textPrimary, other.textPrimary),
      textSecondary: blend(textSecondary, other.textSecondary),
      border: blend(border, other.border),
      success: blend(success, other.success),
      warning: blend(warning, other.warning),
      danger: blend(danger, other.danger),
      onDanger: blend(onDanger, other.onDanger),
    );
  }
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;
}

abstract final class AppRadii {
  static const small = 10.0;
  static const medium = 14.0;
  static const large = 18.0;
  static const sheet = 20.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;
}

abstract final class AppTheme {
  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);
  static ThemeData get light => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette colors, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
        ).copyWith(
          primary: colors.accent,
          onPrimary: colors.onAccent,
          secondary: colors.accent,
          onSecondary: colors.onAccent,
          surface: colors.surface,
          onSurface: colors.textPrimary,
          error: colors.danger,
          onError: colors.onDanger,
          outline: colors.border,
          outlineVariant: colors.border,
        );
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      visualDensity: VisualDensity.standard,
      extensions: [colors],
    );
    final text = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        color: colors.textPrimary,
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: colors.textPrimary,
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        color: colors.textPrimary,
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: colors.textPrimary,
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: colors.textPrimary,
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: colors.textPrimary,
        fontSize: 16,
        height: 1.45,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: colors.textPrimary,
        fontSize: 14,
        height: 1.45,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: colors.textSecondary,
        fontSize: 12,
        height: 1.4,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      borderSide: BorderSide(color: colors.border),
    );
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.input,
        labelStyle: TextStyle(color: colors.textSecondary),
        hintStyle: TextStyle(color: colors.textSecondary),
        errorStyle: TextStyle(color: colors.danger),
        errorMaxLines: 2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.danger),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.danger, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: colors.onAccent,
          backgroundColor: colors.accent,
          disabledForegroundColor: colors.textSecondary,
          disabledBackgroundColor: colors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.textPrimary,
        foregroundColor: colors.background,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surface,
        selectedColor: colors.accentSoft,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        labelStyle: text.labelLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: text.bodyMedium,
        actionTextColor: colors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.input,
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        textStyle: text.bodySmall?.copyWith(color: colors.textPrimary),
      ),
    );
  }
}
