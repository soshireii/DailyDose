import 'package:flutter/widgets.dart';

class Breakpoints {
  /// Switch from bottom navigation bar to a navigation rail.
  static const double wide = 720;

  /// Show an extended (labelled) navigation rail.
  static const double extraWide = 1100;
}

extension ResponsiveContext on BuildContext {
  bool get isWide => MediaQuery.sizeOf(this).width >= Breakpoints.wide;
}
