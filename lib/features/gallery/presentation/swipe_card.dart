import 'package:flutter/material.dart';
import '../domain/swipe_action.dart';

class SwipeCard extends StatefulWidget {
  final Widget child;
  final ValueChanged<SwipeAction> onSwiped;
  final double threshold;

  const SwipeCard({
    super.key,
    required this.child,
    required this.onSwiped,
    this.threshold = 120,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  Offset _drag = Offset.zero;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    final dx = _drag.dx;
    final dy = _drag.dy;
    final horizontalWins = dx.abs() >= dy.abs();

    SwipeAction? action;
    if (horizontalWins && dx <= -widget.threshold) {
      action = SwipeAction.delete;
    } else if (horizontalWins && dx >= widget.threshold) {
      action = SwipeAction.keep;
    } else if (!horizontalWins && dy <= -widget.threshold) {
      action = SwipeAction.favourite;
    } else if (!horizontalWins && dy >= widget.threshold) {
      action = SwipeAction.skip;
    }

    if (action != null) {
      widget.onSwiped(action);
    }
    setState(() => _drag = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final rotation = (_drag.dx / 300).clamp(-0.35, 0.35);
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _drag,
        child: Transform.rotate(angle: rotation, child: widget.child),
      ),
    );
  }
}
