import 'package:boardview/boardview.dart';
import 'package:boardview/boardview_controller.dart';
import 'package:flutter/material.dart';

class BoardViewExample extends StatefulWidget {
  @override
  _BoardViewExampleState createState() => _BoardViewExampleState();
}

class MyPage implements BoardPage {
  final List<Widget> _widgets;

  @override
  List<Widget> get widgets => _widgets;

  @override
  double scrollPosition = 0;

  @override
  int id;

  MyPage(this.id, this.scrollPosition, this._widgets);

  @override
  String name;
}

class _BoardViewExampleState extends State<BoardViewExample> {
  final List<BoardPage> _listData = [
    MyPage(0, 0, [Text("Page 1 - Item 1"), Text("Page 1 - Item 2")]),
    MyPage(1, 0, [Text("Page 2 - Item 1")]),
  ];

  BoardViewController boardViewController = new BoardViewController();

  @override
  Widget build(BuildContext context) {
    return BoardView(
      canDrag: true,
      controller: boardViewController,
      lists: _listData,
      onItemDropped: (int oldListIndex, int newListIndex, int oldItemIndex,
          int newItemIndex) {},
      activeDotColor: null,
      onLockPressed: (int listIndex) {},
      onAttemptDelete: (int listIndex) {
        return null;
      },
      onListDropped: (int oldListIndex, int newListIndex) {},
    );
  }
}
