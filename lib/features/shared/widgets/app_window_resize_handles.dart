import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class AppWindowResizeHandles extends StatelessWidget {
  const AppWindowResizeHandles({super.key});

  static const _channel = MethodChannel('hesab/window');
  static const _edgeSize = 24.0;

  Future<void> _startResize(String edge) async {
    try {
      await _channel.invokeMethod<void>('startResizing', edge);
    } on PlatformException {
      // The resize handles are only active on the Windows runner.
    } on MissingPluginException {
      // Other Flutter targets keep their standard window behavior.
    }
  }

  Widget _handle(SystemMouseCursor cursor, String edge) => MouseRegion(
    cursor: cursor,
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _startResize(edge),
      child: const SizedBox.expand(),
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: _edgeSize,
        right: _edgeSize,
        top: 0,
        height: _edgeSize,
        child: _handle(SystemMouseCursors.resizeUpDown, 'top'),
      ),
      Positioned(
        left: _edgeSize,
        right: _edgeSize,
        bottom: 0,
        height: _edgeSize,
        child: _handle(SystemMouseCursors.resizeUpDown, 'bottom'),
      ),
      Positioned(
        left: 0,
        top: _edgeSize,
        bottom: _edgeSize,
        width: _edgeSize,
        child: _handle(SystemMouseCursors.resizeLeftRight, 'left'),
      ),
      Positioned(
        right: 0,
        top: _edgeSize,
        bottom: _edgeSize,
        width: _edgeSize,
        child: _handle(SystemMouseCursors.resizeLeftRight, 'right'),
      ),
      Positioned(
        left: 0,
        top: 0,
        width: _edgeSize,
        height: _edgeSize,
        child: _handle(SystemMouseCursors.resizeUpLeftDownRight, 'topLeft'),
      ),
      Positioned(
        right: 0,
        top: 0,
        width: _edgeSize,
        height: _edgeSize,
        child: _handle(SystemMouseCursors.resizeUpRightDownLeft, 'topRight'),
      ),
      Positioned(
        left: 0,
        bottom: 0,
        width: _edgeSize,
        height: _edgeSize,
        child: _handle(SystemMouseCursors.resizeUpRightDownLeft, 'bottomLeft'),
      ),
      Positioned(
        right: 0,
        bottom: 0,
        width: _edgeSize,
        height: _edgeSize,
        child: _handle(SystemMouseCursors.resizeUpLeftDownRight, 'bottomRight'),
      ),
    ],
  );
}
