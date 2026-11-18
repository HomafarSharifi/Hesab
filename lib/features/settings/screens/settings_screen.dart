import 'package:material_ui/material_ui.dart';

import '../../../core/theme/hesab_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.isDarkMode,
    required this.onToggleTheme,
    super.key,
  });
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 12 : 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            Card(
              child: SwitchListTile(
                value: isDarkMode,
                onChanged: (_) => onToggleTheme(),
                title: const Text(
                  'حالت شب',
                  style: TextStyle(fontSize: HesabTheme.fontSection),
                ),
                subtitle: const Text(
                  'نمایش برنامه با رنگ‌های تیره',
                  style: TextStyle(fontSize: HesabTheme.fontBody),
                ),
                secondary: Icon(
                  isDarkMode
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.language_rounded),
                title: Text(
                  'زبان و تقویم',
                  style: TextStyle(fontSize: HesabTheme.fontSection),
                ),
                subtitle: Text(
                  'دری افغانستان • ماه‌های جلالی',
                  style: TextStyle(fontSize: HesabTheme.fontBody),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.storage_outlined),
                title: Text(
                  'نگهداری معلومات',
                  style: TextStyle(fontSize: HesabTheme.fontSection),
                ),
                subtitle: Text(
                  'معلومات برنامه به‌صورت محلی در این دستگاه ذخیره می‌شود.',
                  style: TextStyle(fontSize: HesabTheme.fontBody),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
