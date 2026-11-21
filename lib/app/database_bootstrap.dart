import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/theme/hesab_theme.dart';
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
  int _databaseRevision = 0;

  @override
  void initState() {
    super.initState();
    _database = HesabDatabase.instance.database;
  }

  void _onDatabaseChanged() {
    setState(() {
      _databaseRevision++;
      _database = HesabDatabase.instance.database;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Database>(
      future: _database,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _DatabaseErrorApp();
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const _DatabaseLoadingApp();
        }
        return HesabApp(
          key: ValueKey(_databaseRevision),
          services: HesabServices(snapshot.data!),
          onDatabaseChanged: _onDatabaseChanged,
        );
      },
    );
  }
}

class _DatabaseLoadingApp extends StatelessWidget {
  const _DatabaseLoadingApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('fa', 'AF'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: HesabTheme.light,
    home: const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text('پایگاه معلوماتی آماده می‌شود…'),
          ],
        ),
      ),
    ),
  );
}

class _DatabaseErrorApp extends StatelessWidget {
  const _DatabaseErrorApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('fa', 'AF'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: HesabTheme.light,
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
                'پایگاه معلوماتی باز نشد.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'دسترسی به پایگاه معلوماتی ممکن نشد. دوباره تلاش کنید.',
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
