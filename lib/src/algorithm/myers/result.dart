import 'package:declarative_animated_list/src/algorithm/myers/snake.dart';
import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';

class MyersDifferenceResult implements DifferenceResult {
  ///Signifies an item not present in the list.
  static const int no_position = -1;

  ///
  ///While reading the flags below, keep in mind that when multiple items move in a list,
  ///Myers's may pick any of them as the anchor item and consider that one NOT_CHANGED while
  ///picking others as additions and removals. This is completely fine as we later detect
  ///all moves.
  ///Below, when an item is mentioned to stay in the same "location", it means we won't
  ///dispatch a move/add/remove for it, it DOES NOT mean the item is still in the same
  ///position.
  ///
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

  // The Myers' snakes. At this point, we only care about their diagonal sections.
  final List<Snake> mSnakes;

  // The list to keep oldItemStatuses. As we traverse old items, we assign flags to them
  // which also includes whether they were a real removal or a move (and its new index).
  final List<int> mOldItemStatuses;

  // The list to keep newItemStatuses. As we traverse new items, we assign flags to them
  // which also includes whether they were a real addition or a move(and its old index).
  final List<int> mNewItemStatuses;

  // The callback that was given to calculate diff method.
  final DifferenceRequest _request;

  final int mOldListSize;

  final int mNewListSize;

  final bool mDetectMoves;

  ///[callback] The callback that was used to calculate the diff
  ///[snakes] The list of Myers' snakes
  ///[oldItemStatuses] An List<int> that can be re-purposed to keep metadata
  ///[newItemStatuses] An List<int> that can be re-purposed to keep metadata
  ///[detectMoves] True if this DiffResult will try to detect moved items
  MyersDifferenceResult(this._request, this.mSnakes, this.mOldItemStatuses,
      this.mNewItemStatuses, this.mDetectMoves)
      : this.mOldListSize = _request.oldSize,
        this.mNewListSize = _request.newSize {
    mOldItemStatuses.fillRange(0, mOldItemStatuses.length, 0);
    mNewItemStatuses.fillRange(0, mNewItemStatuses.length, 0);
    addRootSnake();
    findMatchingItems();
  }

  ///We always add a Snake to 0/0 so that we can run loops from end to beginning and be done
  ///when we run out of snakes.
  void addRootSnake() {
    Snake firstSnake = mSnakes.isEmpty ? null : mSnakes[0];
    if (firstSnake == null || firstSnake.x != 0 || firstSnake.y != 0) {
      mSnakes.insert(0, Snake.empty());
    }
  }

  ///This method traverses each addition / removal and tries to match it to a previous
  ///removal / addition. This is how we detect move operations.
  ///This class also flags whether an item has been changed or not.
  ///Implementation does this pre-processing so that if it is running on a big list, it can be moved
  ///to background thread where most of the expensive stuff will be calculated and kept in
  ///the statuses maps. Result uses this pre-calculated information while dispatching
  ///the updates (which is probably being called on the main thread).
  void findMatchingItems() {
    int posOld = mOldListSize;
    int posNew = mNewListSize;
    // traverse the matrix from right bottom to 0,0.
    for (int i = mSnakes.length - 1; i >= 0; i--) {
      final Snake snake = mSnakes[i];
      final int endX = snake.x + snake.size;
      final int endY = snake.y + snake.size;
      if (mDetectMoves) {
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
      for (int j = 0; j < snake.size; j++) {
        // matching items. Check if it is changed or not
        final int oldItemPos = snake.x + j;
        final int newItemPos = snake.y + j;
        final bool theSame = _request.areInstancesEqual(oldItemPos, newItemPos);
        final int changeFlag = theSame ? flag_not_changed : flag_changed;
        mOldItemStatuses[oldItemPos] = (newItemPos << flag_offset) | changeFlag;
        mNewItemStatuses[newItemPos] = (oldItemPos << flag_offset) | changeFlag;
      }
      posOld = snake.x;
      posNew = snake.y;
    }
  }

  void findAddition(int x, int y, int snakeIndex) {
    if (mOldItemStatuses[x - 1] != 0) {
      return; // already set by a latter item
    }
    findMatchingItem(x, y, snakeIndex, false);
  }

  void findRemoval(int x, int y, int snakeIndex) {
    if (mNewItemStatuses[y - 1] != 0) {
      return; // already set by a latter item
    }
    findMatchingItem(x, y, snakeIndex, true);
  }

  ///Given a position in the old list, returns the position in the new list, or
  ///[no_position] if it was removed.
  ///[oldListPosition] is position of item in old list
  ///Returns the position of item in new list, or [no_position] if not present.
  int convertOldPositionToNew(int oldListPosition) {
    if (oldListPosition < 0 || oldListPosition >= mOldItemStatuses.length) {
      throw new RangeError(
          "Index out of bounds - passed position = $oldListPosition, old list "
          "size = ${mOldItemStatuses.length}");
    }
    final int status = mOldItemStatuses[oldListPosition];
    if ((status & flag_mask) == 0) {
      return no_position;
    } else {
      return status >> flag_offset;
    }
  }

  ///Given a position in the new list, returns the position in the old list, or
  ///[no_position] if it was removed.
  ///[newListPosition] - position of item in new list
  ///Returns the position of item in old list, or {@code NO_POSITION} if not present.
  int convertNewPositionToOld(int newListPosition) {
    if (newListPosition < 0 || newListPosition >= mNewItemStatuses.length) {
      throw new RangeError(
          "Index out of bounds - passed position = $newListPosition, new list "
          "size = ${mNewItemStatuses.length}");
    }
    final int status = mNewItemStatuses[newListPosition];
    if ((status & flag_mask) == 0) {
      return no_position;
    } else {
      return status >> flag_offset;
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
      final Snake snake = mSnakes[i];
      final int endX = snake.x + snake.size;
      final int endY = snake.y + snake.size;
      if (removal) {
        // check removals for a match
        for (int pos = curX - 1; pos >= endX; pos--) {
          if (_request.isTheSameConceptualEntity(pos, myItemPos)) {
            // found!
            final bool theSame = _request.areInstancesEqual(pos, myItemPos);
            final int changeFlag =
                theSame ? flag_moved_not_changed : flag_moved_changed;
            mNewItemStatuses[myItemPos] = (pos << flag_offset) | flag_ignore;
            mOldItemStatuses[pos] = (myItemPos << flag_offset) | changeFlag;
            return true;
          }
        }
      } else {
        // check for additions for a match
        for (int pos = curY - 1; pos >= endY; pos--) {
          if (_request.isTheSameConceptualEntity(myItemPos, pos)) {
            // found
            final bool theSame = _request.areInstancesEqual(myItemPos, pos);
            final int changeFlag =
                theSame ? flag_moved_not_changed : flag_moved_changed;
            mOldItemStatuses[x - 1] = (pos << flag_offset) | flag_ignore;
            mNewItemStatuses[pos] = ((x - 1) << flag_offset) | changeFlag;
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
  void dispatchUpdates(DifferenceConsumer updateCallback) {
    final BatchingListUpdateCallback batchingCallback =
        updateCallback.batching();
    // These are add/remove ops that are converted to moves. We track their positions until
    // their respective update operations are processed.
    final List<PostponedUpdate> postponedUpdates = new List();
    int posOld = mOldListSize;
    int posNew = mNewListSize;
    for (int snakeIndex = mSnakes.length - 1; snakeIndex >= 0; snakeIndex--) {
      final Snake snake = mSnakes[snakeIndex];
      final int snakeSize = snake.size;
      final int endX = snake.x + snakeSize;
      final int endY = snake.y + snakeSize;
      if (endX < posOld) {
        dispatchRemovals(
            postponedUpdates, batchingCallback, endX, posOld - endX, endX);
      }

      if (endY < posNew) {
        dispatchAdditions(
            postponedUpdates, batchingCallback, endX, posNew - endY, endY);
      }
      for (int i = snakeSize - 1; i >= 0; i--) {
        if ((mOldItemStatuses[snake.x + i] & flag_mask) == flag_changed) {
          batchingCallback.onChanged(snake.x + i, 1,
              _request.getChangePayload(snake.x + i, snake.y + i));
        }
      }
      posOld = snake.x;
      posNew = snake.y;
    }
    batchingCallback.dispatchLastEvent();
  }

  PostponedUpdate removePostponedUpdate(
      List<PostponedUpdate> updates, int pos, bool removal) {
    for (int i = updates.length - 1; i >= 0; i--) {
      final PostponedUpdate update = updates[i];
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

  void dispatchAdditions(
      List<PostponedUpdate> postponedUpdates,
      DifferenceConsumer updateCallback,
      int start,
      int count,
      int globalIndex) {
    if (!mDetectMoves) {
      updateCallback.onInserted(start, count);
      return;
    }
    for (int i = count - 1; i >= 0; i--) {
      int status = mNewItemStatuses[globalIndex + i] & flag_mask;
      switch (status) {
        case 0: // real addition
          updateCallback.onInserted(start, 1);
          for (PostponedUpdate update in postponedUpdates) {
            update.currentPos += 1;
          }
          break;
        case flag_moved_changed:
        case flag_moved_not_changed:
          final int pos = mNewItemStatuses[globalIndex + i] >> flag_offset;
          final PostponedUpdate update =
              removePostponedUpdate(postponedUpdates, pos, true);
          // the item was moved from that position
          //noinspection ConstantConditions
          updateCallback.onMoved(update.currentPos, start);
          if (status == flag_moved_changed) {
            // also dispatch a change
            updateCallback.onChanged(
                start, 1, _request.getChangePayload(pos, globalIndex + i));
          }
          break;
        case flag_ignore: // ignoring this
          postponedUpdates
              .add(new PostponedUpdate(globalIndex + i, start, false));
          break;
        default:
          throw new StateError("unknown flag for pos ${globalIndex + i} "
              "${status.toRadixString(2)}");
      }
    }
  }

  void dispatchRemovals(
      List<PostponedUpdate> postponedUpdates,
      DifferenceConsumer updateCallback,
      int start,
      int count,
      int globalIndex) {
    if (!mDetectMoves) {
      updateCallback.onRemoved(start, count);
      return;
    }
    for (int i = count - 1; i >= 0; i--) {
      final int status = mOldItemStatuses[globalIndex + i] & flag_mask;
      switch (status) {
        case 0: // real removal
          updateCallback.onRemoved(start + i, 1);
          for (PostponedUpdate update in postponedUpdates) {
            update.currentPos -= 1;
          }
          break;
        case flag_moved_changed:
        case flag_moved_not_changed:
          final int pos = mOldItemStatuses[globalIndex + i] >> flag_offset;
          final PostponedUpdate update =
              removePostponedUpdate(postponedUpdates, pos, false);
          // the item was moved to that position. we do -1 because this is a move not
          // add and removing current item offsets the target move by 1
          //noinspection ConstantConditions
          updateCallback.onMoved(start + i, update.currentPos - 1);
          if (status == flag_moved_changed) {
            // also dispatch a change
            updateCallback.onChanged(update.currentPos - 1, 1,
                _request.getChangePayload(globalIndex + i, pos));
          }
          break;
        case flag_ignore: // ignoring this
          postponedUpdates
              .add(new PostponedUpdate(globalIndex + i, start + i, true));
          break;
        default:
          throw new StateError("unknown flag for pos ${(globalIndex + i)} "
              "${status.toRadixString(2)}");
      }
    }
  }

  List<Snake> getSnakes() {
    return mSnakes;
  }
}

class PostponedUpdate {
  int posInOwnerList = 0;

  int currentPos = 0;

  bool removal = false;

  PostponedUpdate(int posInOwnerList, int currentPos, bool removal) {
    this.posInOwnerList = posInOwnerList;
    this.currentPos = currentPos;
    this.removal = removal;
  }
}
