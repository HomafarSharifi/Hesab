import 'package:material_ui/material_ui.dart';

abstract final class HesabTheme {
  static const double fontCaption = 11;
  static const double fontBody = 13;
  static const double fontControl = 14;
  static const double fontSection = 17;
  static const double fontPageTitle = 28;
  static const double fontAmount = 32;
  static const double controlHeight = 40;
  static const double sidebarActionHeight = 44;
  static const double cardRadius = 24;
  static const teal = Color(0xFF198372);
  static const paleTeal = Color(0xFFE0EEEC);
  static const canvas = Color(0xFFF2F5F4);
  static const muted = Color(0xFF737775);

  static Color selectionSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF263B36)
      : paleTeal;

  static Color summarySurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.surfaceContainerHigh
      : paleTeal;

  static Color mutedForeground(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final base = ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: brightness,
        primary: brightness == Brightness.dark ? const Color(0xFF63D6BD) : teal,
      ),
      fontFamily: 'YekanBakh',
      scaffoldBackgroundColor: brightness == Brightness.light
          ? canvas
          : const Color(0xFF151A19),
      useMaterial3: true,
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(fontFamily: 'YekanBakh')
          .copyWith(
            bodySmall: base.textTheme.bodySmall?.copyWith(
              fontSize: fontCaption,
            ),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: fontBody),
            bodyLarge: base.textTheme.bodyLarge?.copyWith(
              fontSize: fontControl,
            ),
            titleMedium: base.textTheme.titleMedium?.copyWith(
              fontSize: fontControl,
            ),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontSize: fontSection,
            ),
            headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontSize: 28,
            ),
            headlineLarge: base.textTheme.headlineLarge?.copyWith(
              fontSize: fontPageTitle,
            ),
          ),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        constraints: BoxConstraints(minHeight: controlHeight),
        contentPadding: EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(112, controlHeight),
          textStyle: const TextStyle(
            fontSize: fontControl,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(96, controlHeight),
          textStyle: const TextStyle(
            fontSize: fontControl,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(72, controlHeight)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      cardTheme: CardThemeData(
        color: base.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF202624)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: brightness == Brightness.dark
          ? const Color(0xFF343C39)
          : const Color(0xFFD4DBD8),
    );
  }
}
