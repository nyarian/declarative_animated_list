import 'package:declarative_animated_list/src/algorithm/myers/snake.dart';
import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';

class MyersDifferenceResult implements DifferenceResult {
  /// Signifies an item not present in the list.
  static const int _noPosition = -1;

  // Item has moved but did not change.
  static const int _flagMoved = 1;

  // Ignore this update.
  // If this is an addition from the new list, it means the item is actually
  // removed from an earlier position and its move will be dispatched when we
  // process the matching removal from the old list.
  // If this is a removal from the old list, it means the item is actually
  // added back to an earlier index in the new list and we'll dispatch its move
  // when we are processing that addition.
  static const int _flagIgnore = _flagMoved << 1;

  // since we are re-using the int arrays that were created in the Myers' step,
  // we mask change flags
  static const int _flagOffset = 5;

  static const int _flagMask = (1 << _flagOffset) - 1;

  // The Myers' snakes. At this point, we only care about their diagonal
  // sections.
  final List<Snake> _snakes;

  // The list to keep oldItemStatuses. As we traverse old items, we assign
  // flags to them which also includes whether they were a real removal or a
  // move (and its new index).
  final List<int> _oldItemStatuses;

  // The list to keep newItemStatuses. As we traverse new items, we assign
  // flags to them which also includes whether they were a real addition or a
  // move(and its old index).
  final List<int> _newItemStatuses;

  // The callback that was given to calculate diff method.
  final DifferenceRequest _request;

  final int _oldListSize;

  final int _newListSize;

  final bool _detectMoves;

  /// [_request] is used to calculate the diff
  /// [_snakes] The list of Myers' snakes
  /// [_oldItemStatuses] An List<int> that can be re-purposed to keep metadata
  /// [_newItemStatuses] An List<int> that can be re-purposed to keep metadata
  /// [detectMoves] True if this DiffResult will try to detect moved items
  MyersDifferenceResult(
    this._request,
    this._snakes,
    this._oldItemStatuses,
    this._newItemStatuses, {
    required bool detectMoves,
  })  : _detectMoves = detectMoves,
        _oldListSize = _request.oldSize,
        _newListSize = _request.newSize {
    _oldItemStatuses.fillRange(0, _oldItemStatuses.length, 0);
    _newItemStatuses.fillRange(0, _newItemStatuses.length, 0);
    _addRootSnake();
    _findMatchingItems();
  }

  /// We always add a Snake to 0/0 so that we can run loops from
  /// end to beginning and be done when we run out of snakes.
  void _addRootSnake() {
    final firstSnake = _snakes.isEmpty ? null : _snakes[0];
    if (firstSnake == null || firstSnake.x != 0 || firstSnake.y != 0) {
      _snakes.insert(0, Snake.empty());
    }
  }

  /// This method traverses each addition / removal and tries to match it to
  /// a previous removal / addition. This is how we detect move operations.
  /// This class also flags whether an item has been changed or not.
  /// Implementation does this pre-processing so that if it is running on a big
  /// list, it can be moved to background thread where most of the expensive
  /// stuff will be calculated and kept in the statuses maps. Result uses this
  /// pre-calculated information while dispatching the updates.
  void _findMatchingItems() {
    var posOld = _oldListSize;
    var posNew = _newListSize;
    // traverse the matrix from right bottom to 0,0.
    for (int i = _snakes.length - 1; i >= 0; i--) {
      final snake = _snakes[i];
      final endX = snake.x + snake.size;
      final endY = snake.y + snake.size;
      if (_detectMoves) {
        while (posOld > endX) {
          // this is a removal. Check remaining snakes to see if this was added
          // before
          findAddition(posOld, posNew, i);
          posOld--;
        }
        while (posNew > endY) {
          // this is an addition. Check remaining snakes to see if this was
          // removed before
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
      findMatchingItem(x, y, snakeIndex, removal: false);
    }
  }

  void findRemoval(final int x, final int y, final int snakeIndex) {
    if (_newItemStatuses[y - 1] == 0) {
      // already set by a latter item
      findMatchingItem(x, y, snakeIndex, removal: true);
    }
  }

  /// Given a position in the old list, returns the position in the new list, or
  /// [_noPosition] if it was removed.
  /// [oldListPosition] is position of item in old list
  /// Returns the position of item in new list, or [_noPosition] if not present.
  int convertOldPositionToNew(final int oldListPosition) {
    if (oldListPosition < 0 || oldListPosition >= _oldItemStatuses.length) {
      throw RangeError(
        'Index out of bounds - passed position = $oldListPosition, old list '
        'size = ${_oldItemStatuses.length}',
      );
    }
    final status = _oldItemStatuses[oldListPosition];
    if ((status & _flagMask) == 0) {
      return _noPosition;
    } else {
      return status >> _flagOffset;
    }
  }

  /// Given a position in the new list, returns the position in the old list, or
  /// [_noPosition] if it was removed.
  /// [newListPosition] - position of item in new list
  /// Returns the position of item in old list, or {@code NO_POSITION} if not
  /// present.
  int convertNewPositionToOld(final int newListPosition) {
    if (newListPosition < 0 || newListPosition >= _newItemStatuses.length) {
      throw RangeError(
        'Index out of bounds - passed position = $newListPosition, new list '
        'size = ${_newItemStatuses.length}',
      );
    }
    final status = _newItemStatuses[newListPosition];
    if ((status & _flagMask) == 0) {
      return _noPosition;
    } else {
      return status >> _flagOffset;
    }
  }

  /// Finds a matching item that is before the given coordinates in the matrix
  /// (before : left and above).
  /// [x] The x position in the matrix (position in the old list)
  /// [y] The y position in the matrix (position in the new list)
  /// [snakeIndex] The current snake index
  /// [removal] - true if we are looking for a removal, false otherwise
  /// Returns true if such item is found.
  bool findMatchingItem(int x, int y, int snakeIndex, {required bool removal}) {
    final myItemPos = removal ? y - 1 : x - 1;
    var curX = removal ? x : x - 1;
    var curY = removal ? y - 1 : y;
    for (int i = snakeIndex; i >= 0; i--) {
      final snake = _snakes[i];
      final endX = snake.x + snake.size;
      final endY = snake.y + snake.size;
      if (removal) {
        // check removals for a match
        for (int pos = curX - 1; pos >= endX; pos--) {
          if (_request.areEqual(pos, myItemPos)) {
            _newItemStatuses[myItemPos] = (pos << _flagOffset) | _flagIgnore;
            _oldItemStatuses[pos] = (myItemPos << _flagOffset) | _flagMoved;
            return true;
          }
        }
      } else {
        // check for additions for a match
        for (int pos = curY - 1; pos >= endY; pos--) {
          if (_request.areEqual(myItemPos, pos)) {
            // found
            _oldItemStatuses[x - 1] = (pos << _flagOffset) | _flagIgnore;
            _newItemStatuses[pos] = ((x - 1) << _flagOffset) | _flagMoved;
            return true;
          }
        }
      }
      curX = snake.x;
      curY = snake.y;
    }
    return false;
  }

  /// Dispatches update operations to the given Callback.
  /// These updates are atomic such that the first update call affects every
  /// update call that comes after it.
  /// [updateCallback] -  The callback to receive the update operations.
  @override
  void dispatchUpdates(final DifferenceConsumer updateCallback) {
    final batchingCallback = updateCallback.batch();
    // These are add/remove ops that are converted to moves. We track their positions until
    // their respective update operations are processed.
    final postponedUpdates = <_PostponedUpdate>[];
    var posOld = _oldListSize;
    var posNew = _newListSize;
    for (int snakeIndex = _snakes.length - 1; snakeIndex >= 0; snakeIndex--) {
      final snake = _snakes[snakeIndex];
      final snakeSize = snake.size;
      final endX = snake.x + snakeSize;
      final endY = snake.y + snakeSize;
      if (endX < posOld) {
        _dispatchRemovals(
          postponedUpdates,
          batchingCallback,
          endX,
          posOld - endX,
          endX,
        );
      }
      if (endY < posNew) {
        _dispatchAdditions(
          postponedUpdates,
          batchingCallback,
          endX,
          posNew - endY,
          endY,
        );
      }
      posOld = snake.x;
      posNew = snake.y;
    }
    batchingCallback.dispatchLastEvent();
  }

  _PostponedUpdate _removePostponedUpdate(
    List<_PostponedUpdate> updates,
    int pos, {
    required bool removal,
  }) {
    for (int i = updates.length - 1; i >= 0; i--) {
      final update = updates[i];
      if (update.posInOwnerList == pos && update.removal == removal) {
        updates.removeAt(i);
        for (int j = i; j < updates.length; j++) {
          // offset other ops since they swapped positions
          updates[j].currentPos += removal ? 1 : -1;
        }
        return update;
      }
    }
    throw StateError(
      'Expected the postponed update, but did not find any. '
      'Pos: $pos, removal: $removal, updates: $updates',
    );
  }

  void _dispatchAdditions(
    List<_PostponedUpdate> postponedUpdates,
    DifferenceConsumer updateCallback,
    int start,
    int count,
    int globalIndex,
  ) {
    if (_detectMoves) {
      for (int i = count - 1; i >= 0; i--) {
        int status = _newItemStatuses[globalIndex + i] & _flagMask;
        switch (status) {
          // real addition
          case 0:
            updateCallback.onInserted(start, 1);
            for (final update in postponedUpdates) {
              update.currentPos += 1;
            }
            break;
          // the item was moved from that position
          case _flagMoved:
            final pos = _newItemStatuses[globalIndex + i] >> _flagOffset;
            final update =
                _removePostponedUpdate(postponedUpdates, pos, removal: true);
            updateCallback.onMoved(update.currentPos, start);
            break;
          // ignoring this
          case _flagIgnore:
            postponedUpdates
                .add(_PostponedUpdate(globalIndex + i, start, removal: false));
            break;
          default:
            throw StateError('unknown flag for pos ${globalIndex + i} '
                '${status.toRadixString(2)}');
        }
      }
    } else {
      updateCallback.onInserted(start, count);
    }
  }

  void _dispatchRemovals(
    List<_PostponedUpdate> postponedUpdates,
    DifferenceConsumer updateCallback,
    int start,
    int count,
    int globalIndex,
  ) {
    if (_detectMoves) {
      for (int i = count - 1; i >= 0; i--) {
        final status = _oldItemStatuses[globalIndex + i] & _flagMask;
        switch (status) {
          // real removal
          case 0:
            updateCallback.onRemoved(start + i, 1);
            for (final update in postponedUpdates) {
              update.currentPos -= 1;
            }
            break;
          case _flagMoved:
            final pos = _oldItemStatuses[globalIndex + i] >> _flagOffset;
            final update =
                _removePostponedUpdate(postponedUpdates, pos, removal: false);
            // the item was moved to that position. we do -1 because this is a
            // move not add and removing current item offsets the target move
            // by 1
            updateCallback.onMoved(start + i, update.currentPos - 1);
            break;
          // ignoring this
          case _flagIgnore:
            postponedUpdates.add(
                _PostponedUpdate(globalIndex + i, start + i, removal: true));
            break;
          default:
            throw StateError('unknown flag for pos ${globalIndex + i} '
                '${status.toRadixString(2)}');
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

  _PostponedUpdate(
    this.posInOwnerList,
    this.currentPos, {
    required this.removal,
  });
}
