import 'package:boardview/board_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class BoardItem extends StatefulWidget {
  final BoardListState boardList;
  final Widget item;
  final int index;
  final Function(Rect bounds) onPreItemDrag;
  final Function(BoardItem, int itemIndex) onItemDrag;
  final bool draggable;

  const BoardItem(
      {Key key,
      this.boardList,
      this.item,
      this.index,
      this.draggable = true,
      @required this.onPreItemDrag,
      @required this.onItemDrag})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return BoardItemState();
  }
}

class BoardItemState extends State<BoardItem> {
  double get top {
    RenderBox box = context.findRenderObject();
    return box.localToGlobal(Offset.zero).dy;
  }

  double get height {
    RenderBox box = context.findRenderObject();
    return box.size.height;
  }

  double get verticalMidpoint {
    return top + height / 2;
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
      onLongPress: () {
        widget.onItemDrag(widget, widget.index);
      },
      child: widget.item,
    );
  }
}
