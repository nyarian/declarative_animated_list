import 'dart:math';

import 'package:declarative_animated_list/src/algorithm/myers/myer.dart';

class DiffResult {
  /**
   * Signifies an item not present in the list.
   */
  static const int no_position = -1;

  /**
   * While reading the flags below, keep in mind that when multiple items move in a list,
   * Myers's may pick any of them as the anchor item and consider that one NOT_CHANGED while
   * picking others as additions and removals. This is completely fine as we later detect
   * all moves.
   * <p>
   * Below, when an item is mentioned to stay in the same "location", it means we won't
   * dispatch a move/add/remove for it, it DOES NOT mean the item is still in the same
   * position.
   */
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

  // The callback that was given to calcualte diff method.
  final Callback mCallback;

  final int mOldListSize;

  final int mNewListSize;

  final bool mDetectMoves;

  /**
   * @param callback        The callback that was used to calculate the diff
   * @param snakes          The list of Myers' snakes
   * @param oldItemStatuses An int[] that can be re-purposed to keep metadata
   * @param newItemStatuses An int[] that can be re-purposed to keep metadata
   * @param detectMoves     True if this DiffResult will try to detect moved items
   */
  DiffResult(this.mCallback, this.mSnakes, this.mOldItemStatuses,
      this.mNewItemStatuses, this.mDetectMoves)
      : this.mOldListSize = mCallback.getOldListSize(),
        this.mNewListSize = mCallback.getNewListSize() {
    mOldItemStatuses.fillRange(0, mOldItemStatuses.length, 0);
    mNewItemStatuses.fillRange(0, mNewItemStatuses.length, 0);
    addRootSnake();
    findMatchingItems();
  }

  /**
   * We always add a Snake to 0/0 so that we can run loops from end to beginning and be done
   * when we run out of snakes.
   */
  void addRootSnake() {
    Snake firstSnake = mSnakes.isEmpty ? null : mSnakes[0];
    if (firstSnake == null || firstSnake.x != 0 || firstSnake.y != 0) {
      Snake root = new Snake();
      root.x = 0;
      root.y = 0;
      root.removal = false;
      root.size = 0;
      root.reverse = false;
      mSnakes.insert(0, root);
    }
  }

  /**
   * This method traverses each addition / removal and tries to match it to a previous
   * removal / addition. This is how we detect move operations.
   * <p>
   * This class also flags whether an item has been changed or not.
   * <p>
   * DiffUtil does this pre-processing so that if it is running on a big list, it can be moved
   * to background thread where most of the expensive stuff will be calculated and kept in
   * the statuses maps. DiffResult uses this pre-calculated information while dispatching
   * the updates (which is probably being called on the main thread).
   */
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
        final bool theSame =
            mCallback.areContentsTheSame(oldItemPos, newItemPos);
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

  /**
   * Given a position in the old list, returns the position in the new list, or
   * {@code NO_POSITION} if it was removed.
   *
   * @param oldListPosition Position of item in old list
   * @return Position of item in new list, or {@code NO_POSITION} if not present.
   * @see #NO_POSITION
   * @see #convertNewPositionToOld(int)
   */
  convertOldPositionToNew(int oldListPosition) {
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

  /**
   * Given a position in the new list, returns the position in the old list, or
   * {@code NO_POSITION} if it was removed.
   *
   * @param newListPosition Position of item in new list
   * @return Position of item in old list, or {@code NO_POSITION} if not present.
   * @see #NO_POSITION
   * @see #convertOldPositionToNew(int)
   */
  convertNewPositionToOld(int newListPosition) {
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

  /**
   * Finds a matching item that is before the given coordinates in the matrix
   * (before : left and above).
   *
   * @param x          The x position in the matrix (position in the old list)
   * @param y          The y position in the matrix (position in the new list)
   * @param snakeIndex The current snake index
   * @param removal    True if we are looking for a removal, false otherwise
   * @return True if such item is found.
   */
  findMatchingItem(
      final int x, final int y, final int snakeIndex, final bool removal) {
    int myItemPos;
    int curX;
    int curY;
    if (removal) {
      myItemPos = y - 1;
      curX = x;
      curY = y - 1;
    } else {
      myItemPos = x - 1;
      curX = x - 1;
      curY = y;
    }
    for (int i = snakeIndex; i >= 0; i--) {
      final Snake snake = mSnakes[i];
      final int endX = snake.x + snake.size;
      final int endY = snake.y + snake.size;
      if (removal) {
        // check removals for a match
        for (int pos = curX - 1; pos >= endX; pos--) {
          if (mCallback.areItemsTheSame(pos, myItemPos)) {
            // found!
            final bool theSame = mCallback.areContentsTheSame(pos, myItemPos);
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
          if (mCallback.areItemsTheSame(myItemPos, pos)) {
            // found
            final bool theSame = mCallback.areContentsTheSame(myItemPos, pos);
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

  /**
   * Dispatches the update events to the given adapter.
   * <p>
   * For example, if you have an {@link RecyclerView.Adapter Adapter}
   * that is backed by a {@link List}, you can swap the list with the new one then call this
   * method to dispatch all updates to the RecyclerView.
   * <pre>
   *     List oldList = mAdapter.getData();
   *     DiffResult result = DiffUtil.calculateDiff(new MyCallback(oldList, newList));
   *     mAdapter.setData(newList);
   *     result.dispatchUpdatesTo(mAdapter);
   * </pre>
   * <p>
   * Note that the RecyclerView requires you to dispatch adapter updates immediately when you
   * change the data (you cannot defer {@code notify*} calls). The usage above adheres to this
   * rule because updates are sent to the adapter right after the backing data is changed,
   * before RecyclerView tries to read it.
   * <p>
   * On the other hand, if you have another
   * {@link RecyclerView.AdapterDataObserver AdapterDataObserver}
   * that tries to process events synchronously, this may confuse that observer because the
   * list is instantly moved to its final state while the adapter updates are dispatched later
   * on, one by one. If you have such an
   * {@link RecyclerView.AdapterDataObserver AdapterDataObserver},
   * you can use
   * {@link #dispatchUpdatesTo(ListUpdateCallback)} to handle each modification
   * manually.
   *
   * @param adapter A RecyclerView adapter which was displaying the old list and will start
   *                displaying the new list.
   * @see AdapterListUpdateCallback
   */
//  void dispatchUpdatesTo(final RecyclerView.Adapter adapter) {
//    dispatchUpdatesTo(new AdapterListUpdateCallback(adapter));
//  }

  /**
   * Dispatches update operations to the given Callback.
   * <p>
   * These updates are atomic such that the first update call affects every update call that
   * comes after it (the same as RecyclerView).
   *
   * @param updateCallback The callback to receive the update operations.
   * @see #dispatchUpdatesTo(RecyclerView.Adapter)
   */
  void dispatchUpdatesTo(ListUpdateCallback updateCallback) {
    BatchingListUpdateCallback batchingCallback;
    if (updateCallback is BatchingListUpdateCallback) {
      batchingCallback = updateCallback;
    } else {
      batchingCallback = new BatchingListUpdateCallback(updateCallback);
      // replace updateCallback with a batching callback and override references to
      // updateCallback so that we don't call it directly by mistake
      //noinspection UnusedAssignment
      updateCallback = batchingCallback;
    }
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
              mCallback.getChangePayload(snake.x + i, snake.y + i));
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
      ListUpdateCallback updateCallback,
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
                start, 1, mCallback.getChangePayload(pos, globalIndex + i));
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
      ListUpdateCallback updateCallback,
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
                mCallback.getChangePayload(globalIndex + i, pos));
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

abstract class ListUpdateCallback {
  void onInserted(int position, int count);

  void onRemoved(int position, int count);

  void onMoved(int from, int to);

  void onChanged(int position, int count, Object payload);
}

class BatchingListUpdateCallback implements ListUpdateCallback {
  static const int type_none = 0;
  static const int type_add = 1;
  static const int type_remove = 2;
  static const int type_change = 3;
  final ListUpdateCallback mWrapped;
  int mLastEventType = 0;
  int mLastEventPosition = -1;
  int mLastEventCount = -1;
  Object mLastEventPayload;

  BatchingListUpdateCallback(this.mWrapped);

  void dispatchLastEvent() {
    if (this.mLastEventType != 0) {
      switch (this.mLastEventType) {
        case 1:
          this
              .mWrapped
              .onInserted(this.mLastEventPosition, this.mLastEventCount);
          break;
        case 2:
          this
              .mWrapped
              .onRemoved(this.mLastEventPosition, this.mLastEventCount);
          break;
        case 3:
          this.mWrapped.onChanged(this.mLastEventPosition, this.mLastEventCount,
              this.mLastEventPayload);
      }

      this.mLastEventPayload = null;
      this.mLastEventType = 0;
    }
  }

  void onInserted(int position, int count) {
    if (this.mLastEventType == 1 &&
        position >= this.mLastEventPosition &&
        position <= this.mLastEventPosition + this.mLastEventCount) {
      this.mLastEventCount += count;
      this.mLastEventPosition = min(position, this.mLastEventPosition);
    } else {
      this.dispatchLastEvent();
      this.mLastEventPosition = position;
      this.mLastEventCount = count;
      this.mLastEventType = 1;
    }
  }

  void onRemoved(int position, int count) {
    if (this.mLastEventType == 2 &&
        this.mLastEventPosition >= position &&
        this.mLastEventPosition <= position + count) {
      this.mLastEventCount += count;
      this.mLastEventPosition = position;
    } else {
      this.dispatchLastEvent();
      this.mLastEventPosition = position;
      this.mLastEventCount = count;
      this.mLastEventType = 2;
    }
  }

  void onMoved(int fromPosition, int toPosition) {
    this.dispatchLastEvent();
    this.mWrapped.onMoved(fromPosition, toPosition);
  }

  void onChanged(int position, int count, Object payload) {
    if (this.mLastEventType == 3 &&
        position <= this.mLastEventPosition + this.mLastEventCount &&
        position + count >= this.mLastEventPosition &&
        this.mLastEventPayload == payload) {
      int previousEnd = this.mLastEventPosition + this.mLastEventCount;
      this.mLastEventPosition = min(position, this.mLastEventPosition);
      this.mLastEventCount =
          max(previousEnd, position + count) - this.mLastEventPosition;
    } else {
      this.dispatchLastEvent();
      this.mLastEventPosition = position;
      this.mLastEventCount = count;
      this.mLastEventPayload = payload;
      this.mLastEventType = 3;
    }
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
