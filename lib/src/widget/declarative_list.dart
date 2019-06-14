import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:declarative_animated_list/src/algorithm/myers/myer.dart';

class DeclarativeList<T> extends StatefulWidget {
  final List<T> items;
  final AnimatedListItemBuilder itemBuilder;
  final RemoveBuilder<T> removeBuilder;
  final int initialItemCount;
  final Duration insertDuration;
  final Duration removeDuration;
  final Axis scrollDirection;
  final ScrollController scrollController;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics physics;
  final bool primary;
  final bool reverse;
  final bool shrinkWrap;

  const DeclarativeList(
      {final Key key,
      @required this.items,
      @required this.itemBuilder,
      @required this.removeBuilder,
      this.scrollDirection = Axis.vertical,
      this.insertDuration,
      this.removeDuration,
      this.scrollController,
      this.padding,
      this.physics,
      this.primary,
      this.reverse = false,
      this.shrinkWrap = false})
      : this.initialItemCount = items?.length ?? 0,
        super(key: key);

  @override
  _DeclarativeListState<T> createState() => _DeclarativeListState<T>();
}

class _DeclarativeListState<T> extends State<DeclarativeList<T>> {
  final GlobalKey<AnimatedListState> _animatedListKey =
      GlobalKey<AnimatedListState>();
  List<T> items;

  @override
  void initState() {
    super.initState();
    this.items = List<T>.from(this.widget.items);
  }

  @override
  void didUpdateWidget(final DeclarativeList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final DifferenceResult result = MyersDifferenceAlgorithm().differentiate(
        ListsDifferenceRequest(oldWidget.items, this.widget.items));
    final DifferenceConsumer consumer = _AnimatedListDifferenceConsumer<T>(
      this._animatedListKey.currentState,
      oldWidget.items,
      this.widget.items,
      this.widget.removeBuilder,
      removeDuration: this.widget.removeDuration,
      insertDuration: this.widget.insertDuration,
    );
    result.dispatchUpdates(consumer);
  }

  @override
  Widget build(final BuildContext context) {
    return AnimatedList(
      key: _animatedListKey,
      initialItemCount: widget.initialItemCount,
      itemBuilder: widget.itemBuilder,
      scrollDirection: widget.scrollDirection,
      controller: widget.scrollController,
      padding: widget.padding,
      physics: widget.physics,
      primary: widget.primary,
      reverse: widget.reverse,
      shrinkWrap: widget.shrinkWrap,
    );
  }
}

class _AnimatedListDifferenceConsumer<T> extends DifferenceConsumer {
  final AnimatedListState state;
  final List<T> oldList;
  final List<T> updatedList;
  final RemoveBuilder<T> removeBuilder;
  final Duration removeDuration;
  final Duration insertDuration;

  _AnimatedListDifferenceConsumer(
      this.state, this.oldList, this.updatedList, this.removeBuilder,
      {this.insertDuration, this.removeDuration});

  @override
  void onInserted(final int position, final int count) {
    for (int i = position; i < position + count; i++) {
      _insertItem(i);
    }
  }

  @override
  void onRemoved(final int position, final int count) {
    for (int i = position; i < position + count; i++) {
      _removeItem(i);
    }
  }

  @override
  void onMoved(final int oldPosition, final int newPosition) {
    _removeItem(oldPosition);
    _insertItem(newPosition);
  }

  void _insertItem(int position) {
    if (insertDuration != null) {
      state.insertItem(position, duration: insertDuration);
    } else {
      state.insertItem(position);
    }
  }

  void _removeItem(final int index) {
    if (removeDuration != null) {
      state.removeItem(index, this.removeBuilder(oldList[index]),
          duration: removeDuration);
    } else {
      state.removeItem(index, this.removeBuilder(oldList[index]));
    }
  }
}

typedef InsertBuilder<T> = AnimatedListItemBuilder Function(T item);

typedef RemoveBuilder<T> = AnimatedListRemovedItemBuilder Function(T item);
