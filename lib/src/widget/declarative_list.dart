import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';
import 'package:declarative_animated_list/src/algorithm/strategy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// A list widget which will calculate difference between the underlying lists
// submitted via constructor and animate UI changes automatically.
class DeclarativeList<T extends Object> extends StatefulWidget {
  /// Set of items to be displayed in the list
  final List<T> items;

  /// Builder function for inserted items
  final AnimatedItemBuilder<T> itemBuilder;

  /// Builder function for removed items
  final AnimatedItemBuilder<T> removeBuilder;

  /// Callback that is used to determine if two given objects are equal. [==]
  /// operator will be used by default.
  final EqualityCheck<T>? equalityCheck;

  /// Initial items count for the list, gets defined automatically
  final int initialItemCount;

  /// Refer to [AnimatedListState.insertItem]
  final Duration? insertDuration;

  /// Refer to [AnimatedListState.removeItem]
  final Duration? removeDuration;

  /// Refer to [AnimatedList.scrollDirection]
  final Axis scrollDirection;

  /// Refer to [AnimatedList.controller]
  final ScrollController? scrollController;

  /// Refer to [AnimatedList.padding]
  final EdgeInsetsGeometry? padding;

  /// Refer to [AnimatedList.physics]
  final ScrollPhysics? physics;

  /// Refer to [AnimatedList.primary]
  final bool? primary;

  /// Refer to [AnimatedList.reverse]
  final bool reverse;

  /// Refer to [AnimatedList.shrinkWrap]
  final bool shrinkWrap;

  /// Refer to [AnimatedList.clipBehavior]
  final Clip clipBehavior;

  const DeclarativeList({
    required this.items,
    required this.itemBuilder,
    required this.removeBuilder,
    this.equalityCheck,
    this.scrollDirection = Axis.vertical,
    this.insertDuration,
    this.removeDuration,
    this.scrollController,
    this.padding,
    this.physics,
    this.primary,
    this.reverse = false,
    this.shrinkWrap = false,
    this.clipBehavior = Clip.hardEdge,
    Key? key,
  })  : initialItemCount = items.length,
        super(key: key);

  @override
  _DeclarativeListState<T> createState() => _DeclarativeListState<T>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IterableProperty('items', items))
      ..add(IntProperty('initialItemCount', initialItemCount))
      ..add(DiagnosticsProperty('insertDuration', insertDuration))
      ..add(DiagnosticsProperty('removeDuration', removeDuration))
      ..add(EnumProperty('scrollDirection', scrollDirection))
      ..add(DiagnosticsProperty('scrollController', scrollController))
      ..add(DiagnosticsProperty('padding', padding))
      ..add(DiagnosticsProperty('physics', physics))
      ..add(DiagnosticsProperty('primary', primary))
      ..add(DiagnosticsProperty('reverse', reverse))
      ..add(DiagnosticsProperty('shrinkWrap', shrinkWrap))
      ..add(EnumProperty('clipBehavior', clipBehavior))
      ..add(ObjectFlagProperty.has('itemBuilder', itemBuilder))
      ..add(ObjectFlagProperty.has('removeBuilder', removeBuilder))
      ..add(ObjectFlagProperty.has('equalityCheck', equalityCheck));
  }
}

class _DeclarativeListState<T extends Object>
    extends State<DeclarativeList<T>> {
  final _animatedListKey = GlobalKey<AnimatedListState>();

  @override
  void didUpdateWidget(DeclarativeList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateList(oldWidget.items, widget.items);
  }

  void _updateList(final List<T> oldList, final List<T> newList) {
    final request = ListsDifferenceRequest(
      oldList,
      newList,
      equalityCheck: widget.equalityCheck,
    );
    final result =
        DifferentiatingStrategyFactory().create().differentiate(request);
    final consumer = _AnimatedListDifferenceConsumer<T>(
      this._animatedListKey.currentState!,
      oldList,
      newList,
      widget.removeBuilder,
      removeDuration: widget.removeDuration,
      insertDuration: widget.insertDuration,
    );
    result.dispatchUpdates(consumer);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _animatedListKey,
      initialItemCount: widget.initialItemCount,
      itemBuilder: (context, index, animation) {
        final item = widget.items[index];
        return widget.itemBuilder(context, item, index, animation);
      },
      scrollDirection: widget.scrollDirection,
      controller: widget.scrollController,
      padding: widget.padding,
      physics: widget.physics,
      primary: widget.primary,
      reverse: widget.reverse,
      shrinkWrap: widget.shrinkWrap,
      clipBehavior: widget.clipBehavior,
    );
  }
}

class _AnimatedListDifferenceConsumer<T> extends DifferenceConsumer {
  final AnimatedListState state;
  final List<T> oldList;
  final List<T> updatedList;
  final AnimatedItemBuilder<T> removeBuilder;
  final Duration? removeDuration;
  final Duration? insertDuration;

  _AnimatedListDifferenceConsumer(
    this.state,
    this.oldList,
    this.updatedList,
    this.removeBuilder, {
    this.insertDuration,
    this.removeDuration,
  });

  @override
  void onInserted(final int position, final int count) {
    for (int i = position; i < position + count; i++) {
      _insertItem(i);
    }
  }

  @override
  void onRemoved(final int position, final int count) {
    for (int i = position + count - 1; i >= position; i--) {
      _removeItem(i);
    }
  }

  @override
  void onMoved(final int oldPosition, final int newPosition) {
    _removeItem(oldPosition);
    _insertItem(newPosition);
  }

  void _insertItem(int position) {
    // We don't want to mess with the Flutter's internal constant in case it 
    // changes
    if (insertDuration != null) {
      state.insertItem(position, duration: insertDuration!);
    } else {
      state.insertItem(position);
    }
  }

  void _removeItem(final int index) {
    Widget builder(BuildContext context, Animation<double> animation) {
      return removeBuilder(context, oldList[index], index, animation);
    }

    // We don't want to mess with the Flutter's internal constant in case it 
    // changes
    if (removeDuration != null) {
      state.removeItem(index, builder, duration: removeDuration!);
    } else {
      state.removeItem(index, builder);
    }
  }
}

typedef AnimatedItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
  Animation<double> animation,
);
