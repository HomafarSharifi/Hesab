/// Shared logical dimensions used by the desktop shell's responsive layout.
abstract final class ResponsiveDimensions {
  /// Switch the desktop sidebar to icon-only navigation below this width.
  static const double expandedNavigationBreakpoint = 1000;

  /// Minimum supported width for the native Windows window, in logical pixels.
  static const double minimumWindowWidth = 900;

  /// Minimum supported height for the native Windows window, in logical pixels.
  static const double minimumWindowHeight = 640;
}
