import 'package:boardview/boardview.dart';
import 'package:boardview/boardview_controller.dart';
import 'package:flutter/material.dart';

class BoardViewExample extends StatefulWidget {
  @override
  _BoardViewExampleState createState() => _BoardViewExampleState();
}

class _BoardViewExampleState extends State<BoardViewExample> {
  final List<List<Widget>> _listData = [
    [Text("Page 1 - Item 1"), Text("Page 1 - Item 2")],
    [Text("Page 2 - Item 1")]
  ];

  BoardViewController boardViewController = new BoardViewController();

  @override
  Widget build(BuildContext context) {
    return BoardView(
      canDrag: true,
      controller: boardViewController,
      lists: _listData,
    );
  }
}
