import 'package:declarative_animated_list/src/algorithm/myers/snake.dart';
import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';

class MyersDifferenceResult implements DifferenceResult {
  /// Signifies an item not present in the list.
  static const int no_position = -1;

  /// While reading the flags below, keep in mind that when multiple items move in a list,
  /// Myers's may pick any of them as the anchor item and consider that one NOT_CHANGED while
  /// picking others as additions and removals. This is completely fine as we later detect
  /// all moves.
  /// Below, when an item is mentioned to stay in the same "location", it means we won't
  /// dispatch a move/add/remove for it, it DOES NOT mean the item is still in the same
  /// position.
  // item stayed the same.
  static const int flag_not_changed = 1;

  // item stayed in the same location but changed.
  static const int flag_changed = flag_not_changed << 1;

  // Item has moved and also changed.
  static const int flag_moved_changed = flag_changed << 1;

  // Item has moved but did not change.
  static const int flag_moved_not_changed = flag_moved_changed << 1;

  // Ignore this update.
  // If this is an addition from the new list, it means the item is actually removed from an
  // earlier position and its move will be dispatched when we process the matching removal
  // from the old list.
  // If this is a removal from the old list, it means the item is actually added back to an
  // earlier index in the new list and we'll dispatch its move when we are processing that
  // addition.
  static const int flag_ignore = flag_moved_not_changed << 1;

  // since we are re-using the int arrays that were created in the Myers' step, we mask
  // change flags
  static const int flag_offset = 5;

  static const int flag_mask = (1 << flag_offset) - 1;

  final DifferenceRequest _request;
  final List<Snake> _snakes;
  final List<int> _oldItemStatuses;
  final List<int> _newItemStatuses;
  final bool _detectMoves;
  final int _oldListSize;
  final int _newListSize;

  MyersDifferenceResult(this._request, this._snakes, this._oldItemStatuses,
      this._newItemStatuses, this._detectMoves)
      : this._oldListSize = _request.oldSize,
        this._newListSize = _request.newSize {
    _oldItemStatuses.fillRange(0, _oldItemStatuses.length, 0);
    _newItemStatuses.fillRange(0, _newItemStatuses.length, 0);
    _addRootShake();
    _findMatchingItems();
  }

  void _addRootShake() {
    final Snake firstSnake = this._snakes.isEmpty ? null : this._snakes.first;
    if (firstSnake == null || firstSnake.x != 0 || firstSnake.y == 0) {
      this._snakes.insert(0, Snake.empty());
    }
  }

  void _findMatchingItems() {
    int oldPosition = _oldListSize;
    int newPosition = _newListSize;
    for (int i = _snakes.length - 1; i >= 0; i--) {
      final Snake snake = _snakes[i];
      final int endX = snake.x + snake.size;
      final int endY = snake.y + snake.size;
      if (_detectMoves) {
        while (oldPosition > endX) {
          // this is a removal. Check remaining snakes to see if this was added before
          _findAddition(oldPosition, newPosition, i);
          oldPosition--;
        }
        while (newPosition > endY) {
          // this is an addition. Check remaining snakes to see if this was removed
          // before
          _findRemoval(oldPosition, newPosition, i);
          newPosition--;
        }
      }
      for (int j = 0; j < snake.size; j++) {
        final int oldItemPosition = snake.x + j;
        final int newItemPosition = snake.y + j;
        final bool isTheSame =
            this._request.areInstancesEqual(oldItemPosition, newItemPosition);
        final int changeFlag = isTheSame ? flag_not_changed : flag_changed;
        _oldItemStatuses[oldItemPosition] =
            (newItemPosition << flag_offset) | changeFlag;
        _newItemStatuses[newItemPosition] =
            (oldItemPosition << flag_offset) | changeFlag;
      }
      oldPosition = snake.x;
      newPosition = snake.y;
    }
  }

  void _findAddition(final int x, final int y, final int snakeIndex) {
    if (_oldItemStatuses[x - 1] == 0) {
      _findMatchingItem(x, y, snakeIndex, false);
    }
  }

  void _findRemoval(final int x, final int y, final int snakeIndex) {
    if (_newItemStatuses[y - 1] == 0) {
      _findMatchingItem(x, y, snakeIndex, true);
    }
  }

  bool _findMatchingItem(
      final int x, final int y, final int snakeIndex, final bool removal) {
    final int myItemPosition = removal ? y - 1 : x - 1;
    int curX = removal ? x : x - 1;
    int curY = removal ? y - 1 : y;
    for (int i = snakeIndex; i >= 0; i--) {
      final Snake snake = this._snakes[i];
      final int endX = snake.x + snake.size;
      final int endY = snake.y + snake.size;
      if (removal) {
        // check removals for a match
        for (int pos = curX - 1; pos >= endX; pos--) {
          if (this._request.isTheSameConceptualEntity(pos, myItemPosition)) {
            // found!
            final bool isTheSame =
                this._request.areInstancesEqual(pos, myItemPosition);
            final int changeFlag =
                isTheSame ? flag_moved_not_changed : flag_moved_changed;
            _newItemStatuses[myItemPosition] =
                (pos << flag_offset) | flag_ignore;
            _oldItemStatuses[pos] =
                (myItemPosition << flag_offset) | changeFlag;
            return true;
          }
        }
      } else {
        // check for additions for a match
        for (int pos = curY - 1; pos >= endY; pos--) {
          if (this._request.isTheSameConceptualEntity(myItemPosition, pos)) {
            // found!
            final bool isTheSame =
                this._request.areInstancesEqual(myItemPosition, pos);
            final int changeFlag =
                isTheSame ? flag_moved_not_changed : flag_moved_changed;
            _oldItemStatuses[x - 1] = (pos << flag_offset) | flag_ignore;
            _newItemStatuses[pos] = ((x - 1) << flag_offset) | changeFlag;
            return true;
          }
        }
      }
      curX = snake.x;
      curY = snake.y;
    }
    return false;
  }

  @override
  void dispatchUpdates(final DifferenceResultConsumer consumer) {
    final BatchedListUpdateConsumer batchedConsumer = consumer.batched();
    final List<_PostponedUpdate> postponedUpdates =
        new List<_PostponedUpdate>();
    int oldPosition = _oldListSize;
    int newPosition = _newListSize;
    for (int snakeIndex = this._snakes.length - 1;
        snakeIndex >= 0;
        snakeIndex--) {
      final Snake snake = this._snakes[snakeIndex];
      final int snakeSize = snake.size;
      final int endX = snake.x + snakeSize;
      final int endY = snake.y + snakeSize;
      if (endX < oldPosition) {
        this._dispatchRemovals(
            postponedUpdates, batchedConsumer, endX, oldPosition - endX, endX);
      }
      if (endY < newPosition) {
        this._dispatchAdditions(
            postponedUpdates, batchedConsumer, endX, newPosition - endY, endY);
      }
      for (int i = snakeSize - 1; i >= 0; i--) {
        if ((_oldItemStatuses[snake.x + i] & flag_mask) == flag_changed) {
          batchedConsumer.onChange(snake.x + i, 1,
              this._request.getChangePayload(snake.x + i, snake.y + i));
        }
      }
      oldPosition = snake.x;
      newPosition = snake.y;
    }
    batchedConsumer.dispatchLastEvent();
  }

  void _dispatchAdditions(
      final List<_PostponedUpdate> postponedUpdates,
      final DifferenceResultConsumer consumer,
      final int start,
      final int count,
      final int globalIndex) {
    if (_detectMoves) {
      for (int i = count - 1; i >= 0; i--) {
        int status = _newItemStatuses[globalIndex + i] & flag_mask;
        switch (status) {
          case 0: // real addition
            consumer.onInsert(start, 1);
            for (_PostponedUpdate update in postponedUpdates) {
              update.currentPosition += 1;
            }
            break;
          case flag_moved_changed:
          case flag_moved_not_changed:
            final int pos = _newItemStatuses[globalIndex + i] >> flag_offset;
            final _PostponedUpdate update =
                _removePostponedUpdate(postponedUpdates, pos, true);
            // the item was moved from that position
            //noinspection ConstantConditions
            consumer.onMove(update.currentPosition, start);
            if (status == flag_moved_changed) {
              // also dispatch a change
              consumer.onChange(start, 1,
                  this._request.getChangePayload(pos, globalIndex + i));
            }
            break;
          case flag_ignore: // ignoring this
            postponedUpdates
                .add(_PostponedUpdate(globalIndex + i, start, false));
            break;
          default:
            throw new StateError(
                "Unknown flag for pos ${(globalIndex + i)} ${status.toRadixString(2)}");
        }
      }
    } else {
      consumer.onInsert(start, count);
    }
  }

  void _dispatchRemovals(
      final List<_PostponedUpdate> postponedUpdates,
      final DifferenceResultConsumer consumer,
      final int start,
      final int count,
      final int globalIndex) {
    if (_detectMoves) {
      for (int i = count - 1; i >= 0; i--) {
        final int status = _oldItemStatuses[globalIndex + i] & flag_mask;
        switch (status) {
          case 0: // real removal
            consumer.onRemove(start + i, 1);
            for (_PostponedUpdate update in postponedUpdates) {
              update.currentPosition -= 1;
            }
            break;
          case flag_moved_changed:
          case flag_moved_not_changed:
            final int pos = _oldItemStatuses[globalIndex + i] >> flag_offset;
            final _PostponedUpdate update =
                _removePostponedUpdate(postponedUpdates, pos, false);
            // the item was moved to that position. we do -1 because this is a move not
            // add and removing current item offsets the target move by 1
            //noinspection ConstantConditions
            consumer.onMove(start + i, update.currentPosition - 1);
            if (status == flag_moved_changed) {
              // also dispatch a change
              consumer.onChange(update.currentPosition - 1, 1,
                  this._request.getChangePayload(globalIndex + i, pos));
            }
            break;
          case flag_ignore: // ignoring this
            postponedUpdates
                .add(new _PostponedUpdate(globalIndex + i, start + i, true));
            break;
          default:
            throw new StateError(
                "Unknown flag for pos ${globalIndex + i} ${status.toRadixString(2)}");
        }
      }
    } else {
      consumer.onRemove(start, count);
    }
  }

  _PostponedUpdate _removePostponedUpdate(final List<_PostponedUpdate> updates,
      final int position, final bool removal) {
    for (int i = updates.length - 1; i >= 0; i--) {
      final _PostponedUpdate update = updates[i];
      if (update.positionInOwnerList == position && update.removal == removal) {
        updates.removeAt(i);
        for (int j = i; j < updates.length; j++) {
          // offset other ops since they swapped positions
          updates[j].currentPosition += removal ? 1 : -1;
        }
        return update;
      }
    }
    return null;
  }
}

class _PostponedUpdate {
  final int positionInOwnerList;
  int currentPosition;
  final bool removal;

  _PostponedUpdate(
      this.positionInOwnerList, this.currentPosition, this.removal);
}
