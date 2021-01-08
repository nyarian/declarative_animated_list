import 'package:declarative_animated_list/src/algorithm/myers/myer.dart';
import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockListUpdateCallback callback;

  setUp(() => callback = MockListUpdateCallback());

  test('verify that single onInserted was dispatched with count 1', () {
    final List<int> old = [1, 3];
    final List<int> updated = [1, 2, 3];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    expect(callback.wasInserted(position: 1, count: 1), isTrue);
  });

  test('verify that single onInserted was dispatched with count 2', () {
    final List<int> old = [1, 4];
    final List<int> updated = [1, 2, 3, 4];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    expect(callback.wasInserted(position: 1, count: 2), isTrue);
  });

  test('verify that single onRemoved was dispatched with count 1', () {
    final List<int> old = [1, 2, 3];
    final List<int> updated = [1, 3];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    expect(callback.wasRemoved(position: 1, count: 1), isTrue);
  });

  test('verify that single onRemoved was dispatched with count 2', () {
    final List<int> old = [1, 2, 3, 4];
    final List<int> updated = [1, 4];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    expect(callback.wasRemoved(position: 1, count: 2), isTrue);
  });

  test('verify that single onMoved was dispatched, case 1', () {
    final List<int> old = [1, 2, 3];
    final List<int> updated = [1, 3, 2];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    expect(callback.wasMoved(from: 2, to: 1), isTrue);
  });

  test('verify that single onMoved was dispatched case 2', () {
    final List<int> old = [1, 2, 3];
    final List<int> updated = [3, 1, 2];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    expect(callback.wasMoved(from: 2, to: 0), isTrue);
  });

  test('verify that single onMoved was dispatched case 3', () {
    final List<int> old = [1, 2, 3];
    final List<int> updated = [2, 1, 3];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    expect(callback.wasMoved(from: 1, to: 0), isTrue);
  });

  test('verify that double onMoved was dispatched case 1', () {
    final List<int> old = [1, 2, 3, 4];
    final List<int> updated = [2, 1, 4, 3];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    expect(callback.wasMoved(from: 3, to: 1), isTrue);
    expect(callback.wasMoved(from: 2, to: 0), isTrue);
  });
}

DifferenceResult calculateWithLists<T extends Object>(
    final List<T> old, final List<T> updated) {
  return MyersDifferenceAlgorithm()
      .differentiate(ListsDifferenceRequest(old, updated));
}

class MockListUpdateCallback<T extends Object> implements DifferenceConsumer {
  @override
  BatchingListUpdateCallback batching() => BatchingListUpdateCallback(this);

  @override
  void onInserted(int position, int count) => _inserts[position] = count;

  @override
  void onMoved(int from, int to) => _moves[from] = to;

  @override
  void onRemoved(int position, int count) => _removes[position] = count;

  bool wasInserted({required int position, required int count}) =>
      _inserts[position] == count;

  bool wasRemoved({required int position, required int count}) =>
      _removes[position] == count;

  bool wasMoved({required int from, required int to}) => _moves[from] == to;

  final Map<int, int> _inserts = {};
  final Map<int, int> _removes = {};
  final Map<int, int> _moves = {};
}
