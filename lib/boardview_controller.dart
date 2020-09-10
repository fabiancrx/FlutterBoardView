import 'package:flutter/animation.dart';
import 'package:flutter/cupertino.dart';

import 'boardview.dart';

class BoardViewController {
  BoardViewController();

  BoardViewState state;

  Future<void> animateTo(int index, {int durationMs = 300, curve: Curves.ease}) async {
    if (state.boardViewController != null &&
        state.boardViewController.hasClients) {

      // Get current page
      int currentPage = state.boardViewController.page.toInt();
      state.allowFromPage = currentPage;
      state.allowToPage = index;

      await state.boardViewController.animateToPage(index,
          duration: Duration(milliseconds: durationMs), curve: curve);

      state.allowFromPage = null;
      state.allowToPage = null;
    }
  }

  Future<void> toggleMode() async {
    if (state.boardViewController != null &&
        state.boardViewController.hasClients) {
      state.toggleMode();
    }
  }
}
