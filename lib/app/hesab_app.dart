import 'package:material_ui/material_ui.dart';

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
