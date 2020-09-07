library boardview;

import 'dart:core';

import 'package:boardview/board_list.dart';
import 'package:boardview/boardview_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'boardview_controller.dart';
import 'boardview_page_controller.dart';

class BoardView extends StatefulWidget {
  final List<BoardList> lists;
  final double width;
  Widget middleWidget;
  double bottomPadding;
  bool isSelecting;
  BoardViewController boardViewController;

  Function(bool) itemInMiddleWidget;
  OnDropBottomWidget onDropItemInMiddleWidget;

  BoardView(
      {Key key,
      this.itemInMiddleWidget,
      this.boardViewController,
      this.onDropItemInMiddleWidget,
      this.isSelecting = false,
      this.lists,
      this.width = 280,
      this.middleWidget,
      this.bottomPadding})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return BoardViewState();
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
    with SingleTickerProviderStateMixin {
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

  double rightListX;
  double leftListX;
  double topListY;
  double bottomListY;
  double topItemY;
  double bottomItemY;
  double height;
  int startListIndex;
  int startItemIndex;

  bool canDrag = true;

  BoardViewMode boardViewMode = BoardViewMode.single;
  Animation<double> modeAnimation;
  AnimationController modeAnimationController;

  DynamicPageController boardViewController = DynamicPageController();

  List<BoardListState> listStates = List<BoardListState>();

  OnDropItem onDropItem;
  OnDropList onDropList;

  bool _isInWidget = false;

  PointerDownEvent pointer;

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
      topItemY +=
          listStates[draggedListIndex].itemStates[draggedItemIndex + 1].height;
      bottomItemY +=
          listStates[draggedListIndex].itemStates[draggedItemIndex + 1].height;
      var item = widget.lists[draggedListIndex].items[draggedItemIndex];
      widget.lists[draggedListIndex].items.removeAt(draggedItemIndex);
      var itemState = listStates[draggedListIndex].itemStates[draggedItemIndex];
      listStates[draggedListIndex].itemStates.removeAt(draggedItemIndex);
      widget.lists[draggedListIndex].items.insert(++draggedItemIndex, item);
      listStates[draggedListIndex]
          .itemStates
          .insert(draggedItemIndex, itemState);
    });
  }

  // Moves the dragged item up one in the list
  void moveUp() {
    listStates[draggedListIndex].setState(() {
      topItemY -=
          listStates[draggedListIndex].itemStates[draggedItemIndex - 1].height;
      bottomItemY -=
          listStates[draggedListIndex].itemStates[draggedItemIndex - 1].height;
      var item = widget.lists[draggedListIndex].items[draggedItemIndex];
      widget.lists[draggedListIndex].items.removeAt(draggedItemIndex);
      var itemState = listStates[draggedListIndex].itemStates[draggedItemIndex];
      listStates[draggedListIndex].itemStates.removeAt(draggedItemIndex);
      widget.lists[draggedListIndex].items.insert(--draggedItemIndex, item);
      listStates[draggedListIndex]
          .itemStates
          .insert(draggedItemIndex, itemState);
    });
  }

  void moveListRight() {
    setState(() {
      var list = widget.lists[draggedListIndex];
      var listState = listStates[draggedListIndex];
      widget.lists.removeAt(draggedListIndex);
      listStates.removeAt(draggedListIndex);
      draggedListIndex++;
      widget.lists.insert(draggedListIndex, list);
      listStates.insert(draggedListIndex, listState);
      canDrag = false;
      if (boardViewController != null && boardViewController.hasClients) {
        int tempListIndex = draggedListIndex;
        boardViewController
            .animateTo(draggedListIndex * widget.width,
                duration: new Duration(milliseconds: 400), curve: Curves.ease)
            .whenComplete(() {
          RenderBox object =
              listStates[tempListIndex].context.findRenderObject();
          Offset pos = object.localToGlobal(Offset.zero);
          leftListX = pos.dx;
          rightListX = pos.dx + object.size.width;
          Future.delayed(new Duration(milliseconds: 300), () {
            canDrag = true;
          });
        });
      }
    });
  }

  void moveRight() {
    setState(() {
      var item = widget.lists[draggedListIndex].items[draggedItemIndex];
      var itemState = listStates[draggedListIndex].itemStates[draggedItemIndex];
      listStates[draggedListIndex].setState(() {
        widget.lists[draggedListIndex].items.removeAt(draggedItemIndex);
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
        widget.lists[draggedListIndex].items.insert(draggedItemIndex, item);
        listStates[draggedListIndex]
            .itemStates
            .insert(draggedItemIndex, itemState);
        canDrag = false;
      });
      if (boardViewController != null && boardViewController.hasClients) {
        int tempListIndex = draggedListIndex;
        int tempItemIndex = draggedItemIndex;
        boardViewController
            .animateTo(draggedListIndex * widget.width,
                duration: new Duration(milliseconds: 400), curve: Curves.ease)
            .whenComplete(() {
          RenderBox object =
              listStates[tempListIndex].context.findRenderObject();
          Offset pos = object.localToGlobal(Offset.zero);
          leftListX = pos.dx;
          rightListX = pos.dx + object.size.width;
          RenderBox box = listStates[tempListIndex]
              .itemStates[tempItemIndex]
              .context
              .findRenderObject();
          Offset itemPos = box.localToGlobal(Offset.zero);
          topItemY = itemPos.dy;
          bottomItemY = itemPos.dy + box.size.height;
          Future.delayed(new Duration(milliseconds: 300), () {
            canDrag = true;
          });
        });
      }
    });
  }

  void moveListLeft() {
    setState(() {
      var list = widget.lists[draggedListIndex];
      var listState = listStates[draggedListIndex];
      widget.lists.removeAt(draggedListIndex);
      listStates.removeAt(draggedListIndex);
      draggedListIndex--;
      widget.lists.insert(draggedListIndex, list);
      listStates.insert(draggedListIndex, listState);
      canDrag = false;
      if (boardViewController != null && boardViewController.hasClients) {
        int tempListIndex = draggedListIndex;
        boardViewController
            .animateTo(draggedListIndex * widget.width,
                duration: new Duration(milliseconds: 400), curve: Curves.ease)
            .whenComplete(() {
          RenderBox object =
              listStates[tempListIndex].context.findRenderObject();
          Offset pos = object.localToGlobal(Offset.zero);
          leftListX = pos.dx;
          rightListX = pos.dx + object.size.width;
          Future.delayed(new Duration(milliseconds: 300), () {
            canDrag = true;
          });
        });
      }
    });
  }

  void moveLeft() {
    setState(() {
      var item = widget.lists[draggedListIndex].items[draggedItemIndex];
      var itemState = listStates[draggedListIndex].itemStates[draggedItemIndex];
      listStates[draggedListIndex].setState(() {
        widget.lists[draggedListIndex].items.removeAt(draggedItemIndex);
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
        widget.lists[draggedListIndex].items.insert(draggedItemIndex, item);
        listStates[draggedListIndex]
            .itemStates
            .insert(draggedItemIndex, itemState);
        canDrag = false;
      });
      if (boardViewController != null && boardViewController.hasClients) {
        int tempListIndex = draggedListIndex;
        int tempItemIndex = draggedItemIndex;
        boardViewController
            .animateTo(draggedListIndex * widget.width,
                duration: new Duration(milliseconds: 400), curve: Curves.ease)
            .whenComplete(() {
          RenderBox object =
              listStates[tempListIndex].context.findRenderObject();
          Offset pos = object.localToGlobal(Offset.zero);
          leftListX = pos.dx;
          rightListX = pos.dx + object.size.width;
          RenderBox box = listStates[tempListIndex]
              .itemStates[tempItemIndex]
              .context
              .findRenderObject();
          Offset itemPos = box.localToGlobal(Offset.zero);
          topItemY = itemPos.dy;
          bottomItemY = itemPos.dy + box.size.height;
          Future.delayed(new Duration(milliseconds: 300), () {
            canDrag = true;
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackWidgets = <Widget>[
      FractionallySizedBox(
        heightFactor: modeAnimation.value,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if(notification is ScrollUpdateNotification) {
                handleItemReorder(dx, dy);
            }

            return false;
          },
          child: PageView.builder(
            itemCount: widget.lists.length,
            scrollDirection: Axis.horizontal,
            controller: boardViewController,
            physics: DynamicPageScrollPhysics(),
            pageSnapping: false,
            itemBuilder: (BuildContext context, int index) {
              if (widget.lists[index].boardView == null) {
                widget.lists[index] = BoardList(
                  items: widget.lists[index].items,
                  headerBackgroundColor:
                      widget.lists[index].headerBackgroundColor,
                  backgroundColor: widget.lists[index].backgroundColor,
                  footer: widget.lists[index].footer,
                  header: widget.lists[index].header,
                  boardView: this,
                  draggable: widget.lists[index].draggable,
                  onDropList: widget.lists[index].onDropList,
                  onTapList: widget.lists[index].onTapList,
                  onStartDragList: widget.lists[index].onStartDragList,
                  boardViewMode: boardViewMode,
                );
              }
              if (widget.lists[index].index != index ||
                  widget.lists[index].boardViewMode != boardViewMode) {
                widget.lists[index] = BoardList(
                  items: widget.lists[index].items,
                  headerBackgroundColor:
                      widget.lists[index].headerBackgroundColor,
                  backgroundColor: widget.lists[index].backgroundColor,
                  footer: widget.lists[index].footer,
                  header: widget.lists[index].header,
                  boardView: this,
                  draggable: widget.lists[index].draggable,
                  index: index,
                  onDropList: widget.lists[index].onDropList,
                  onTapList: widget.lists[index].onTapList,
                  onStartDragList: widget.lists[index].onStartDragList,
                  boardViewMode: boardViewMode,
                );
              }

              var temp = Container(
                  width: widget.width,
                  padding:
                      EdgeInsets.fromLTRB(0, 0, 0, widget.bottomPadding ?? 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[Expanded(child: widget.lists[index])],
                  ));
              // Draws an empty spot that the user is currently hovering
              // a dragged item over
              if (draggedListIndex == index && draggedItemIndex == null) {
                return Opacity(
                  opacity: 0.0,
                  child: temp,
                );
              } else {
                return temp;
              }
            },
          ),
        ),
      )
    ];
//    bool isInBottomWidget = false;
//    if (dy != null) {
//      if (MediaQuery.of(context).size.height - dy < 80) {
//        isInBottomWidget = true;
//      }
//    }
//    if (widget.itemInMiddleWidget != null && _isInWidget != isInBottomWidget) {
//      widget.itemInMiddleWidget(isInBottomWidget);
//      _isInWidget = isInBottomWidget;
//    }

    if (dx != null && dy != null && height != null && widget.width != null) {
      if (widget.middleWidget != null) {
        stackWidgets.add(widget.middleWidget);
      }
      stackWidgets.add(Positioned(
        width: widget.width,
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
                if (onDropItem != null) {
                  listStates.forEach((e) => {
                    if(e.boardListController != null && e.boardListController.hasClients) {
                      e.boardListController.position.hold(() { })
                    }
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
                leftListX = null;
                rightListX = null;
                topListY = null;
                bottomListY = null;
                topItemY = null;
                bottomItemY = null;
                startListIndex = null;
                startItemIndex = null;
              });
            },
            child: new Stack(
              children: stackWidgets,
            )));
  }

  void handleDrag(double dx, double dy) {
    if (initialX == null ||
        initialY == null ||
        dx == null ||
        dy == null ||
        height == null ||
        widget.width == null ||
        !canDrag) {
      return;
    }

    if (draggedItemIndex != null &&
        draggedItem != null &&
        topItemY != null &&
        bottomItemY != null) {
      handleItemScroll(dx, dy);
      handleItemReorder(dx, dy);
    } else {
      handleListDrag(dx, dy);
    }
    setState(() {
      this.dx = dx;
      this.dy = dy;
    });
  }

  void handleListDrag(double dx, double dy) {
    //dragging list
    if (0 <= draggedListIndex - 1 && dx < leftListX + 45) {
      //scroll left
      if (boardViewController != null && boardViewController.hasClients) {
        boardViewController.animateTo(boardViewController.position.pixels - 5,
            duration: new Duration(milliseconds: 10), curve: Curves.ease);
        leftListX += 5;
        rightListX += 5;
      }
    }

    if (widget.lists.length > draggedListIndex + 1 && dx > rightListX - 45) {
      //scroll right
      if (boardViewController != null && boardViewController.hasClients) {
        boardViewController.animateTo(boardViewController.position.pixels + 5,
            duration: new Duration(milliseconds: 10), curve: Curves.ease);
        leftListX -= 5;
        rightListX -= 5;
      }
    }
    if (widget.lists.length > draggedListIndex + 1 && dx > rightListX) {
      //move right
      moveListRight();
    }
    if (0 <= draggedListIndex - 1 && dx < leftListX) {
      //move left
      moveListLeft();
    }
  }

  void handleItemScroll(double dx, double dy) {
    /*
     * Handle vertical scrolling within a [BoardList].
     * If the hovering item is near the top or bottom of a list,
     * it should automatically scroll
     */
    bool isScrolling = listStates[draggedListIndex]
        .boardListController
        .position
        .isScrollingNotifier
        .value;

    // Scroll up
    if (dy < topListY + 70 && dx > leftListX && dx < rightListX) {
      if (listStates[draggedListIndex].boardListController != null &&
          listStates[draggedListIndex].boardListController.hasClients && !isScrolling) {
        int duration = ((listStates[draggedListIndex]
                    .boardListController
                    .position
                    .pixels) *
                4)
            .toInt();

        listStates[draggedListIndex].boardListController.animateTo(0,
            duration: new Duration(milliseconds: duration), curve: Curves.linear);
      }
    }
    // Scroll down
    else if (dy > bottomListY - 70 && dx > leftListX && dx < rightListX) {
      if (listStates[draggedListIndex].boardListController != null &&
          listStates[draggedListIndex].boardListController.hasClients && !isScrolling) {
        int duration = ((listStates[draggedListIndex]
                        .boardListController
                        .position
                        .maxScrollExtent -
                    listStates[draggedListIndex]
                        .boardListController
                        .position
                        .pixels)  *
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
    } else if (isScrolling) {
      listStates[draggedListIndex].boardListController.position.hold((){});
    }

//    if (0 <= draggedListIndex - 1 && dx < leftListX + 45) {
//      //scroll left
//      if (boardViewController != null && boardViewController.hasClients) {
//        boardViewController.animateTo(boardViewController.position.pixels - 5,
//            duration: new Duration(milliseconds: 10), curve: Curves.ease);
//        RenderBox object =
//            listStates[draggedListIndex].context.findRenderObject();
//        Offset pos = object.localToGlobal(Offset.zero);
//        leftListX = pos.dx;
//        rightListX = pos.dx + object.size.width;
//      }
//    }
//    if (widget.lists.length > draggedListIndex + 1 && dx > rightListX - 45) {
//      //scroll right
//      if (boardViewController != null && boardViewController.hasClients) {
//        boardViewController.animateTo(boardViewController.position.pixels + 5,
//            duration: new Duration(milliseconds: 10), curve: Curves.ease);
//        RenderBox object =
//            listStates[draggedListIndex].context.findRenderObject();
//        Offset pos = object.localToGlobal(Offset.zero);
//        leftListX = pos.dx;
//        rightListX = pos.dx + object.size.width;
//      }
//    }
//    if (0 <= draggedListIndex - 1 && dx < leftListX) {
//      //move left
//      moveLeft();
//    }
  }

  void handleItemReorder(double dx, double dy) {
    if(draggedItem == null) return;

    /*
     * Check if the item should be repositioned
     */

    //  Move up
    // Compute if the pointer dy location is higher than the vertical
    // midpoint of the immediately above adjacent item
    if (draggedItemIndex - 1 >= 0 &&
        dy <
            listStates[draggedListIndex]
                .itemStates[draggedItemIndex - 1].renderBox.localToGlobal(Offset.zero).dy +
                listStates[draggedListIndex]
                    .itemStates[draggedItemIndex - 1]
                    .renderBox.size.height /
                    2) {
      moveUp();
    }
    // Move down
    // Compute if the pointer dy location is lower than the vertical
    // midpoint of the immediately below adjacent item
    else if (draggedItemIndex + 1 < widget.lists[draggedListIndex].items.length &&
        dy >
            listStates[draggedListIndex]
                .itemStates[draggedItemIndex + 1].renderBox.localToGlobal(Offset.zero).dy +
                listStates[draggedListIndex]
                    .itemStates[draggedItemIndex + 1]
                    .renderBox.size.height /
                    2) {
      moveDown();
    }

    //    if (0 <= draggedListIndex - 1 && dx < leftListX) {
//      //move left
//      moveLeft();
//    }
//    if (widget.lists.length > draggedListIndex + 1 && dx > rightListX) {
//      //move right
//      moveRight();
//    }
  }

  void run() {
    if (pointer != null) {
      print("here!");
      handleDrag(pointer.position.dx, pointer.position.dy);

//      RenderBox renderBox = (context.findRenderObject() as RenderBox);
//
//      Offset topLeft = renderBox.localToGlobal(Offset.zero);
//      Offset bottomLeft =
//          renderBox.localToGlobal(renderBox.size.bottomLeft(Offset.zero));
//
//      // Scroll up
//      if (pointer.position.dy < topLeft.dy + 50) {
//        print("UP!");
//      }
//      // Scroll down
//      else if (pointer.position.dy > bottomLeft.dy - 50) {
//        print("DOWN");
//      }
//
//      setState(() {
//        dx = pointer.position.dx;
//        dy = pointer.position.dy;
//      });
    }
  }
}
