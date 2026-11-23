import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/theme/hesab_theme.dart';
import 'hesab_services.dart';
import 'hesab_shell.dart';

class HesabApp extends StatefulWidget {
  const HesabApp({
    required this.services,
    required this.onDatabaseChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final HesabServices services;
  final VoidCallback onDatabaseChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<HesabApp> createState() => _HesabAppState();
}

class _HesabAppState extends State<HesabApp> {
  static const _windowChannel = MethodChannel('hesab/window');

  int? _lastCaptionBackground;
  int? _lastCaptionForeground;

  void _toggleTheme(bool isDarkMode) {
    final mode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    widget.onThemeModeChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حساب',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'AF'),
      supportedLocales: const [Locale('fa', 'AF')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: HesabTheme.light,
      darkTheme: HesabTheme.dark,
      themeMode: widget.themeMode,
      builder: (context, child) {
        final colors = Theme.of(context).colorScheme;
        final captionBackground = colors.primary.toARGB32();
        final captionForeground = colors.onPrimary.toARGB32();
        if (defaultTargetPlatform == TargetPlatform.windows &&
            (_lastCaptionBackground != captionBackground ||
                _lastCaptionForeground != captionForeground)) {
          _lastCaptionBackground = captionBackground;
          _lastCaptionForeground = captionForeground;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(
              _windowChannel.invokeMethod<void>('setCaptionColors', {
                'background': captionBackground,
                'foreground': captionForeground,
              }),
            );
          });
        }
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Builder(
        builder: (context) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          return HesabShell(
            services: widget.services,
            onDatabaseChanged: widget.onDatabaseChanged,
            onToggleTheme: () => _toggleTheme(isDarkMode),
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }
}
