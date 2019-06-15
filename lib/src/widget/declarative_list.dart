//  Copyright 2019 nyarian
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';
import 'package:declarative_animated_list/src/algorithm/strategy.dart';

class DeclarativeList<T> extends StatefulWidget {
  ///Set of items to be displayed in the list
  final List<T> items;

  ///Builder function for inserted items
  final AnimatedItemBuilder<T> itemBuilder;

  ///Builder function for removed items
  final AnimatedItemBuilder<T> removeBuilder;

  ///Callback that is used to determine if two given objects are equal. [==]
  ///operator will be used by default.
  final EqualityCheck<T> equalityCheck;

  ///Initial items count for the list, gets defined automatically
  final int initialItemCount;

  ///Refer to [AnimatedListState.insertItem]
  final Duration insertDuration;

  ///Refer to [AnimatedListState.removeItem]
  final Duration removeDuration;

  ///Refer to [AnimatedList.scrollDirection]
  final Axis scrollDirection;

  ///Refer to [AnimatedList.scrollController]
  final ScrollController scrollController;

  ///Refer to [AnimatedList.padding]
  final EdgeInsetsGeometry padding;

  ///Refer to [AnimatedList.physics]
  final ScrollPhysics physics;

  ///Refer to [AnimatedList.primary]
  final bool primary;

  ///Refer to [AnimatedList.reverse]
  final bool reverse;

  ///Refer to [AnimatedList.shrinkWrap]
  final bool shrinkWrap;

  const DeclarativeList(
      {final Key key,
      @required this.items,
      @required this.itemBuilder,
      @required this.removeBuilder,
      this.equalityCheck,
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
    _updateList(oldWidget.items, this.widget.items);
  }

  void _updateList(final List<T> oldList, final List<T> newList) {
    final DifferenceResult result = DifferentiatingStrategyFactory()
        .create()
        .differentiate(ListsDifferenceRequest(oldList, newList,
            equalityCheck: this.widget.equalityCheck));
    final DifferenceConsumer consumer = _AnimatedListDifferenceConsumer<T>(
      this._animatedListKey.currentState,
      oldList,
      newList,
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
      itemBuilder: (final BuildContext context, final int index,
              final Animation<double> animation) =>
          this
              .widget
              .itemBuilder(context, this.widget.items[index], index, animation),
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
  final AnimatedItemBuilder<T> removeBuilder;
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
    final AnimatedListRemovedItemBuilder builder =
        (final BuildContext context, final Animation<double> animation) =>
            this.removeBuilder(context, oldList[index], index, animation);
    if (removeDuration != null) {
      state.removeItem(index, builder, duration: removeDuration);
    } else {
      state.removeItem(index, builder);
    }
  }
}

typedef AnimatedItemBuilder<T> = Widget Function(
    BuildContext context, T item, int index, Animation<double> animation);
