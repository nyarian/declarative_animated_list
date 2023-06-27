import 'package:declarative_animated_list/src/algorithm/myers/result.dart';
import 'package:declarative_animated_list/src/algorithm/myers/snake.dart';
import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';
import 'package:declarative_animated_list/src/algorithm/strategy.dart';

// Myers' algorithm uses two lists as axis labels. In algorithm's
// implementation, `x` axis is used for old list and `y` axis is used for the
// new list.
class MyersDifferenceAlgorithm implements DifferentiatingStrategy {
  /// Calculates the list of update operations that can covert one list into the
  /// other one.
  /// A Result that contains the information about the edit sequence to convert
  /// the old list into the new list.
  @override
  DifferenceResult differentiate(final DifferenceRequest request) {
    return _calculateDifference(request, true);
  }

  /// Calculates the list of update operations that can covert one list into
  /// the other one.
  /// If your old and new lists are sorted by the same constraint and items
  /// never move (swap positions), you can disable move detection which takes
  /// O(N^2) time where N is the number of added, moved, removed items.
  /// [detectMoves] True if algorithm implementation should try to detect moved
  /// items, false otherwise.
  /// Returns a [DifferenceResult] that contains the information about the edit
  /// sequence to convert the old list into the new list.
  DifferenceResult _calculateDifference(
    DifferenceRequest request,
    bool detectMoves,
  ) {
    final oldSize = request.oldSize;
    final newSize = request.newSize;

    final snakes = <Snake>[];

    // instead of a recursive implementation, we keep our own stack to avoid
    // potential stack overflow exceptions
    final stack = <Range>[
      Range(
        oldListStart: 0,
        oldListEnd: oldSize,
        newListStart: 0,
        newListEnd: newSize,
      ),
    ];

    final max = oldSize + newSize + (oldSize - newSize).abs();
    // allocate forward and backward k-lines. K lines are diagonal lines in the
    // matrix. (see the paper for details)
    // These arrays lines keep the max reachable position for each k-line.
    final forward = List<int>.generate(max * 2, (_) => 0);
    final backward = List<int>.generate(max * 2, (_) => 0);

    // We pool the ranges to avoid allocations for each recursive call.
    final rangePool = <Range>[];
    while (stack.isNotEmpty) {
      final range = stack.removeAt(stack.length - 1);
      final snake = _diffPartial(
        request,
        range.oldListStart,
        range.oldListEnd,
        range.newListStart,
        range.newListEnd,
        forward,
        backward,
        max,
      );
      if (snake != null) {
        if (snake.size > 0) snakes.add(snake);

        // offset the snake to convert its coordinates from the Range's area to
        // global
        snake
          ..x += range.oldListStart
          ..y += range.newListStart;

        // add new ranges for left and right
        final left = (rangePool.isEmpty
            ? Range.empty()
            : rangePool.removeAt(rangePool.length - 1))
          ..oldListStart = range.oldListStart
          ..newListStart = range.newListStart;
        if (snake.reverse) {
          left
            ..oldListEnd = snake.x
            ..newListEnd = snake.y;
        } else {
          if (snake.removal) {
            left
              ..oldListEnd = snake.x - 1
              ..newListEnd = snake.y;
          } else {
            left
              ..oldListEnd = snake.x
              ..newListEnd = snake.y - 1;
          }
        }
        stack.add(left);

        // re-use range for right
        //noinspection UnnecessaryLocalVariable
        final right = range;
        if (snake.reverse) {
          if (snake.removal) {
            right
              ..oldListStart = snake.x + snake.size + 1
              ..newListStart = snake.y + snake.size;
          } else {
            right
              ..oldListStart = snake.x + snake.size
              ..newListStart = snake.y + snake.size + 1;
          }
        } else {
          right
            ..oldListStart = snake.x + snake.size
            ..newListStart = snake.y + snake.size;
        }
        stack.add(right);
      } else {
        rangePool.add(range);
      }
    }
    snakes.sort(
      (o1, o2) {
        int cmpX = o1.x - o2.x;
        return cmpX == 0 ? o1.y - o2.y : cmpX;
      },
    );
    return MyersDifferenceResult(
      request,
      snakes,
      forward,
      backward,
      detectMoves: detectMoves,
    );
  }

  Snake? _diffPartial(
    DifferenceRequest request,
    int startOld,
    int endOld,
    int startNew,
    int endNew,
    List<int> forward,
    List<int> backward,
    int offset,
  ) {
    final oldSize = endOld - startOld;
    final newSize = endNew - startNew;
    if (endOld - startOld < 1 || endNew - startNew < 1) return null;
    final delta = oldSize - newSize;
    final dLimit = (oldSize + newSize + 1) ~/ 2;
    backward.fillRange(
      offset - dLimit - 1 + delta,
      offset + dLimit + 1 + delta,
      oldSize,
    );
    forward.fillRange(offset - dLimit - 1, offset + dLimit + 1, 0);
    final checkInFwd = delta % 2 != 0;
    for (int d = 0; d <= dLimit; d++) {
      for (int k = -d; k <= d; k += 2) {
// find forward path
// we can reach k from k - 1 or k + 1. Check which one is further in the graph
        int x;
        bool removal;
        if (k == -d ||
            (k != d && forward[offset + k - 1] < forward[offset + k + 1])) {
          x = forward[offset + k + 1];
          removal = false;
        } else {
          x = forward[offset + k - 1] + 1;
          removal = true;
        }
// set y based on x
        var y = x - k;
// move diagonal as long as items match
        while (x < oldSize &&
            y < newSize &&
            request.areEqual(startOld + x, startNew + y)) {
          x++;
          y++;
        }
        forward[offset + k] = x;
        if (checkInFwd &&
            k >= delta - d + 1 &&
            k <= delta + d - 1 &&
            forward[offset + k] >= backward[offset + k]) {
          final snakeX = backward[offset + k];
          return Snake(
            snakeX,
            snakeX - k,
            forward[offset + k] - snakeX,
            removal: removal,
            reverse: false,
          );
        }
      }
      for (int k = -d; k <= d; k += 2) {
        // find reverse path at k + delta, in reverse
        final backwardK = k + delta;
        int x;
        bool removal;
        if (backwardK == d + delta ||
            (backwardK != -d + delta &&
                backward[offset + backwardK - 1] <
                    backward[offset + backwardK + 1])) {
          x = backward[offset + backwardK - 1];
          removal = false;
        } else {
          x = backward[offset + backwardK + 1] - 1;
          removal = true;
        }

// set y based on x
        var y = x - backwardK;
// move diagonal as long as items match
        while (x > 0 &&
            y > 0 &&
            request.areEqual(startOld + x - 1, startNew + y - 1)) {
          x--;
          y--;
        }
        backward[offset + backwardK] = x;
        if (!checkInFwd &&
            k + delta >= -d &&
            k + delta <= d &&
            forward[offset + backwardK] >= backward[offset + backwardK]) {
          final snakeX = backward[offset + backwardK];
          return Snake(
            snakeX,
            snakeX - backwardK,
            forward[offset + backwardK] - snakeX,
            removal: removal,
            reverse: true,
          );
        }
      }
    }
    throw StateError(
      'Algorithm implementation hit an unexpected case while trying to '
      'calculate the optimal path. Please make sure your data is not changing '
      'during the diff calculation.',
    );
  }
}

/// Represents a range in two lists that needs to be solved.
/// This internal class is used when running Myers' algorithm without recursion.
class Range {
  int oldListStart;
  int oldListEnd;
  int newListStart;
  int newListEnd;

  Range({
    required this.oldListStart,
    required this.oldListEnd,
    required this.newListStart,
    required this.newListEnd,
  });

  Range.empty()
      : this(oldListStart: 0, oldListEnd: 0, newListStart: 0, newListEnd: 0);
}
