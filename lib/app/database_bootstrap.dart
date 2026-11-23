import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/theme/hesab_theme.dart';
import '../core/theme/theme_mode_store.dart';
import '../data/database/hesab_database.dart';
import 'hesab_services.dart';
import 'hesab_app.dart';

class DatabaseBootstrap extends StatefulWidget {
  const DatabaseBootstrap({super.key});

  @override
  State<DatabaseBootstrap> createState() => _DatabaseBootstrapState();
}

class _DatabaseBootstrapState extends State<DatabaseBootstrap> {
  Future<Database>? _database;
  late Future<ThemeMode?> _themeModeFuture;
  ThemeMode? _themeMode;
  int _databaseRevision = 0;

  @override
  void initState() {
    super.initState();
    _database = HesabDatabase.instance.database;
    _themeModeFuture = const ThemeModeStore().load();
  }

  void _onDatabaseChanged() {
    setState(() {
      _databaseRevision++;
      _database = HesabDatabase.instance.database;
    });
  }

  void _onThemeModeChanged(ThemeMode mode) {
    setState(() => _themeMode = mode);
    unawaited(_saveThemeMode(mode));
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    try {
      await const ThemeModeStore().save(mode);
    } on Object {
      // Keep the current session usable if the preference cannot be written.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ThemeMode?>(
      future: _themeModeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasError) {
          // Avoid showing a light splash while the saved theme is being read.
          return const SizedBox.shrink();
        }
        _themeMode ??= snapshot.hasError
            ? ThemeMode.system
            : snapshot.data ?? ThemeMode.system;
        return FutureBuilder<Database>(
          future: _database,
          builder: (context, databaseSnapshot) {
            if (databaseSnapshot.hasError) {
              return _DatabaseErrorApp(themeMode: _themeMode!);
            }
            if (databaseSnapshot.connectionState != ConnectionState.done) {
              return _DatabaseLoadingApp(themeMode: _themeMode!);
            }
            return HesabApp(
              key: ValueKey(_databaseRevision),
              services: HesabServices(databaseSnapshot.data!),
              onDatabaseChanged: _onDatabaseChanged,
              themeMode: _themeMode!,
              onThemeModeChanged: _onThemeModeChanged,
            );
          },
        );
      },
    );
  }
}

class _DatabaseLoadingApp extends StatelessWidget {
  const _DatabaseLoadingApp({required this.themeMode});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('fa', 'AF'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: HesabTheme.light,
    darkTheme: HesabTheme.dark,
    themeMode: themeMode,
    home: const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text('دیتابیس آماده می‌شود…'),
          ],
        ),
      ),
    ),
  );
}

class _DatabaseErrorApp extends StatelessWidget {
  const _DatabaseErrorApp({required this.themeMode});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('fa', 'AF'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: HesabTheme.light,
    darkTheme: HesabTheme.dark,
    themeMode: themeMode,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storage_rounded, size: 48),
              const SizedBox(height: 16),
              Text(
                'دیتابیس باز نشد.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'دسترسی به دیتابیس ممکن نشد. دوباره تلاش کنید.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _retry,
                child: const Text('دوباره تلاش کنید'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _retry() async {
    await HesabDatabase.instance.close();
    runApp(const DatabaseBootstrap());
  }
}
