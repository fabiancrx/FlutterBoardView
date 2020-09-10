library boardview;

import 'dart:async';
import 'dart:core';

import 'package:boardview/board_item.dart';
import 'package:boardview/board_list.dart';
import 'package:boardview/boardview_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'boardview_controller.dart';
import 'boardview_page_controller.dart';

enum BoardViewMode {
  single,
  pages,
}

class BoardView extends StatefulWidget {
  /// [BoardView] will automatically re-order these for you. Use
  /// [onListsChanged] to detect when this happens. Note:
  /// All widgets should have a key that is globally unique across
  /// all lists.
  final List<List<Widget>> lists;

  final BoardViewController controller;

  /// Whether items (or lists) can be re-ordered
  final bool canDrag;

  /// Called whenever [BoardView] modifies [lists]
  final VoidCallback onListsChanged;

  /// See [DynamicPageScrollPhysics]
  final OnAttemptDrag onAttemptDrag;

  /// PageView initial page
  final int initialPage;

  BoardView(
      {Key key,
      @required this.controller,
      @required this.lists,
      @required this.canDrag,
      this.onAttemptDrag,
      this.initialPage = 0,
      this.onListsChanged})
      : assert(!canDrag || onAttemptDrag == null,
            "Cannot lock pages when item drag is enabled."),
        super(key: key);

  @override
  State<StatefulWidget> createState() => BoardViewState();
}

class BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  DynamicPageController boardViewController;
  BoardViewMode boardViewMode = BoardViewMode.single;
  Animation<double> modeAnimation;
  AnimationController modeAnimationController;

  // Keeps track of BoardList states so items can be inserted between lists
  List<BoardListState> listStates = List<BoardListState>();

  /// The widget the user is currently dragging
  Widget draggedItem;

  /// The list the user is currently dragging [draggedItem] within
  int draggedListIndex;

  /// The index of [draggedItem] within [draggedListIndex]
  int draggedItemIndex;

  /// The offset of the pointer from the top left of [draggedItem]
  Offset localDragOffset;

  /// When a [BoardItem] is picked up, this is the local x offset from the
  /// top left corner of the [BoardItem]. Used to draw the hovering [draggedItem].
  double draggedInitX = 0;

  /// When a [BoardItem] is picked up, this is the local y offset from the
  /// top left corner of the [BoardItem]. Used to draw the hovering [draggedItem].
  double draggedInitY = 0;
  PointerDownEvent pointer;

  /// The pointer's global location
  double dx;

  /// The pointer's global location
  double dy;

  /// The width at which to draw [draggedItem]
  double draggedItemWidth;

  /// The height at which to draw [draggedItem]
  double draggedItemHeight;

  /// When an user drags [draggedItem] between pages, this timer is used to
  /// pass for a second or so before automatically navigating to the next page
  Timer horizontalDragTimer;

  /// If true, the user must either wait until [horizontalDragTimer] unlocks
  /// horizontal drag automatically, or they must exit and re-enter the horizontal
  /// drag zone.
  bool horizontalDragLocked = true;

  /// An over-ride to a page lock so that the system can use "animateTo"
  /// to force got to a page.
  int allowToPage;

  /// If a user is allowed to intercept a page animation.
  bool allowPageAnimationInterception = true;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      widget.controller.state = this;
    }

    modeAnimationController = AnimationController(
        duration: const Duration(milliseconds: 150), vsync: this);

    modeAnimation = Tween<double>(begin: 1, end: 0.85).animate(
        new CurvedAnimation(
            parent: modeAnimationController, curve: Curves.linear))
      ..addListener(() {
        setState(() {
          if (modeAnimation != null) {
            boardViewController.updateViewportFraction(modeAnimation.value);
          }
        });
      });

    boardViewController =
        DynamicPageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    modeAnimationController.dispose();
    boardViewController.dispose();

    super.dispose();
  }

  /// Animates to the desired page, ignoring any pages locks.
  /// If [allowAnimationInterception] is `true`, a user may touch
  /// the screen during the animation to cancel the animation. Only
  /// make this true when animating between pages that are NOT locked.
  Future<void> animateTo(bool allowAnimationInterception, int pageIndex,
      Duration duration, Curve curve) async {
    setState(() {
      allowToPage = pageIndex;
      allowPageAnimationInterception = allowAnimationInterception;
    });

    await boardViewController.animateToPage(pageIndex,
        duration: duration, curve: curve);

    setState(() {
      allowToPage = null;
      allowPageAnimationInterception = true;
    });
  }

  /// Toggles between zoomed-in and zoomed-out modes
  void toggleMode() async {
    await boardViewController.animateToPage(0,
        duration: Duration(milliseconds: 400),
        curve: Curves.fastLinearToSlowEaseIn);

    allowPageAnimationInterception = true;

    if (boardViewMode == BoardViewMode.single) {
      await modeAnimationController.forward();
      setState(() {
        boardViewMode = BoardViewMode.pages;
      });
    } else {
      await modeAnimationController.reverse();
      setState(() {
        boardViewMode = BoardViewMode.single;
      });
    }
  }

  // Moves the dragged item one down in the list
  void _moveDown() {
    listStates[draggedListIndex].setState(() {
      var item = widget.lists[draggedListIndex][draggedItemIndex];
      widget.lists[draggedListIndex].removeAt(draggedItemIndex);
      var itemState = listStates[draggedListIndex].itemStates[draggedItemIndex];
      listStates[draggedListIndex].itemStates.removeAt(draggedItemIndex);
      widget.lists[draggedListIndex].insert(++draggedItemIndex, item);
      listStates[draggedListIndex]
          .itemStates
          .insert(draggedItemIndex, itemState);
    });

    if (widget.onListsChanged != null) widget.onListsChanged();
  }

  // Moves the dragged item up one in the list
  void _moveUp() {
    listStates[draggedListIndex].setState(() {
      var item = widget.lists[draggedListIndex][draggedItemIndex];
      widget.lists[draggedListIndex].removeAt(draggedItemIndex);
      var itemState = listStates[draggedListIndex].itemStates[draggedItemIndex];
      listStates[draggedListIndex].itemStates.removeAt(draggedItemIndex);
      widget.lists[draggedListIndex].insert(--draggedItemIndex, item);
      listStates[draggedListIndex]
          .itemStates
          .insert(draggedItemIndex, itemState);
    });

    if (widget.onListsChanged != null) widget.onListsChanged();
  }

  // Moves the dragged item right one in the list
  void _moveRight() {
    setState(() {
      var item = widget.lists[draggedListIndex][draggedItemIndex];
      var itemState = listStates[draggedListIndex].itemStates[draggedItemIndex];
      listStates[draggedListIndex].setState(() {
        widget.lists[draggedListIndex].removeAt(draggedItemIndex);
        listStates[draggedListIndex].itemStates.removeAt(draggedItemIndex);
      });
      draggedListIndex++;
      listStates[draggedListIndex].setState(() {
        double closestValue = 10000;
        draggedItemIndex = 0;
        for (int i = 0;
            i < listStates[draggedListIndex].itemStates.length;
            i++) {
          if (listStates[draggedListIndex].itemStates[i].context != null) {
            RenderBox box = listStates[draggedListIndex]
                .itemStates[i]
                .context
                .findRenderObject();
            Offset pos = box.localToGlobal(Offset.zero);
            var temp = (pos.dy - dy + (box.size.height / 2)).abs();
            if (temp < closestValue) {
              closestValue = temp;
              draggedItemIndex = i;
            }
          }
        }
        widget.lists[draggedListIndex].insert(draggedItemIndex, item);
        listStates[draggedListIndex]
            .itemStates
            .insert(draggedItemIndex, itemState);
      });
    });

    if (widget.onListsChanged != null) widget.onListsChanged();
  }

  // Moves the dragged item left one in the list
  void _moveLeft() {
    setState(() {
      var item = widget.lists[draggedListIndex][draggedItemIndex];
      var itemState = listStates[draggedListIndex].itemStates[draggedItemIndex];
      listStates[draggedListIndex].setState(() {
        widget.lists[draggedListIndex].removeAt(draggedItemIndex);
        listStates[draggedListIndex].itemStates.removeAt(draggedItemIndex);
      });
      draggedListIndex--;
      listStates[draggedListIndex].setState(() {
        double closestValue = 10000;
        draggedItemIndex = 0;
        for (int i = 0;
            i < listStates[draggedListIndex].itemStates.length;
            i++) {
          if (listStates[draggedListIndex].itemStates[i].context != null) {
            RenderBox box = listStates[draggedListIndex]
                .itemStates[i]
                .context
                .findRenderObject();
            Offset pos = box.localToGlobal(Offset.zero);
            var temp = (pos.dy - dy + (box.size.height / 2)).abs();
            if (temp < closestValue) {
              closestValue = temp;
              draggedItemIndex = i;
            }
          }
        }
        widget.lists[draggedListIndex].insert(draggedItemIndex, item);
        listStates[draggedListIndex]
            .itemStates
            .insert(draggedItemIndex, itemState);
      });
    });

    if (widget.onListsChanged != null) widget.onListsChanged();
  }

  // Moves the dragged list right one
  void _moveListRight() {
    setState(() {
      var list = widget.lists[draggedListIndex];
      var listState = listStates[draggedListIndex];
      widget.lists.removeAt(draggedListIndex);
      listStates.removeAt(draggedListIndex);
      draggedListIndex++;
      widget.lists.insert(draggedListIndex, list);
      listStates.insert(draggedListIndex, listState);
    });

    if (widget.onListsChanged != null) widget.onListsChanged();
  }

  // Moves the dragged list left one
  void _moveListLeft() {
    setState(() {
      var list = widget.lists[draggedListIndex];
      var listState = listStates[draggedListIndex];
      widget.lists.removeAt(draggedListIndex);
      listStates.removeAt(draggedListIndex);
      draggedListIndex--;
      widget.lists.insert(draggedListIndex, list);
      listStates.insert(draggedListIndex, listState);
    });

    if (widget.onListsChanged != null) widget.onListsChanged();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackWidgets = <Widget>[
      FractionallySizedBox(
        heightFactor: modeAnimation.value,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              _handleItemReorder(dx, dy);
            }

            return true;
          },
          child: PageView.builder(
            itemCount: widget.lists.length,
            scrollDirection: Axis.horizontal,
            controller: boardViewController,
            physics: allowPageAnimationInterception
                ? DynamicPageScrollPhysics(onAttemptDrag: (from, to) {
                    if (boardViewMode == BoardViewMode.pages) {
                      return true;
                    }

                    if (allowToPage != null) {
                      return (to < from && allowToPage < from) ||
                          (to > from && allowToPage > from);
                    }

                    if (widget.canDrag) {
                      return true;
                    } else {
                      return widget.onAttemptDrag(from, to);
                    }
                  })
                : NeverScrollableScrollPhysics(),
            pageSnapping: false,
            itemBuilder: (context, index) {
              var boardList = BoardList(
                key: ValueKey(widget.lists[index]),
                items: widget.lists[index],
                boardView: this,
                boardViewMode: boardViewMode,
                index: index,
                onPreListDrag: (Rect bounds) {
                  if (!widget.canDrag) return;

                  draggedInitX = bounds.left;
                  draggedInitY = bounds.top;
                  draggedItemWidth = bounds.width;
                  draggedItemHeight = bounds.height;
                },
                onListDrag: (BoardList boardList, int listIndex) {
                  if (!widget.canDrag) return;

                  setState(() {
                    draggedListIndex = listIndex;
                    draggedItemIndex = null;
                    draggedItem = boardList;
                  });

                  if (pointer != null) {
                    _handleDrag(pointer.position.dx, pointer.position.dy);
                  }
                },
                onPreItemDrag: (Rect bounds) {
                  if (!widget.canDrag) return;

                  draggedInitX = bounds.left;
                  draggedInitY = bounds.top;
                  draggedItemWidth = bounds.width;
                  draggedItemHeight = bounds.height;
                },
                onItemDrag: (BoardItem boardItem, int itemIndex) {
                  if (!widget.canDrag) return;

                  setState(() {
                    draggedItemIndex = itemIndex;
                    draggedListIndex = index;
                    draggedItem = boardItem;
                  });

                  if (pointer != null) {
                    _handleDrag(pointer.position.dx, pointer.position.dy);
                  }
                },
              );

              return draggedListIndex == index && draggedItemIndex == null
                  ? Opacity(opacity: 0, child: boardList)
                  : boardList;
            },
          ),
        ),
      )
    ];

    // In-hand dragging item
    if (dx != null &&
        dy != null &&
        draggedItemHeight != null &&
        draggedItemWidth != null &&
        draggedItem != null) {
      stackWidgets.add(Positioned(
        width: draggedItemWidth,
        height: draggedItemHeight,
        left: (dx - localDragOffset.dx) + draggedInitX,
        top: (dy - localDragOffset.dy) + draggedInitY,
        child: Opacity(opacity: .7, child: draggedItem),
      ));
    }

    return Container(
        child: Listener(
            onPointerMove: (opm) {
              _handleDrag(opm.position.dx, opm.position.dy);
            },
            onPointerDown: (opd) {
              RenderBox box = context.findRenderObject();
              localDragOffset = box.localToGlobal(opd.position);
              pointer = opd;

              _handleDrag(opd.position.dx, opd.position.dy);
            },
            onPointerUp: (opu) {
              setState(() {
                horizontalDragTimer?.cancel();
                draggedItem = null;
                draggedInitX = null;
                draggedInitY = null;
                dx = null;
                dy = null;
                draggedItemIndex = null;
                draggedListIndex = null;
                horizontalDragLocked = true;
                draggedItemWidth = null;
              });
            },
            child: new Stack(
              clipBehavior: Clip.none,
              children: stackWidgets,
            )));
  }

  /*
   * Dragging code
   */

  /// Handles a pointer drag event
  void _handleDrag(double dx, double dy) {
    if (draggedInitX == null ||
        draggedInitY == null ||
        draggedItemHeight == null ||
        draggedItemWidth == null) {
      return;
    }

    if (draggedItemIndex != null && draggedItem != null) {
      _handleItemScroll(dx, dy);
      _handleItemReorder(dx, dy);
    } else if (draggedListIndex != null) {
      _handleListDrag(dx, dy);
    }
    setState(() {
      this.dx = dx;
      this.dy = dy;
    });
  }

  /// Handles a list drag event (also moves the list once it crosses
  /// the boundaries to its left or right)
  void _handleListDrag(double dx, double dy) {
    if (draggedListIndex == null || draggedItemIndex != null) return;

    // Scroll left
    if (0 <= draggedListIndex - 1 &&
        dx < listStates[draggedListIndex - 1].right + 45) {
      if (boardViewController != null &&
          boardViewController.hasClients &&
          !boardViewController.position.isScrollingNotifier.value &&
          !horizontalDragLocked) {
        boardViewController.animateToPage(draggedListIndex - 1,
            duration: Duration(milliseconds: 400), curve: Curves.ease);
        _moveListLeft();
        if (draggedListIndex != 0) _startTimedHorizontalDragLock();
      }
    }
    // Scroll right
    else if (draggedListIndex + 1 < widget.lists.length &&
        dx > listStates[draggedListIndex + 1].left - 45) {
      if (boardViewController != null &&
          boardViewController.hasClients &&
          !boardViewController.position.isScrollingNotifier.value &&
          !horizontalDragLocked) {
        boardViewController.animateToPage(draggedListIndex + 1,
            duration: Duration(milliseconds: 400), curve: Curves.ease);
        _moveListRight();
        _startTimedHorizontalDragLock();
      }
    } else {
      horizontalDragLocked = false;
    }
  }

  /// Handles item scrolling - determines whether to scroll up/down in the
  /// list or right/left between lists
  void _handleItemScroll(double dx, double dy) {
    if (draggedItem == null || draggedItemIndex == null) return;

    /*
     * Handle vertical scrolling within a [BoardList].
     * If the hovering item is near the top or bottom of a list,
     * it should automatically scroll
     */
    bool isVerticallyScrolling = listStates[draggedListIndex]
        .boardListController
        .position
        .isScrollingNotifier
        .value;

    // Scroll up
    if (dy < listStates[draggedListIndex].top + 70) {
      if (listStates[draggedListIndex].boardListController != null &&
          listStates[draggedListIndex].boardListController.hasClients &&
          !isVerticallyScrolling) {
        int duration = ((listStates[draggedListIndex]
                    .boardListController
                    .position
                    .pixels) *
                4)
            .toInt();

        listStates[draggedListIndex].boardListController.animateTo(0,
            duration: new Duration(milliseconds: duration),
            curve: Curves.linear);
      }
    }
    // Scroll down
    else if (dy > listStates[draggedListIndex].bottom - 70) {
      if (listStates[draggedListIndex].boardListController != null &&
          listStates[draggedListIndex].boardListController.hasClients &&
          !isVerticallyScrolling) {
        int duration = ((listStates[draggedListIndex]
                        .boardListController
                        .position
                        .maxScrollExtent -
                    listStates[draggedListIndex]
                        .boardListController
                        .position
                        .pixels) *
                4)
            .toInt();

        listStates[draggedListIndex].boardListController.animateTo(
            listStates[draggedListIndex]
                .boardListController
                .position
                .maxScrollExtent,
            duration: new Duration(milliseconds: duration),
            curve: Curves.linear);
      }
    } else if (isVerticallyScrolling) {
      listStates[draggedListIndex].boardListController.position.hold(() {});
    }

    /*
     * Handle horizontal scrolling between pages
     * in a [BoardView]
     */
    // Scroll left
    if (0 <= draggedListIndex - 1 &&
        dx < listStates[draggedListIndex].left + 45) {
      if (boardViewController != null &&
          boardViewController.hasClients &&
          !boardViewController.position.isScrollingNotifier.value &&
          !horizontalDragLocked) {
        boardViewController.animateToPage(draggedListIndex - 1,
            duration: Duration(milliseconds: 400), curve: Curves.ease);
        _startTimedHorizontalDragLock();
      }
    }
    // Scroll right
    else if (draggedListIndex + 1 < widget.lists.length &&
        dx > listStates[draggedListIndex].right - 45) {
      if (boardViewController != null &&
          boardViewController.hasClients &&
          !boardViewController.position.isScrollingNotifier.value &&
          !horizontalDragLocked) {
        boardViewController.animateToPage(draggedListIndex + 1,
            duration: Duration(milliseconds: 400), curve: Curves.ease);
        _startTimedHorizontalDragLock();
      }
    } else {
      horizontalDragLocked = false;
    }
  }

  /// Starts a timed horizontal lock. When a user is dragged [draggedItem]
  /// left or right, after the page is changed, the user's pointer
  /// is still likely in the drag region. Instead of immediately going
  /// to the next page, give the user a second to cancel the page change if
  /// they want.
  void _startTimedHorizontalDragLock() {
    horizontalDragLocked = true;
    horizontalDragTimer?.cancel();
    horizontalDragTimer = new Timer(Duration(milliseconds: 1000), () {
      horizontalDragLocked = false;
      _handleItemScroll(dx, dy);
      _handleListDrag(dx, dy);
    });
  }

  /// Checks if an item should be reordered within a list / between lists
  /// based off its location
  void _handleItemReorder(double dx, double dy) {
    if (draggedItem == null ||
        draggedListIndex == null ||
        draggedItemIndex == null) return;

    /*
     * Check if the item should be repositioned
     */

    // Move up
    // Compute if the pointer dy location is higher than the vertical
    // midpoint of the immediately above adjacent item
    if (draggedItemIndex - 1 >= 0 &&
        dy <
            listStates[draggedListIndex]
                .itemStates[draggedItemIndex - 1]
                .verticalMidpoint) {
      _moveUp();
    }
    // Move down
    // Compute if the pointer dy location is lower than the vertical
    // midpoint of the immediately below adjacent item
    else if (draggedItemIndex + 1 < widget.lists[draggedListIndex].length &&
        dy >
            listStates[draggedListIndex]
                .itemStates[draggedItemIndex + 1]
                .verticalMidpoint) {
      _moveDown();
    }

    // Move to the left list
    if (draggedListIndex - 1 >= 0 && dx < listStates[draggedListIndex].left) {
      _moveLeft();
    }
    // Move to the right list
    else if (draggedListIndex + 1 < widget.lists.length &&
        dx > listStates[draggedListIndex].right) {
      _moveRight();
    }
  }
}
