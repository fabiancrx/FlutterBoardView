import 'package:boardview/board_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

typedef void OnDropItem(int listIndex, int itemIndex, int oldListIndex,
    int oldItemIndex, BoardItemState state);
typedef void OnTapItem(int listIndex, int itemIndex, BoardItemState state);
typedef void OnStartDragItem(
    int listIndex, int itemIndex, BoardItemState state);
typedef void OnDragItem(int oldListIndex, int oldItemIndex, int newListIndex,
    int newItemIndex, BoardItemState state);

class BoardItem extends StatefulWidget {
  final BoardListState boardList;
  final Widget item;
  final int index;
  final OnDropItem onDropItem;
  final OnTapItem onTapItem;
  final OnStartDragItem onStartDragItem;
  final OnDragItem onDragItem;
  final Function(Rect bounds) onPreItemDrag;
  final Function(BoardItem, int itemIndex) onItemDrag;
  final bool draggable;

  const BoardItem(
      {Key key,
      this.boardList,
      this.item,
      this.index,
      this.onDropItem,
      this.onTapItem,
      this.onStartDragItem,
      this.draggable = true,
      this.onDragItem,
      @required this.onPreItemDrag,
      @required this.onItemDrag})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return BoardItemState();
  }
}

class BoardItemState extends State<BoardItem> {
  RenderBox get renderBox {
    return context.findRenderObject();
  }

  void onDropItem(int listIndex, int itemIndex) {
    widget.boardList.widget.boardView.listStates[listIndex].setState(() {
      if (widget.onDropItem != null) {
        widget.onDropItem(
            listIndex,
            itemIndex,
            widget.boardList.widget.boardView.startListIndex,
            widget.boardList.widget.boardView.startItemIndex,
            this);
      }
      widget.boardList.widget.boardView.draggedItemIndex = null;
      widget.boardList.widget.boardView.draggedListIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.boardList.itemStates.length > widget.index) {
      widget.boardList.itemStates.removeAt(widget.index);
    }
    widget.boardList.itemStates.insert(widget.index, this);
    return GestureDetector(
      onTapDown: (pointer) {
        RenderBox object = context.findRenderObject();
        Offset pos = object.localToGlobal(Offset.zero);

        Rect rect = Rect.fromLTWH(
            pos.dx, pos.dy, object.size.width * 0.8, object.size.height);

        // If the touch position would occur outside the right side (after width
        // adjustment), adjust initial's by the difference
        if (pointer.globalPosition.dx > rect.right) {
          double correction =
              pointer.globalPosition.dx - (rect.left + object.size.width * 0.7);
          rect = Rect.fromLTWH(
              rect.left + correction, rect.top, rect.width, rect.height);
        }

        widget.onPreItemDrag(rect);
      },
      onTapCancel: () {},
      onTap: () {
        if (widget.onTapItem != null) {
          widget.onTapItem(widget.boardList.widget.index, widget.index, this);
        }
      },
      onLongPress: () {
        widget.onItemDrag(widget, widget.index);
      },
      child: widget.item,
    );
  }
}
