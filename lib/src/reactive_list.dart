import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:declarative_animated_list/src/algorithm/myers/myer.dart';


class ReactiveList<T> extends StatefulWidget {
  final List<T> items;
  final AnimatedListItemBuilder itemBuilder;
  final AnimatedListRemovedItemBuilder removeBuilder;
  final int initialItemCount;
  final Axis scrollDirection;
  final ScrollController scrollController;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics physics;
  final bool primary;
  final bool reverse;
  final bool shrinkWrap;

  const ReactiveList(
      {final Key key,
      @required this.items,
      @required this.itemBuilder,
      @required this.removeBuilder,
      this.scrollDirection = Axis.vertical,
      this.scrollController,
      this.padding,
      this.physics,
      this.primary,
      this.reverse = false,
      this.shrinkWrap = false})
      : this.initialItemCount = items?.length ?? 0,
        super(key: key);

  @override
  _ReactiveListState<T> createState() => _ReactiveListState();
}

class _ReactiveListState<T> extends State<ReactiveList> {
  final GlobalKey<AnimatedListState> _animatedListKey =
      GlobalKey<AnimatedListState>();
  List<T> items;

  @override
  void initState() {
    super.initState();
    this.items = List<T>.from(this.widget.items);
  }

  @override
  void didUpdateWidget(final ReactiveList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final DifferenceResult result = MyersDifferenceAlgorithm().differentiate(
        ListsCallback(oldWidget.items, this.widget.items));
    result.dispatchUpdates(_AnimatedListDifferenceConsumer(
        this._animatedListKey.currentState,
        this.widget.items,
        this.widget.removeBuilder));
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
  final List<T> updatedList;
  final AnimatedListRemovedItemBuilder removeBuilder;

  _AnimatedListDifferenceConsumer(
      this.state, this.updatedList, this.removeBuilder);

  @override
  void onInserted(final int position, final int count) {
    for (int i = position; i < position + count; i++) {
      state.insertItem(i);
    }
  }

  @override
  void onRemoved(final int position, final int count) {
    for (int i = position; i < position + count; i++) {
      state.removeItem(i, this.removeBuilder);
    }
  }

  @override
  void onMoved(final int oldPosition, final int newPosition) {
    state.removeItem(oldPosition, this.removeBuilder);
    state.insertItem(newPosition);
  }

  @override
  void onChanged(final int position, final int count, final Object payload) {
    for (int i = position; i < position + count; i++) {
      this.onMoved(i, i);
    }
  }
}

class ListsCallback<T> extends DifferenceRequest {

  final List<T> oldList;
  final List<T> newList;


  ListsCallback(this.oldList, this.newList);

  @override
  bool areEqual(int oldPosition, int newPosition) {
    return oldList[oldPosition] == newList[newPosition];
  }

  @override
  int get newSize => newList.length;

  @override
  int get oldSize => oldList.length;

}
