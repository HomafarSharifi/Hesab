import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/hesab_services.dart';
import '../../../core/theme/hesab_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.services,
    required this.onDatabaseChanged,
    super.key,
  });

  final HesabServices services;
  final VoidCallback onDatabaseChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _version = '۱.۰.۰';
  bool _busy = false;

  Future<void> _backup() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'ذخیره نسخه پشتیبان',
      fileName: 'hesab_backup.sqlite3',
      type: FileType.custom,
      allowedExtensions: const ['sqlite3', 'db'],
      lockParentWindow: true,
    );
    if (path == null || !mounted) return;
    final target = path.toLowerCase().endsWith('.sqlite3') ||
            path.toLowerCase().endsWith('.db')
        ? path
        : '$path.sqlite3';
    await _run(() => widget.services.databaseMaintenance.createBackup(target));
  }

  Future<void> _restore() async {
    final confirmed = await _confirm(
      title: 'بازیابی نسخه پشتیبان؟',
      message:
          'تمام دیتا فعلی با دیتا فایل پشتیبان جایگزین می‌شود. پیش از ادامه، یک نسخه پشتیبان از دیتا فعلی بگیرید.',
      action: 'انتخاب فایل',
    );
    if (!confirmed || !mounted) return;
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'انتخاب فایل پشتیبان حساب',
      type: FileType.custom,
      allowedExtensions: const ['sqlite3', 'db'],
      lockParentWindow: true,
    );
    final path = result == null || result.files.isEmpty
        ? null
        : result.files.single.path;
    if (path == null) return;
    final success = await _run(
      () => widget.services.databaseMaintenance.restore(path),
      successMessage: 'دیتا با موفقیت بازیابی شد.',
    );
    if (success && mounted) widget.onDatabaseChanged();
  }

  Future<void> _clear() async {
    final confirmed = await _confirmClear();
    if (!confirmed || !mounted) return;
    final success = await _run(
      widget.services.databaseMaintenance.clear,
      successMessage: 'تمام دیتا پاک شد.',
    );
    if (success && mounted) widget.onDatabaseChanged();
  }

  Future<bool> _confirmClear() async {
    const challenge = 'پاک کردن';
    final controller = TextEditingController();
    try {
      return await showDialog<bool>(
            context: context,
            builder: (context) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('پاک کردن تمام دیتا؟'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'تمام اجناس، دسته‌بندی‌ها، کیف پول‌ها و معاملات این دستگاه پاک می‌شود. برای تأیید، عبارت زیر را بنویسید:',
                    ),
                    const SizedBox(height: 10),
                    const SelectableText(
                      challenge,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      textDirection: TextDirection.rtl,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: challenge,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('انصراف'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: controller.text.trim() == challenge
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: const Text('پاک کردن دیتا'),
                  ),
                ],
              ),
            ),
          ) ??
          false;
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    )
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<bool> _run(
    Future<void> Function() operation, {
    String successMessage = 'نسخه پشتیبان ذخیره شد.',
  }) async {
    setState(() => _busy = true);
    var success = false;
    String message;
    try {
      await operation();
      success = true;
      message = successMessage;
    } on Object {
      message = 'انجام عملیات ممکن نشد. فایل را بررسی کرده و دوباره تلاش کنید.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
    return success;
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 12 : 24),
      child: ListView(
        children: [
          const SizedBox(height: 6),
          Text(
            'مدیریت دیتابیس',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: HesabTheme.fontSection,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _SettingsAction(
                  icon: Icons.backup_outlined,
                  title: 'نسخه پشتیبان',
                  subtitle: 'ذخیره یک نسخه کامل از دیتابیس',
                  onTap: _busy ? null : _backup,
                ),
                const Divider(height: 1),
                _SettingsAction(
                  icon: Icons.restore_rounded,
                  title: 'بازیابی نسخه پشتیبان',
                  subtitle: 'جایگزینی دیتابیس با فایل بکآپ',
                  onTap: _busy ? null : _restore,
                ),
                const Divider(height: 1),
                _SettingsAction(
                  icon: Icons.delete_forever_outlined,
                  title: 'حذف دیتابیس',
                  subtitle: 'حذف تمام دیتا ذخیره‌شده در این دستگاه',
                  destructive: true,
                  onTap: _busy ? null : _clear,
                ),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'درباره برنامه',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: HesabTheme.fontSection,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text(
                'نسخه برنامه',
                style: TextStyle(fontSize: HesabTheme.fontSection),
              ),
              trailing: Text(
                _version,
                style: const TextStyle(fontSize: HesabTheme.fontBody),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontSize: HesabTheme.fontSection,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: HesabTheme.fontBody),
      ),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
