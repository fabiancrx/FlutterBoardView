import 'package:flutter/animation.dart';
import 'package:flutter/cupertino.dart';

import 'boardview.dart';

class BoardViewController {
  BoardViewController();

  BoardViewState state;

  BoardViewMode get mode => state.boardViewMode;

  void animateTo(int index,
      {int durationMs = 300,
      curve: Curves.ease,
      allowAnimationInterception = false}) {
    if (state.boardViewController != null &&
        state.boardViewController.hasClients) {
      state.animateTo(false, index, Duration(milliseconds: durationMs), curve);
    }
  }

  Future<void> toggleMode() async {
    if (state.boardViewController != null &&
        state.boardViewController.hasClients) {
      state.toggleMode();
    }
  }
}
