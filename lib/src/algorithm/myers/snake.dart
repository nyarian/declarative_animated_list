class Snake {
  int x;
  int y;
  final int size;
  final bool removal;
  final bool reverse;

  Snake(this.x, this.y, this.size, this.removal, this.reverse);

  Snake.empty() : this(0, 0, 0, false, false);

}

final Comparator<Snake> snakeComparator =
    (final Snake left, final Snake right) {
  final int cmpX = left.x - right.x;
  return cmpX == 0 ? left.y - right.y : cmpX;
};
