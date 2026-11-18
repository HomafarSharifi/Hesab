import 'package:material_ui/material_ui.dart';

import '../core/theme/hesab_theme.dart';
import 'hesab_services.dart';
import 'hesab_shell.dart';

class HesabApp extends StatefulWidget {
  const HesabApp({required this.services, super.key});

  final HesabServices services;

  @override
  State<HesabApp> createState() => _HesabAppState();
}

class _HesabAppState extends State<HesabApp> {
  ThemeMode? _themeMode;

  void _toggleTheme(bool isDarkMode) => setState(
    () => _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark,
  );

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
      themeMode: _themeMode ?? ThemeMode.system,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Builder(
        builder: (context) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          return HesabShell(
            services: widget.services,
            onToggleTheme: () => _toggleTheme(isDarkMode),
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }
}
