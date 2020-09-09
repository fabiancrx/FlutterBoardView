import 'package:boardview/board_item.dart';
import 'package:boardview/boardview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

typedef void OnDropList(int listIndex, int oldListIndex);
typedef void OnTapList(int listIndex);
typedef void OnStartDragList(int listIndex);

class BoardList extends StatefulWidget {
  final List<Widget> header;
  final Widget footer;
  final List<Widget> items;
  final Color backgroundColor;
  final Color headerBackgroundColor;
  final BoardViewState boardView;
  final BoardViewMode boardViewMode;

  final Function(Rect bounds) onPreListDrag;
  final Function(BoardList, int listIndex) onListDrag;
  // These just pass up events from children
  final Function(Rect bounds) onPreItemDrag;
  final Function(BoardItem, int itemIndex) onItemDrag;

  const BoardList({
    Key key,
    this.header,
    this.items,
    this.footer,
    this.backgroundColor,
    this.headerBackgroundColor,
    this.boardView,
    this.index,
    this.boardViewMode,
    @required this.onPreListDrag,
    @required this.onListDrag,
    @required this.onPreItemDrag,
    @required this.onItemDrag
  }) : super(key: key);

  final int index;

  @override
  State<StatefulWidget> createState() {
    return BoardListState();
  }
}

class BoardListState extends State<BoardList> {
  List<BoardItemState> itemStates = List<BoardItemState>();
  ScrollController boardListController = new ScrollController();

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
    List<Widget> listWidgets = new List<Widget>();
    if (widget.header != null) {
      listWidgets.add(Container(
        color: widget.headerBackgroundColor,
        child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.header),
      ));
    }

    if (widget.items != null) {
      listWidgets.add(Flexible(
          child: new ListView.builder(
        shrinkWrap: true,
        controller: boardListController,
        itemCount: widget.items.length,
        itemBuilder: (ctx, index) {
          var item = BoardItem(
              key: ValueKey(index + 100 * widget.index),
              boardList: this,
              item: widget.items[index],
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
      )));
    }

    if (widget.boardView.listStates.length > widget.index) {
      widget.boardView.listStates.removeAt(widget.index);
    }
    widget.boardView.listStates.insert(widget.index, this);

    var page = Column(children: listWidgets);

    return widget.boardViewMode == BoardViewMode.pages
        ? GestureDetector(
            onTapDown: (pointer) {
              RenderBox object = context.findRenderObject();
              Offset pos = object.localToGlobal(Offset.zero);

              Rect rect = Rect.fromLTWH(pos.dx, pos.dy, object.size.width * 0.8, object.size.height);

              // If the touch position would occur outside the right side (after width
              // adjustment), adjust initial's by the difference
              if (pointer.globalPosition.dx > rect.right) {
                double correction = pointer.globalPosition.dx - (rect.left + object.size.width * 0.7);
                rect = Rect.fromLTWH(rect.left + correction, rect.top, rect.width, rect.height);
              }

              widget.onPreListDrag(rect);
            },
            onTapCancel: () {},
            onLongPress: () {
              widget.onListDrag(widget, widget.index);
            },
            child: AbsorbPointer(child: page))
        : page;
  }
}
