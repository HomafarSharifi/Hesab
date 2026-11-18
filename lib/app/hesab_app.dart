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
  bool _darkMode = false;

  void _toggleTheme() => setState(() => _darkMode = !_darkMode);

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
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: HesabShell(
        services: widget.services,
        onToggleTheme: _toggleTheme,
        isDarkMode: _darkMode,
      ),
    );
  }
}
