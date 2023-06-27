/// Snakes represent a match between two lists. It is optionally prefixed or 
/// post-fixed with an
/// add or remove operation. See the Myers' paper for details.
class Snake {
  /// Position in the old list
  int x;

  /// Position in the new list
  int y;

  /// Number of matches. Might be 0.
  final int size;

  /// If true, this is a removal from the original list followed by
  /// {@code size} matches.
  /// If false, this is an addition from the new list followed by {@code size}
  /// matches.
  final bool removal;

  /// If true, the addition or removal is at the end of the snake.
  /// If false, the addition or removal is at the beginning of the snake.
  final bool reverse;

  Snake(
    this.x,
    this.y,
    this.size, {
    required this.removal,
    required this.reverse,
  });

  Snake.empty() : this(0, 0, 0, removal: false, reverse: false);
}
