import 'package:material_ui/material_ui.dart';

import '../../../core/calendar/jalali_date.dart';
import '../../../core/theme/hesab_theme.dart';
import 'jalali_date_picker_dialog.dart';

Future<DateTimeRange?> showJalaliDateRangeDialog(
  BuildContext context, {
  required DateTime initialStart,
  required DateTime initialEnd,
}) => showDialog<DateTimeRange>(
  context: context,
  builder: (_) =>
      JalaliDateRangeDialog(initialStart: initialStart, initialEnd: initialEnd),
);

class JalaliDateRangeDialog extends StatefulWidget {
  const JalaliDateRangeDialog({
    required this.initialStart,
    required this.initialEnd,
    super.key,
  });

  final DateTime initialStart;
  final DateTime initialEnd;

  @override
  State<JalaliDateRangeDialog> createState() => _JalaliDateRangeDialogState();
}

class _JalaliDateRangeDialogState extends State<JalaliDateRangeDialog> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  Future<void> _selectStart() async {
    final value = await showJalaliDatePicker(context, initialDate: _start);
    if (value != null && mounted) setState(() => _start = value);
  }

  Future<void> _selectEnd() async {
    final value = await showJalaliDatePicker(context, initialDate: _end);
    if (value != null && mounted) setState(() => _end = value);
  }

  void _confirm() {
    if (_end.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تاریخ پایان پیش از تاریخ آغاز شده نمی‌تواند باشد.'),
        ),
      );
      return;
    }
    Navigator.pop(context, DateTimeRange(start: _start, end: _end));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        scrollable: true,
        title: const Text('بازهٔ زمانی دلخواه'),
        content: SizedBox(
          width: width < 480 ? double.maxFinite : 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DateField(
                label: 'از تاریخ',
                value: JalaliDate.fromGregorian(_start).fullDate,
                onTap: _selectStart,
              ),
              const SizedBox(height: 14),
              _DateField(
                label: 'تا تاریخ',
                value: JalaliDate.fromGregorian(_end).fullDate,
                onTap: _selectEnd,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          FilledButton(onPressed: _confirm, child: const Text('تأیید')),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month_rounded),
        border: const OutlineInputBorder(),
        constraints: const BoxConstraints(minHeight: HesabTheme.controlHeight),
      ),
      child: Text(value, style: const TextStyle(fontSize: HesabTheme.fontBody)),
    ),
  );
}
