import 'package:declarative_animated_list/src/algorithm/myers/snake.dart';
import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';

class MyersDifferenceResult implements DifferenceResult {
  ///Signifies an item not present in the list.
  static const int _no_position = -1;

  // Item has moved but did not change.
  static const int _flag_moved = 1;

  // Ignore this update.
  // If this is an addition from the new list, it means the item is actually removed from an
  // earlier position and its move will be dispatched when we process the matching removal
  // from the old list.
  // If this is a removal from the old list, it means the item is actually added back to an
  // earlier index in the new list and we'll dispatch its move when we are processing that
  // addition.
  static const int _flag_ignore = _flag_moved << 1;

  // since we are re-using the int arrays that were created in the Myers' step, we mask
  // change flags
  static const int _flag_offset = 5;

  static const int _flag_mask = (1 << _flag_offset) - 1;

  // The Myers' snakes. At this point, we only care about their diagonal sections.
  final List<Snake> _snakes;

  // The list to keep oldItemStatuses. As we traverse old items, we assign flags to them
  // which also includes whether they were a real removal or a move (and its new index).
  final List<int> _oldItemStatuses;

  // The list to keep newItemStatuses. As we traverse new items, we assign flags to them
  // which also includes whether they were a real addition or a move(and its old index).
  final List<int> _newItemStatuses;

  // The callback that was given to calculate diff method.
  final DifferenceRequest _request;

  final int _oldListSize;

  final int _newListSize;

  final bool _detectMoves;

  ///[callback] The callback that was used to calculate the diff
  ///[snakes] The list of Myers' snakes
  ///[oldItemStatuses] An List<int> that can be re-purposed to keep metadata
  ///[newItemStatuses] An List<int> that can be re-purposed to keep metadata
  ///[detectMoves] True if this DiffResult will try to detect moved items
  MyersDifferenceResult(this._request, this._snakes, this._oldItemStatuses,
      this._newItemStatuses, this._detectMoves)
      : this._oldListSize = _request.oldSize,
        this._newListSize = _request.newSize {
    _oldItemStatuses.fillRange(0, _oldItemStatuses.length, 0);
    _newItemStatuses.fillRange(0, _newItemStatuses.length, 0);
    _addRootSnake();
    _findMatchingItems();
  }

  ///We always add a Snake to 0/0 so that we can run loops from end to beginning and be done
  ///when we run out of snakes.
  void _addRootSnake() {
    Snake firstSnake = _snakes.isEmpty ? null : _snakes[0];
    if (firstSnake == null || firstSnake.x != 0 || firstSnake.y != 0) {
      _snakes.insert(0, Snake.empty());
    }
  }

  ///This method traverses each addition / removal and tries to match it to a previous
  ///removal / addition. This is how we detect move operations.
  ///This class also flags whether an item has been changed or not.
  ///Implementation does this pre-processing so that if it is running on a big list, it can be moved
  ///to background thread where most of the expensive stuff will be calculated and kept in
  ///the statuses maps. Result uses this pre-calculated information while dispatching
  ///the updates (which is probably being called on the main thread).
  void _findMatchingItems() {
    int posOld = _oldListSize;
    int posNew = _newListSize;
    // traverse the matrix from right bottom to 0,0.
    for (int i = _snakes.length - 1; i >= 0; i--) {
      final Snake snake = _snakes[i];
      final int endX = snake.x + snake.size;
      final int endY = snake.y + snake.size;
      if (_detectMoves) {
        while (posOld > endX) {
          // this is a removal. Check remaining snakes to see if this was added before
          findAddition(posOld, posNew, i);
          posOld--;
        }
        while (posNew > endY) {
          // this is an addition. Check remaining snakes to see if this was removed
          // before
          findRemoval(posOld, posNew, i);
          posNew--;
        }
      }
      posOld = snake.x;
      posNew = snake.y;
    }
  }

  void findAddition(final int x, final int y, final int snakeIndex) {
    if (_oldItemStatuses[x - 1] == 0) {
      findMatchingItem(x, y, snakeIndex, false);
    }
  }

  void findRemoval(final int x, final int y, final int snakeIndex) {
    if (_newItemStatuses[y - 1] == 0) {
      findMatchingItem(x, y, snakeIndex, true); // already set by a latter item
    }
  }

  ///Given a position in the old list, returns the position in the new list, or
  ///[_no_position] if it was removed.
  ///[oldListPosition] is position of item in old list
  ///Returns the position of item in new list, or [_no_position] if not present.
  int convertOldPositionToNew(final int oldListPosition) {
    if (oldListPosition < 0 || oldListPosition >= _oldItemStatuses.length) {
      throw new RangeError(
          "Index out of bounds - passed position = $oldListPosition, old list "
          "size = ${_oldItemStatuses.length}");
    }
    final int status = _oldItemStatuses[oldListPosition];
    if ((status & _flag_mask) == 0) {
      return _no_position;
    } else {
      return status >> _flag_offset;
    }
  }

  ///Given a position in the new list, returns the position in the old list, or
  ///[_no_position] if it was removed.
  ///[newListPosition] - position of item in new list
  ///Returns the position of item in old list, or {@code NO_POSITION} if not present.
  int convertNewPositionToOld(final int newListPosition) {
    if (newListPosition < 0 || newListPosition >= _newItemStatuses.length) {
      throw new RangeError(
          "Index out of bounds - passed position = $newListPosition, new list "
          "size = ${_newItemStatuses.length}");
    }
    final int status = _newItemStatuses[newListPosition];
    if ((status & _flag_mask) == 0) {
      return _no_position;
    } else {
      return status >> _flag_offset;
    }
  }

  ///Finds a matching item that is before the given coordinates in the matrix
  ///(before : left and above).
  ///[x] The x position in the matrix (position in the old list)
  ///[y] The y position in the matrix (position in the new list)
  ///[snakeIndex] The current snake index
  ///[removal] - true if we are looking for a removal, false otherwise
  ///Returns true if such item is found.
  bool findMatchingItem(
      final int x, final int y, final int snakeIndex, final bool removal) {
    final int myItemPos = removal ? y - 1 : x - 1;
    int curX = removal ? x : x - 1;
    int curY = removal ? y - 1 : y;
    for (int i = snakeIndex; i >= 0; i--) {
      final Snake snake = _snakes[i];
      final int endX = snake.x + snake.size;
      final int endY = snake.y + snake.size;
      if (removal) {
        // check removals for a match
        for (int pos = curX - 1; pos >= endX; pos--) {
          if (_request.areEqual(pos, myItemPos)) {
            _newItemStatuses[myItemPos] = (pos << _flag_offset) | _flag_ignore;
            _oldItemStatuses[pos] =
                (myItemPos << _flag_offset) | _flag_moved;
            return true;
          }
        }
      } else {
        // check for additions for a match
        for (int pos = curY - 1; pos >= endY; pos--) {
          if (_request.areEqual(myItemPos, pos)) {
            // found
            _oldItemStatuses[x - 1] = (pos << _flag_offset) | _flag_ignore;
            _newItemStatuses[pos] = ((x - 1) << _flag_offset) | _flag_moved;
            return true;
          }
        }
      }
      curX = snake.x;
      curY = snake.y;
    }
    return false;
  }

  ///Dispatches update operations to the given Callback.
  ///These updates are atomic such that the first update call affects every
  ///update call that
  ///comes after it
  /// [updateCallback] -  The callback to receive the update operations.
  @override
  void dispatchUpdates(final DifferenceConsumer updateCallback) {
    final BatchingListUpdateCallback batchingCallback =
        updateCallback.batching();
    // These are add/remove ops that are converted to moves. We track their positions until
    // their respective update operations are processed.
    final List<_PostponedUpdate> postponedUpdates = new List();
    int posOld = _oldListSize;
    int posNew = _newListSize;
    for (int snakeIndex = _snakes.length - 1; snakeIndex >= 0; snakeIndex--) {
      final Snake snake = _snakes[snakeIndex];
      final int snakeSize = snake.size;
      final int endX = snake.x + snakeSize;
      final int endY = snake.y + snakeSize;
      if (endX < posOld) {
        _dispatchRemovals(
            postponedUpdates, batchingCallback, endX, posOld - endX, endX);
      }

      if (endY < posNew) {
        _dispatchAdditions(
            postponedUpdates, batchingCallback, endX, posNew - endY, endY);
      }
      posOld = snake.x;
      posNew = snake.y;
    }
    batchingCallback.dispatchLastEvent();
  }

  _PostponedUpdate _removePostponedUpdate(
      List<_PostponedUpdate> updates, int pos, bool removal) {
    for (int i = updates.length - 1; i >= 0; i--) {
      final _PostponedUpdate update = updates[i];
      if (update.posInOwnerList == pos && update.removal == removal) {
        updates.removeAt(i);
        for (int j = i; j < updates.length; j++) {
          // offset other ops since they swapped positions
          updates[j].currentPos += removal ? 1 : -1;
        }
        return update;
      }
    }
    return null;
  }

  void _dispatchAdditions(
      List<_PostponedUpdate> postponedUpdates,
      DifferenceConsumer updateCallback,
      int start,
      int count,
      int globalIndex) {
    if (_detectMoves) {
      for (int i = count - 1; i >= 0; i--) {
        int status = _newItemStatuses[globalIndex + i] & _flag_mask;
        switch (status) {
          case 0: // real addition
            updateCallback.onInserted(start, 1);
            for (_PostponedUpdate update in postponedUpdates) {
              update.currentPos += 1;
            }
            break;
          case _flag_moved:
            final int pos = _newItemStatuses[globalIndex + i] >> _flag_offset;
            final _PostponedUpdate update =
                _removePostponedUpdate(postponedUpdates, pos, true);
            // the item was moved from that position
            //noinspection ConstantConditions
            updateCallback.onMoved(update.currentPos, start);
            break;
          case _flag_ignore: // ignoring this
            postponedUpdates
                .add(new _PostponedUpdate(globalIndex + i, start, false));
            break;
          default:
            throw new StateError("unknown flag for pos ${globalIndex + i} "
                "${status.toRadixString(2)}");
        }
      }
    } else {
      updateCallback.onInserted(start, count);
    }
  }

  void _dispatchRemovals(
      final List<_PostponedUpdate> postponedUpdates,
      final DifferenceConsumer updateCallback,
      final int start,
      final int count,
      final int globalIndex) {
    if (_detectMoves) {
      for (int i = count - 1; i >= 0; i--) {
        final int status = _oldItemStatuses[globalIndex + i] & _flag_mask;
        switch (status) {
          case 0: // real removal
            updateCallback.onRemoved(start + i, 1);
            for (_PostponedUpdate update in postponedUpdates) {
              update.currentPos -= 1;
            }
            break;
          case _flag_moved:
            final int pos = _oldItemStatuses[globalIndex + i] >> _flag_offset;
            final _PostponedUpdate update =
                _removePostponedUpdate(postponedUpdates, pos, false);
            // the item was moved to that position. we do -1 because this is a move not
            // add and removing current item offsets the target move by 1
            //noinspection ConstantConditions
            updateCallback.onMoved(start + i, update.currentPos - 1);
            break;
          case _flag_ignore: // ignoring this
            postponedUpdates
                .add(new _PostponedUpdate(globalIndex + i, start + i, true));
            break;
          default:
            throw new StateError("unknown flag for pos ${(globalIndex + i)} "
                "${status.toRadixString(2)}");
        }
      }
    } else {
      updateCallback.onRemoved(start, count);
    }
  }
}

class _PostponedUpdate {
  int currentPos;
  final int posInOwnerList;
  final bool removal;

  _PostponedUpdate(this.posInOwnerList, this.currentPos, this.removal);
}
