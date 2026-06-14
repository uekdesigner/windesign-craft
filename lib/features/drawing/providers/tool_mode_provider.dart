import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ToolMode {
  selection,
  verticalLine,
  horizontalLine,
  triangle,
  verticalDoubleLine,
  horizontalDoubleLine,
  triangleUp,
  triangleDown,
  triangleRight,
  triangleLeft,
  dotGrid,
  lineGrid,
  dashedLines,
  shortHorizontalLine,
  shortVerticalLine,
  slideRight,
  slideLeft,
  attachPanel,
}

final toolModeProvider = StateNotifierProvider<ToolModeNotifier, ToolMode>((
  ref,
) {
  return ToolModeNotifier();
});

class ToolModeNotifier extends StateNotifier<ToolMode> {
  ToolModeNotifier() : super(ToolMode.selection);

  void setMode(ToolMode mode) => state = mode;

  void reset() => state = ToolMode.selection;

  void toggle(ToolMode mode) {
    if (state == mode) {
      state = ToolMode.selection;
    } else {
      state = mode;
    }
  }
}
