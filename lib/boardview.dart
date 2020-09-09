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

class BoardView extends StatefulWidget {
  final List<List<Widget>> lists;
  Widget middleWidget;
  double bottomPadding;
  BoardViewController boardViewController;

  Function(bool) itemInMiddleWidget;
  OnDropBottomWidget onDropItemInMiddleWidget;

  BoardView(
      {Key key,
      this.itemInMiddleWidget,
      this.boardViewController,
      this.onDropItemInMiddleWidget,
      this.lists,
      this.middleWidget,
      this.bottomPadding})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return BoardViewState(lists);
  }
}

typedef void OnDropBottomWidget(int listIndex, int itemIndex, double percentX);
typedef void OnDropItem(int listIndex, int itemIndex);
typedef void OnDropList(int listIndex);

enum BoardViewMode {
  single,
  pages,
}

class BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Keeps track of all present widgets
  final List<List<Widget>> pages;

  // Keeps track of BoardList states so items can be inserted between lists
  List<BoardListState> listStates = List<BoardListState>();

  Widget draggedItem;
  int draggedItemIndex;
  int draggedListIndex;

  Offset offset;

  /// When a [BoardItem] is picked up, this is the local x offset from the
  /// top left corner of the [BoardItem]
  double initialX = 0;

  /// When a [BoardItem] is picked up, this is the local y offset from the
  /// top left corner of the [BoardItem]
  double initialY = 0;

  /// The pointer's location relative to [BoardView] (local location)
  double dx;
  double dy;

  double width;

  double height;
  int startListIndex;
  int startItemIndex;

  bool canDrag = true;

  Timer recurringHorizontalTimer;
  bool horizontalLocked = true;

  BoardViewMode boardViewMode = BoardViewMode.single;
  Animation<double> modeAnimation;
  AnimationController modeAnimationController;

  DynamicPageController boardViewController = DynamicPageController();

  OnDropItem onDropItem;
  OnDropList onDropList;

  bool _isInWidget = false;

  PointerDownEvent pointer;

  BoardViewState(this.pages);

  @override
  void initState() {
    super.initState();
    if (widget.boardViewController != null) {
      widget.boardViewController.state = this;
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
  }

  @override
  void dispose() {
    modeAnimationController.dispose();

    super.dispose();
  }

  void toggleMode() async {
    await boardViewController.animateToPage(0,
        duration: Duration(milliseconds: 400),
        curve: Curves.fastLinearToSlowEaseIn);

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
  void moveDown() {
    listStates[draggedListIndex].setState(() {
      var item = pages[draggedListIndex][draggedItemIndex];
      pages[draggedListIndex].removeAt(draggedItemIndex);
      var itemState = listStates[draggedListIndex].itemStates[draggedItemIndex];
      listStates[draggedListIndex].itemStates.removeAt(draggedItemIndex);
      pages[draggedListIndex].insert(++draggedItemIndex, item);
      listStates[draggedListIndex]
          .itemStates
          .insert(draggedItemIndex, itemState);
    });
  }

  // Moves the dragged item up one in the list
  void moveUp() {
    listStates[draggedListIndex].setState(() {
      var item = pages[draggedListIndex][draggedItemIndex];
      pages[draggedListIndex].removeAt(draggedItemIndex);
      var itemState = listStates[draggedListIndex].itemStates[draggedItemIndex];
      listStates[draggedListIndex].itemStates.removeAt(draggedItemIndex);
      pages[draggedListIndex].insert(--draggedItemIndex, item);
      listStates[draggedListIndex]
          .itemStates
          .insert(draggedItemIndex, itemState);
    });
  }

  void moveListRight() {
    setState(() {
      var list = pages[draggedListIndex];
      var listState = listStates[draggedListIndex];
      pages.removeAt(draggedListIndex);
      listStates.removeAt(draggedListIndex);
      draggedListIndex++;
      pages.insert(draggedListIndex, list);
      listStates.insert(draggedListIndex, listState);
    });
  }

  void moveRight() {
    setState(() {
      var item = pages[draggedListIndex][draggedItemIndex];
      var itemState = listStates[draggedListIndex].itemStates[draggedItemIndex];
      listStates[draggedListIndex].setState(() {
        pages[draggedListIndex].removeAt(draggedItemIndex);
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
        pages[draggedListIndex].insert(draggedItemIndex, item);
        listStates[draggedListIndex]
            .itemStates
            .insert(draggedItemIndex, itemState);
      });
    });
  }

  void moveListLeft() {
    setState(() {
      var list = pages[draggedListIndex];
      var listState = listStates[draggedListIndex];
      pages.removeAt(draggedListIndex);
      listStates.removeAt(draggedListIndex);
      draggedListIndex--;
      pages.insert(draggedListIndex, list);
      listStates.insert(draggedListIndex, listState);
    });
  }

  void moveLeft() {
    setState(() {
      var item = pages[draggedListIndex][draggedItemIndex];
      var itemState = listStates[draggedListIndex].itemStates[draggedItemIndex];
      listStates[draggedListIndex].setState(() {
        pages[draggedListIndex].removeAt(draggedItemIndex);
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
        pages[draggedListIndex].insert(draggedItemIndex, item);
        listStates[draggedListIndex]
            .itemStates
            .insert(draggedItemIndex, itemState);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    List<Widget> stackWidgets = <Widget>[
      FractionallySizedBox(
        heightFactor: modeAnimation.value,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              handleItemReorder(dx, dy);
            }

            return true;
          },
          child: PageView.builder(
            itemCount: pages.length,
            scrollDirection: Axis.horizontal,
            controller: boardViewController,
            physics: DynamicPageScrollPhysics(),
            pageSnapping: false,
            itemBuilder: (context, index) {
              var boardList = BoardList(
                items: pages[index],
                boardView: this,
                boardViewMode: boardViewMode,
                index: index,
                onPreListDrag: (Rect bounds) {
                  initialX = bounds.left;
                  initialY = bounds.top;
                  width = bounds.width;
                  height = bounds.height;
                },
                onListDrag: (BoardList boardList, int listIndex) {
                  setState(() {
                    startListIndex = listIndex;
                    draggedListIndex = listIndex;
                    draggedItemIndex = null;
                    draggedItem = boardList;
                  });

                  if (pointer != null) {
                    handleDrag(pointer.position.dx, pointer.position.dy);
                  }
                },
                onPreItemDrag: (Rect bounds) {
                  initialX = bounds.left;
                  initialY = bounds.top;
                  width = bounds.width;
                  height = bounds.height;
                },
                onItemDrag: (BoardItem boardItem, int itemIndex) {
                  setState(() {
                    draggedItemIndex = itemIndex;
                    draggedListIndex = index;
                    startListIndex = index;
                    startItemIndex = itemIndex;
                    draggedItem = boardItem;
                  });

                  if (pointer != null) {
                    handleDrag(pointer.position.dx, pointer.position.dy);
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
    if (dx != null && dy != null && height != null && width != null) {
      stackWidgets.add(Positioned(
        width: width,
        height: height,
        child: Opacity(opacity: .7, child: draggedItem),
        left: (dx - offset.dx) + initialX,
        top: (dy - offset.dy) + initialY,
      ));
    }

    return Container(
        child: Listener(
            onPointerMove: (opm) {
              if (draggedItem != null) {
                handleDrag(opm.position.dx, opm.position.dy);
              }
            },
            onPointerDown: (opd) {
              RenderBox box = context.findRenderObject();
              offset = box.localToGlobal(opd.position);
              pointer = opd;

              handleDrag(opd.position.dx, opd.position.dy);
            },
            onPointerUp: (opu) {
              setState(() {
                recurringHorizontalTimer?.cancel();

                if (onDropItem != null) {
                  listStates.forEach((e) => {
                        if (e.boardListController != null &&
                            e.boardListController.hasClients)
                          {e.boardListController.position.hold(() {})}
                      });

                  int tempDraggedItemIndex = draggedItemIndex;
                  int tempDraggedListIndex = draggedListIndex;
                  int startDraggedItemIndex = startItemIndex;
                  int startDraggedListIndex = startListIndex;

                  if (_isInWidget && widget.onDropItemInMiddleWidget != null) {
                    onDropItem(startDraggedListIndex, startDraggedItemIndex);
                    widget.onDropItemInMiddleWidget(
                        startDraggedListIndex,
                        startDraggedItemIndex,
                        opu.position.dx / MediaQuery.of(context).size.width);
                  } else {
                    onDropItem(tempDraggedListIndex, tempDraggedItemIndex);
                  }
                }
                if (onDropList != null) {
                  int tempDraggedListIndex = draggedListIndex;
                  if (_isInWidget && widget.onDropItemInMiddleWidget != null) {
                    onDropList(tempDraggedListIndex);
                    widget.onDropItemInMiddleWidget(tempDraggedListIndex, null,
                        opu.position.dx / MediaQuery.of(context).size.width);
                  } else {
                    onDropList(tempDraggedListIndex);
                  }
                }

                draggedItem = null;
                initialX = null;
                initialY = null;
                dx = null;
                dy = null;
                draggedItemIndex = null;
                draggedListIndex = null;
                onDropItem = null;
                onDropList = null;
                startListIndex = null;
                startItemIndex = null;
                horizontalLocked = true;
                width = null;
              });
            },
            child: new Stack(
              clipBehavior: Clip.none,
              children: stackWidgets,
            )));
  }

  void handleDrag(double dx, double dy) {
    if (initialX == null ||
        initialY == null ||
        height == null ||
        width == null ||
        !canDrag) {
      return;
    }

    if (draggedItemIndex != null && draggedItem != null) {
      handleItemScroll(dx, dy);
      handleItemReorder(dx, dy);
    } else if (draggedListIndex != null) {
      handleListDrag(dx, dy);
    }
    setState(() {
      this.dx = dx;
      this.dy = dy;
    });
  }

  void handleListDrag(double dx, double dy) {
    if (draggedListIndex == null || draggedItemIndex != null) return;
    // TODO why offset here but not for items?

    // Scroll left
    if (0 <= draggedListIndex - 1 &&
        dx < listStates[draggedListIndex - 1].right + 45) {
      if (boardViewController != null &&
          boardViewController.hasClients &&
          !boardViewController.position.isScrollingNotifier.value &&
          !horizontalLocked) {
        boardViewController.animateToPage(draggedListIndex - 1,
            duration: Duration(milliseconds: 400), curve: Curves.ease);
        moveListLeft();
        if (draggedListIndex != 0) startTimedHorizontalLock();
      }
    }
    // Scroll right
    else if (draggedListIndex + 1 < pages.length &&
        dx > listStates[draggedListIndex + 1].left - 45) {
      if (boardViewController != null &&
          boardViewController.hasClients &&
          !boardViewController.position.isScrollingNotifier.value &&
          !horizontalLocked) {
        boardViewController.animateToPage(draggedListIndex + 1,
            duration: Duration(milliseconds: 400), curve: Curves.ease);
        moveListRight();
        startTimedHorizontalLock();
      }
    } else {
      horizontalLocked = false;
    }
  }

  void handleItemScroll(double dx, double dy) {
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
          !horizontalLocked) {
        boardViewController.animateToPage(draggedListIndex - 1,
            duration: Duration(milliseconds: 400), curve: Curves.ease);
        startTimedHorizontalLock();
      }
    }
    // Scroll right
    else if (draggedListIndex + 1 < pages.length &&
        dx > listStates[draggedListIndex].right - 45) {
      if (boardViewController != null &&
          boardViewController.hasClients &&
          !boardViewController.position.isScrollingNotifier.value &&
          !horizontalLocked) {
        boardViewController.animateToPage(draggedListIndex + 1,
            duration: Duration(milliseconds: 400), curve: Curves.ease);
        startTimedHorizontalLock();
      }
    } else {
      horizontalLocked = false;
    }
  }

  void startTimedHorizontalLock() {
    horizontalLocked = true;
    recurringHorizontalTimer?.cancel();
    recurringHorizontalTimer = new Timer(Duration(milliseconds: 1000), () {
      horizontalLocked = false;
      handleItemScroll(dx, dy);
      handleListDrag(dx, dy);
    });
  }

  void handleItemReorder(double dx, double dy) {
    if (draggedItem == null ||
        draggedListIndex == null ||
        draggedItemIndex == null) return;

    /*
     * Check if the item should be repositioned
     */

    // TODO extract bounds as properties

    // Move up
    // Compute if the pointer dy location is higher than the vertical
    // midpoint of the immediately above adjacent item
    if (draggedItemIndex - 1 >= 0 &&
        dy <
            listStates[draggedListIndex]
                    .itemStates[draggedItemIndex - 1]
                    .renderBox
                    .localToGlobal(Offset.zero)
                    .dy +
                listStates[draggedListIndex]
                        .itemStates[draggedItemIndex - 1]
                        .renderBox
                        .size
                        .height /
                    2) {
      moveUp();
    }
    // Move down
    // Compute if the pointer dy location is lower than the vertical
    // midpoint of the immediately below adjacent item
    else if (draggedItemIndex + 1 < pages[draggedListIndex].length &&
        dy >
            listStates[draggedListIndex]
                    .itemStates[draggedItemIndex + 1]
                    .renderBox
                    .localToGlobal(Offset.zero)
                    .dy +
                listStates[draggedListIndex]
                        .itemStates[draggedItemIndex + 1]
                        .renderBox
                        .size
                        .height /
                    2) {
      moveDown();
    }

    // Move to the left list
    if (draggedListIndex - 1 >= 0 && dx < listStates[draggedListIndex].left) {
      moveLeft();
    }
    // Move to the right list
    else if (draggedListIndex + 1 < pages.length &&
        dx > listStates[draggedListIndex].right) {
      moveRight();
    }
  }

  void onDragStarted() {}

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}
