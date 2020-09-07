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
  final List<BoardItem> items;
  final Color backgroundColor;
  final Color headerBackgroundColor;
  final BoardViewState boardView;
  final OnDropList onDropList;
  final OnTapList onTapList;
  final OnStartDragList onStartDragList;
  final bool draggable;
  final BoardViewMode boardViewMode;

  const BoardList({
    Key key,
    this.header,
    this.items,
    this.footer,
    this.backgroundColor,
    this.headerBackgroundColor,
    this.boardView,
    this.draggable = true,
    this.index,
    this.onDropList,
    this.onTapList,
    this.onStartDragList,
    this.boardViewMode,
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
    if(context == null) {
      return double.infinity;
    }

    RenderBox renderBox = context.findRenderObject();
    Offset offset = renderBox.localToGlobal(Offset.zero);
    return offset.dx;
  }
  
  double get right {
    if(context == null) {
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
  
  void onDropList(int listIndex) {
    widget.boardView.setState(() {
      if (widget.onDropList != null) {
        widget.onDropList(listIndex, widget.boardView.startListIndex);
      }
      widget.boardView.draggedListIndex = null;
    });
  }

  void _startDrag(Widget item, BuildContext context) {
    if (widget.boardView != null && widget.draggable) {
      widget.boardView.setState(() {
        if (widget.onStartDragList != null) {
          widget.onStartDragList(widget.index);
        }
        widget.boardView.startListIndex = widget.index;
        widget.boardView.height = context.size.height;
        widget.boardView.draggedListIndex = widget.index;
        widget.boardView.draggedItemIndex = null;
        widget.boardView.draggedItem = item;
        widget.boardView.onDropList = onDropList;
        widget.boardView.run();
      });
    }
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
          if (widget.items[index].boardList == null ||
              widget.items[index].index != index ||
              widget.items[index].boardList.widget.index != widget.index ||
              widget.items[index].boardList != this) {
            widget.items[index] = new BoardItem(
              boardList: this,
              item: widget.items[index].item,
              draggable: widget.items[index].draggable,
              index: index,
              onDropItem: widget.items[index].onDropItem,
              onTapItem: widget.items[index].onTapItem,
              onDragItem: widget.items[index].onDragItem,
              onStartDragItem: widget.items[index].onStartDragItem,
            );
          }
          if (widget.boardView.draggedItemIndex == index &&
              widget.boardView.draggedListIndex == widget.index) {
            return Opacity(
              opacity: 0.0,
              child: widget.items[index],
            );
          } else {
            return widget.items[index];
          }
        },
      )));
    }

    if (widget.footer != null) {
      listWidgets.add(widget.footer);
    }

    if (widget.boardView.listStates.length > widget.index) {
      widget.boardView.listStates.removeAt(widget.index);
    }
    widget.boardView.listStates.insert(widget.index, this);

    var page = Column(children: listWidgets);
    
    return widget.boardViewMode == BoardViewMode.pages
        ? GestureDetector(
            onTap: () {
              if (widget.onTapList != null) {
                widget.onTapList(widget.index);
              }
            },
            onTapDown: (pointer) {
              if (widget.draggable) {
                RenderBox object = context.findRenderObject();
                Offset pos = object.localToGlobal(Offset.zero);
                widget.boardView.initialX = pos.dx;
                widget.boardView.initialY = pos.dy;
                widget.boardView.width = object.size.width * 0.8;

                // If the touch position would occur outside the right side (after width
                // adjustment), adjust initial's by the difference
                if(pointer.globalPosition.dx > pos.dx + object.size.width * 0.8) {
                  widget.boardView.initialX += pointer.globalPosition.dx - (pos.dx + object.size.width * 0.7);
                }
              }
            },
            onTapCancel: () {},
            onLongPress: () {
              if (!widget.boardView.widget.isSelecting && widget.draggable) {
                _startDrag(widget, context);
              }
            },
            child: AbsorbPointer(child: page))
        : page;
  }
}
