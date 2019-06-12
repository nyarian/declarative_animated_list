void compare<T>(final List<T> old, final List<T> updated) {
  final _V v = _V(old.length, updated.length);
  final List<Snake> snakes = List<Snake>();
  final List<_V> vs = List<_V>();
}

void calculateDiff<T>(final List<Snake> snakes, final List<_V> vs, _V v,
    final List<T> old, final List<T> updated) {

}

//void calculateDiff<T>(final List<T> old, final List<T> updated) {
//  for (int d = 0; d <= old.length + updated.length; d++) {
//    for (int k = -d; k <= d; k += 2) {
//      bool down = k == -d || (k != d && v[k - 1] < v[k + 1]);
//    }
//  }
//}

class _V {
  final int n;
  final int m;
  final int max;
  final int delta;
  final List<int> array;

  _V(this.n, this.m)
      : this.delta = 0,
        this.max = n + m < 0 ? 1 : n + m,
        this.array = List(2 * (n + m < 0 ? 1 : n + m) + 1) {
    this[1] = 0;
  }

  int operator [](final int k) => array[k - delta + max];

  void operator []=(final int k, final int value) =>
      array[k - delta + max] = value;

  int getY(final int k) => this[k] - k;
}

class Snake {}
