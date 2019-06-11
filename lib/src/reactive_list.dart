import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ReactiveList<T> extends StatefulWidget {
  final List<T> items;
  final AnimatedListItemBuilder itemBuilder;
  final AnimatedListItemBuilder removeBuilder;
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
      this.scrollDirection,
      this.scrollController,
      this.padding,
      this.physics,
      this.primary,
      this.reverse,
      this.shrinkWrap})
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
  void didUpdateWidget(ReactiveList oldWidget) {
    super.didUpdateWidget(oldWidget);
    //TODO calculate diff and update all the things
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
