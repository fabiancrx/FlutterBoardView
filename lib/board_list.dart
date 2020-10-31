import 'package:boardview/board_item.dart';
import 'package:boardview/boardview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

typedef void OnDropList(int listIndex, int oldListIndex);
typedef void OnTapList(int listIndex);
typedef void OnStartDragList(int listIndex);

class BoardList extends StatefulWidget {
  final BoardPage page;
  final Color backgroundColor;
  final Color headerBackgroundColor;
  final BoardViewState boardView;
  final BoardViewMode boardViewMode;

  final Function(Rect bounds) onPreListDrag;
  final Function(BoardList, int listIndex) onListDrag;

  // These just pass up events from children
  final Function(Rect bounds) onPreItemDrag;
  final Function(BoardItem, int itemIndex) onItemDrag;

  final Function(String) onTitleChanged;
  final VoidCallback onDeletePressed;
  final VoidCallback onLockPressed;

  final String title;

  final int index;

  const BoardList(
      {Key key,
      this.page,
      this.backgroundColor,
      this.headerBackgroundColor,
      this.boardView,
      this.index,
      this.boardViewMode,
      @required this.onTitleChanged,
      @required this.title,
      @required this.onDeletePressed,
      @required this.onLockPressed,
      @required this.onPreListDrag,
      @required this.onListDrag,
      @required this.onPreItemDrag,
      @required this.onItemDrag})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return BoardListState();
  }
}

class BoardListState extends State<BoardList> with AutomaticKeepAliveClientMixin<BoardList> {
  List<BoardItemState> itemStates = List<BoardItemState>();
  ScrollController boardListController;

  TextEditingController headerEditingController;

  @override
  void initState() {
    super.initState();

    boardListController =
        ScrollController(initialScrollOffset: widget.page.scrollPosition, keepScrollOffset: false);

    headerEditingController = TextEditingController(text: widget.title);
  }

  @override
  void dispose() {
    boardListController.dispose();
    headerEditingController.dispose();
    super.dispose();
  }

  double get left {
    if (context == null) {
      return double.infinity;
    }

    RenderBox renderBox = context.findRenderObject();
    Offset offset = renderBox.localToGlobal(Offset.zero);
    return offset.dx;
  }

  double get right {
    if (context == null) {
      return double.negativeInfinity;
    }

    RenderBox renderBox = context.findRenderObject();
    Offset offset = renderBox.localToGlobal(Offset.zero);
    return offset.dx + renderBox.size.width;
  }

  double get top {
    RenderBox renderBox = context.findRenderObject();
    Offset offset = renderBox.localToGlobal(Offset.zero);
    return offset.dy;
  }

  double get bottom {
    RenderBox renderBox = context.findRenderObject();
    Offset offset = renderBox.localToGlobal(Offset.zero);
    return offset.dy + renderBox.size.height;
  }

  double get middleHorizontal {
    return (left + right) / 2;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.boardView.listStates.length > widget.index) {
      widget.boardView.listStates.removeAt(widget.index);
    }
    widget.boardView.listStates.insert(widget.index, this);

    var boardList = ListView.builder(
      padding: widget.boardViewMode == BoardViewMode.single
          ? const EdgeInsets.only(bottom: kFloatingActionButtonMargin + 48)
          : null,
      shrinkWrap: true,
      controller: boardListController,
      itemCount: widget.page.widgets.length,
      addAutomaticKeepAlives: true,
      itemBuilder: (ctx, index) {
        var item = BoardItem(
            key: widget.page.widgets[index].key,
            boardList: this,
            item: widget.page.widgets[index],
            index: index,
            onPreItemDrag: widget.onPreItemDrag,
            onItemDrag: widget.onItemDrag);

        if (widget.boardView.draggedItemIndex == index &&
            widget.boardView.draggedListIndex == widget.index) {
          return Opacity(
            opacity: 0,
            child: item,
          );
        } else {
          return item;
        }
      },
    );

    var list = NotificationListener(
      onNotification: (notification) {
        if (notification is ScrollNotification) {
          widget.page.scrollPosition = notification.metrics.pixels;
        }

        return true;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.boardViewMode == BoardViewMode.pages)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextField(
                          onChanged: (val) {
                            widget.onTitleChanged(val);
                          },
                          controller: headerEditingController,
                          decoration: InputDecoration(
                              contentPadding: EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 0),
                              labelText: "Page name",
                              border: OutlineInputBorder())),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.all(8),
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: Color.fromRGBO(0, 0, 0, 0.7)),
                    child: IconButton(
                      icon: Icon(Icons.lock),
                      iconSize: 30,
                      padding: EdgeInsets.all(0),
                      onPressed: () {
                        widget.onLockPressed();

                        //widget.onLockPressed(index);
                      },
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.all(8),
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: Color.fromRGBO(0, 0, 0, 0.7)),
                    child: IconButton(
                      icon: Icon(Icons.delete),
                      color: Colors.red,
                      iconSize: 30,
                      padding: EdgeInsets.all(0),
                      onPressed: () {
                        widget.onDeletePressed();
                        // var deleted = await widget.onAttemptDelete(index);
                        //
                        // setState(() {
                        //   if(deleted != null) {
                        //     boardViewController.jumpToPage(max(deleted - 1, 0));
                        //   }
                        // });
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (widget.boardViewMode == BoardViewMode.pages)
            Flexible(fit: FlexFit.loose, child: AbsorbPointer(child: boardList))
          else
            Flexible(fit: FlexFit.loose, child: boardList)
        ],
      ),
    );

    return list;
  }

  void onTapDown(pointer) {
    RenderBox object = context.findRenderObject();
    Offset pos = object.localToGlobal(Offset.zero);

    Rect rect = Rect.fromLTWH(pos.dx, pos.dy, object.size.width * 0.9, object.size.height);

    // If the touch position would occur outside the right side (after width
    // adjustment), adjust initial's by the difference
    if (pointer.globalPosition.dx > rect.right) {
      double correction = pointer.globalPosition.dx - (rect.left + object.size.width * 0.8);
      rect = Rect.fromLTWH(rect.left + correction, rect.top, rect.width, rect.height);
    }

    widget.onPreListDrag(rect);
  }

  void onLongPress() {
    widget.onListDrag(widget, widget.index);
  }

  @override
  bool get wantKeepAlive => true;
}
