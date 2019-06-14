import 'package:declarative_animated_list/src/algorithm/myers/result.dart';
import 'package:declarative_animated_list/src/algorithm/myers/snake.dart';

class MyersDifferenceAlgorithm {
  final Comparator<Snake> snakeComparator = (o1, o2) {
    int cmpX = o1.x - o2.x;
    return cmpX == 0 ? o1.y - o2.y : cmpX;
  };

// Myers' algorithm uses two lists as axis labels. In algorithm implementation's implementation, `x` axis is
// used for old list and `y` axis is used for new list.

  ///Calculates the list of update operations that can covert one list into the other one.
  ///[cb] The callback that acts as a gateway to the backing list data
  ///A Result that contains the information about the edit sequence to convert the
  ///old list into the new list.
  DiffResult calculateDiff(Callback cb) {
    return calculateDifference(cb, true);
  }

  ///Calculates the list of update operations that can covert one list into the other one.
  ///If your old and new lists are sorted by the same constraint and items never move (swap
  ///positions), you can disable move detection which takes O(N^2) time where
  ///N is the number of added, moved, removed items.
  ///[cb] The callback that acts as a gateway to the backing list data
  ///[detectMoves] True if algorithm implementation should try to detect moved items, false otherwise.
  ///Returns a [Result] that contains the information about the edit sequence to convert the
  ///old list into the new list.
  DiffResult calculateDifference(Callback cb, bool detectMoves) {
    final int oldSize = cb.getOldListSize();
    final int newSize = cb.getNewListSize();

    final List<Snake> snakes = new List();

    // instead of a recursive implementation, we keep our own stack to avoid potential stack
    // overflow exceptions
    final List<Range> stack = new List();

    stack.add(new Range(0, oldSize, 0, newSize));

    final int max = oldSize + newSize + (oldSize - newSize).abs();
    // allocate forward and backward k-lines. K lines are diagonal lines in the matrix. (see the
    // paper for details)
    // These arrays lines keep the max reachable position for each k-line.
    final List<int> forward = new List(max * 2);
    final List<int> backward = new List(max * 2);

    // We pool the ranges to avoid allocations for each recursive call.
    final List<Range> rangePool = new List();
    while (stack.isNotEmpty) {
      final Range range = stack.removeAt(stack.length - 1);
      final Snake snake = diffPartial(cb, range.oldListStart, range.oldListEnd,
          range.newListStart, range.newListEnd, forward, backward, max);
      if (snake != null) {
        if (snake.size > 0) {
          snakes.add(snake);
        }
        // offset the snake to convert its coordinates from the Range's area to global
        snake.x += range.oldListStart;
        snake.y += range.newListStart;

        // add new ranges for left and right
        final Range left = rangePool.isEmpty
            ? new Range.empty()
            : rangePool.removeAt(rangePool.length - 1);
        left.oldListStart = range.oldListStart;
        left.newListStart = range.newListStart;
        if (snake.reverse) {
          left.oldListEnd = snake.x;
          left.newListEnd = snake.y;
        } else {
          if (snake.removal) {
            left.oldListEnd = snake.x - 1;
            left.newListEnd = snake.y;
          } else {
            left.oldListEnd = snake.x;
            left.newListEnd = snake.y - 1;
          }
        }
        stack.add(left);

        // re-use range for right
        //noinspection UnnecessaryLocalVariable
        final Range right = range;
        if (snake.reverse) {
          if (snake.removal) {
            right.oldListStart = snake.x + snake.size + 1;
            right.newListStart = snake.y + snake.size;
          } else {
            right.oldListStart = snake.x + snake.size;
            right.newListStart = snake.y + snake.size + 1;
          }
        } else {
          right.oldListStart = snake.x + snake.size;
          right.newListStart = snake.y + snake.size;
        }
        stack.add(right);
      } else {
        rangePool.add(range);
      }
    }
    snakes.sort(snakeComparator);
    return new DiffResult(cb, snakes, forward, backward, detectMoves);
  }

  Snake diffPartial(Callback cb, int startOld, int endOld, int startNew,
      int endNew, List<int> forward, List<int> backward, int kOffset) {
    final int oldSize = endOld - startOld;
    final int newSize = endNew - startNew;

    if (endOld - startOld < 1 || endNew - startNew < 1) {
      return null;
    }

    final int delta = oldSize - newSize;
    final int dLimit = (oldSize + newSize + 1) ~/ 2;
    backward.fillRange(
        kOffset - dLimit - 1 + delta, kOffset + dLimit + 1 + delta, oldSize);
    forward.fillRange(kOffset - dLimit - 1, kOffset + dLimit + 1, 0);
    final bool checkInFwd = delta % 2 != 0;
    for (int d = 0; d <= dLimit; d++) {
      for (int k = -d; k <= d; k += 2) {
// find forward path
// we can reach k from k - 1 or k + 1. Check which one is further in the graph
        int x;
        bool removal;
        if (k == -d ||
            (k != d && forward[kOffset + k - 1] < forward[kOffset + k + 1])) {
          x = forward[kOffset + k + 1];
          removal = false;
        } else {
          x = forward[kOffset + k - 1] + 1;
          removal = true;
        }
// set y based on x
        int y = x - k;
// move diagonal as long as items match
        while (x < oldSize &&
            y < newSize &&
            cb.areItemsTheSame(startOld + x, startNew + y)) {
          x++;
          y++;
        }
        forward[kOffset + k] = x;
        if (checkInFwd &&
            k >= delta - d + 1 &&
            k <= delta + d - 1 &&
            forward[kOffset + k] >= backward[kOffset + k]) {
          final int snakeX = backward[kOffset + k];
          return Snake(snakeX, snakeX - k, forward[kOffset + k] - snakeX,
              removal, false);
        }
      }
      for (int k = -d; k <= d; k += 2) {
// find reverse path at k + delta, in reverse
        final int backwardK = k + delta;
        int x;
        bool removal;
        if (backwardK == d + delta ||
            (backwardK != -d + delta &&
                backward[kOffset + backwardK - 1] <
                    backward[kOffset + backwardK + 1])) {
          x = backward[kOffset + backwardK - 1];
          removal = false;
        } else {
          x = backward[kOffset + backwardK + 1] - 1;
          removal = true;
        }

// set y based on x
        int y = x - backwardK;
// move diagonal as long as items match
        while (x > 0 &&
            y > 0 &&
            cb.areItemsTheSame(startOld + x - 1, startNew + y - 1)) {
          x--;
          y--;
        }
        backward[kOffset + backwardK] = x;
        if (!checkInFwd &&
            k + delta >= -d &&
            k + delta <= d &&
            forward[kOffset + backwardK] >= backward[kOffset + backwardK]) {
          final int snakeX = backward[kOffset + backwardK];
          return Snake(snakeX, snakeX - backwardK,
              forward[kOffset + backwardK] - snakeX, removal, true);
        }
      }
    }
    throw new StateError(
        "algorithm implementation hit an unexpected case while trying to calculate" +
            " the optimal path. Please make sure your data is not changing during the" +
            " diff calculation.");
  }
}

///A Callback class used by algorithm implementation while calculating the
///difference between two lists.
abstract class Callback {
  ///Returns the size of the old list.
  int getOldListSize();

  ///Returns the size of the new list.
  int getNewListSize();

  ///Called by the algorithm implementation to decide whether two object represent the same item.
  ///For example, if your items have unique ids, this method should check their id equality.
  ///[oldItemPosition] The position of the item in the old list
  ///[newItemPosition] The position of the item in the new list
  ///Returns true if the two items represent the same object or false if they are different.
  bool areItemsTheSame(int oldItemPosition, int newItemPosition);

  ///Called by the algorithm implementation when it wants to check whether two items have the same data.
  ///Algorithm implementation uses this information to detect if the contents of an item has changed.
  ///Algorithm implementation uses this method to check equality instead of [==]
  ///so that you can change its behavior depending on your UI.
  ///This method is called only if [areItemsTheSame] returns true for these items.
  ///[oldItemPosition] - the position of the item in the old list
  ///[newItemPosition] - the position of the item in the new list which replaces the oldItem
  ///@return True if the contents of the items are the same or false if they are different.
  bool areContentsTheSame(int oldItemPosition, int newItemPosition);

  ///
  ///When [areItemsTheSame] returns true for two items and
  ///[areContentsTheSame] returns false for them, algorithm implementation
  ///calls this method to get a payload about the change.
  ///Default implementation returns null
  ///[oldItemPosition] The position of the item in the old list
  ///[newItemPosition] The position of the item in the new list
  ///Returns A payload object that represents the change between the two items.
  getChangePayload(int oldItemPosition, int newItemPosition) {
    return null;
  }
}

///Represents a range in two lists that needs to be solved.
///This internal class is used when running Myers' algorithm without recursion.
class Range {
  int oldListStart = 0, oldListEnd = 0;

  int newListStart = 0, newListEnd = 0;

  Range.empty() : this(0, 0, 0, 0);

  Range(int oldListStart, int oldListEnd, int newListStart, int newListEnd) {
    this.oldListStart = oldListStart;
    this.oldListEnd = oldListEnd;
    this.newListStart = newListStart;
    this.newListEnd = newListEnd;
  }
}

///Represents an update that we skipped because it was a move.
///When an update is skipped, it is tracked as other updates are dispatched until the matching
///add/remove operation is found at which point the tracked position is used to dispatch the
///update.
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
