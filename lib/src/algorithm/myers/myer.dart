import 'package:reactive_list/src/algorithm/myers/result.dart';
import 'package:reactive_list/src/algorithm/myers/snake.dart';
import 'package:reactive_list/src/algorithm/request.dart';
import 'package:reactive_list/src/algorithm/result.dart';
import 'package:reactive_list/src/algorithm/strategy.dart';

class MyersDifferenceAlgorithm implements DifferentiatingStrategy {
  @override
  DifferenceResult differentiate(final DifferenceRequest request) {
    final int oldSize = request.oldSize;
    final int newSize = request.newSize;
    final List<Snake> snakes = List<Snake>();
    final List<_Range> stack = List<_Range>();
    stack.add(_Range(0, oldSize, 0, newSize));
    final int max = oldSize + newSize + (oldSize - newSize).abs();
    final List<int> forward = List<int>(max * 2);
    final List<int> backward = List<int>(max * 2);
    final List<_Range> rangePool = List<_Range>();
    while (stack.isNotEmpty) {
      final _Range range = stack.removeLast();
      final Snake snake = _differentiatePartially(
          request,
          range.oldListStart,
          range.oldListEnd,
          range.newListStart,
          range.newListEnd,
          forward,
          backward,
          max);
      if (snake != null) {
        if (snake.size > 0) {
          snakes.add(snake);
        }
        snake.x += range.oldListStart;
        snake.y += range.newListStart;
        final _Range left =
            rangePool.isEmpty ? _Range.empty() : rangePool.removeLast();
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

        final _Range right = range;
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
    return MyersDifferenceResult(request, snakes, forward, backward, true);
  }

  Snake _differentiatePartially(
      final DifferenceRequest request,
      final int oldListStartIndex,
      final int oldListEndIndex,
      final int newListStartIndex,
      final int newListEndIndex,
      final List<int> forward,
      final List<int> backward,
      final int offset) {
    final int oldSize = oldListEndIndex - oldListStartIndex;
    final int newSize = newListEndIndex - newListStartIndex;

    if (oldSize < 1 || newSize < 1) {
      return null;
    }

    final int delta = oldSize - newSize;
    final int dLimit = (oldSize + newSize + 1) ~/ 2;

    forward.fillRange(offset - dLimit - 1, offset + dLimit + 1, 0);
    backward.fillRange(offset - dLimit - 1, offset + dLimit + 1, oldSize);

    final bool checkInFwd = delta % 2 != 0;
    for (int d = 0; d <= dLimit; d++) {
      //Forward
      for (int k = -d; k <= d; k += 2) {
        final bool isRemoveTurn = !(k == -d ||
            (k != d && forward[offset + k - 1] < forward[offset + k + 1]));
        int x = isRemoveTurn
            ? forward[offset + k - 1] + 1
            : forward[offset + k + 1];
        int y = x - k;
        while (x < oldSize &&
            y < newSize &&
            request.isTheSameConceptualEntity(
                oldListStartIndex + x, newListStartIndex + y)) {
          x++;
          y++;
        }
        forward[offset + k] = x;
        if (checkInFwd &&
            k >= delta - d + 1 &&
            k <= delta + d - 1 &&
            forward[offset + k] >= backward[offset + k]) {
          final int snakeX = backward[offset + k];
          return Snake(snakeX, snakeX - k, forward[offset + k] - snakeX,
              isRemoveTurn, false);
        }
      }

      //Backward
      for (int k = -d; k <= d; k += 2) {
        final int backwardK = k + delta;
        final bool isRemoveTurn = !(backwardK == d + delta ||
            (backwardK != -d + delta &&
                backward[offset + backwardK - 1] <
                    backward[offset + backwardK + 1]));
        int x = isRemoveTurn
            ? backward[offset + backwardK + 1] - 1
            : backward[offset + backwardK - 1];
        int y = x - backwardK;
        while (x > 0 &&
            y > 0 &&
            request.isTheSameConceptualEntity(
                oldListStartIndex + x - 1, newListStartIndex + y - 1)) {
          x--;
          y--;
        }
        backward[offset + backwardK] = x;
        if (!checkInFwd &&
            k + delta >= -d &&
            k + delta <= d &&
            forward[offset + backwardK] >= backward[offset + backwardK]) {
          final int snakeX = backward[offset + backwardK];
          return Snake(snakeX, snakeX - backwardK,
              forward[offset + backwardK] - snakeX, isRemoveTurn, true);
        }
      }
    }
    throw StateError(
        "Myers diff algorithm implementation hit an unexpected case while "
        "trying to calculate the optimal path. Please make sure your data "
        "is not changing during the diff calculation.");
  }
}

class _Range {
  int oldListStart;
  int oldListEnd;
  int newListStart;
  int newListEnd;

  _Range(
      this.oldListStart, this.oldListEnd, this.newListStart, this.newListEnd);

  _Range.empty() : this(0, 0, 0, 0);
}
