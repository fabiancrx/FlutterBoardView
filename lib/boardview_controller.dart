import 'package:flutter/animation.dart';
import 'package:flutter/cupertino.dart';

import 'boardview.dart';

class BoardViewController {
  BoardViewController();

  BoardViewState state;

  Future<void> animateTo(int index, {Duration duration, Curve curve}) async {
    double offset = index * state.widget.width;
    if (state.boardViewController != null &&
        state.boardViewController.hasClients) {
      await state.boardViewController
          .animateTo(offset, duration: duration, curve: curve);
    }
  }

  Future<void> toggleMode() async {
    if (state.boardViewController != null &&
        state.boardViewController.hasClients) {
      state.toggleMode();
    }
  }
}
