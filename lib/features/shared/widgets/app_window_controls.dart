import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class AppWindowControls extends StatefulWidget {
  const AppWindowControls({super.key});

  @override
  State<AppWindowControls> createState() => _AppWindowControlsState();
}

class _AppWindowControlsState extends State<AppWindowControls> {
  static const _channel = MethodChannel('hesab/window');
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'windowStateChanged' && call.arguments is bool) {
        if (mounted) setState(() => _maximized = call.arguments as bool);
      }
    });
    _refreshState();
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _refreshState() async {
    try {
      final maximized = await _channel.invokeMethod<bool>('isMaximized');
      if (mounted && maximized != null) setState(() => _maximized = maximized);
    } on PlatformException {
      // The controls are only active on the Windows runner.
    } on MissingPluginException {
      // Other Flutter targets keep their standard window behavior.
    }
  }

  Future<void> _invoke(String method) async {
    try {
      if (method == 'toggleMaximize') {
        final maximized = await _channel.invokeMethod<bool>(method);
        if (mounted && maximized != null) {
          setState(() => _maximized = maximized);
        }
      } else {
        await _channel.invokeMethod<void>(method);
      }
    } on PlatformException {
      // The controls are only active on the Windows runner.
    } on MissingPluginException {
      // Other Flutter targets keep their standard window behavior.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget control({
      required String label,
      required IconData icon,
      required String method,
      bool close = false,
    }) => Tooltip(
      message: label,
      waitDuration: const Duration(seconds: 1),
      child: IconButton(
        onPressed: () => _invoke(method),
        icon: Icon(icon, size: 17),
        visualDensity: VisualDensity.compact,
        style:
            IconButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
              backgroundColor: Colors.transparent,
              hoverColor: close
                  ? const Color(0xFFE81123)
                  : colors.surfaceContainerHigh,
              focusColor: colors.primary.withValues(alpha: 0.16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
              fixedSize: const Size(34, 34),
            ).copyWith(
              foregroundColor: close
                  ? WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.hovered)
                          ? Colors.white
                          : colors.onSurfaceVariant,
                    )
                  : null,
            ),
      ),
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          control(
            label: 'کوچک کردن',
            icon: Icons.remove_rounded,
            method: 'minimize',
          ),
          control(
            label: _maximized ? 'بازگردانی' : 'بزرگ‌سازی',
            icon: _maximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            method: 'toggleMaximize',
          ),
          control(
            label: 'بستن',
            icon: Icons.close_rounded,
            method: 'close',
            close: true,
          ),
        ],
      ),
    );
  }
}
