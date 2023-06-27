import 'package:declarative_animated_list/src/algorithm/myers/myer.dart';
import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeListUpdateCallback callback;

  setUp(() => callback = FakeListUpdateCallback());

  test('verify that single onInserted was dispatched with count 1', () {
    final old = [1, 3];
    final updated = [1, 2, 3];
    calculateWithLists(old, updated).dispatchUpdates(callback);
    expect(callback.wasInserted(position: 1, count: 1), isTrue);
  });

  test('verify that single onInserted was dispatched with count 2', () {
    final old = [1, 4];
    final updated = [1, 2, 3, 4];
    calculateWithLists(old, updated).dispatchUpdates(callback);
    expect(callback.wasInserted(position: 1, count: 2), isTrue);
  });

  test('verify that single onRemoved was dispatched with count 1', () {
    final old = [1, 2, 3];
    final updated = [1, 3];
    calculateWithLists(old, updated).dispatchUpdates(callback);
    expect(callback.wasRemoved(position: 1, count: 1), isTrue);
  });

  test('verify that single onRemoved was dispatched with count 2', () {
    final old = [1, 2, 3, 4];
    final updated = [1, 4];
    calculateWithLists(old, updated).dispatchUpdates(callback);
    expect(callback.wasRemoved(position: 1, count: 2), isTrue);
  });

  test('verify that single onRemoved was dispatched with count 4', () {
    final old = [1, 2, 3, 4];
    final updated = <int>[];
    calculateWithLists(old, updated).dispatchUpdates(callback);
    expect(callback.wasRemoved(position: 0, count: 4), isTrue);
  });

  test('verify that single onMoved was dispatched, case 1', () {
    final old = [1, 2, 3];
    final updated = [1, 3, 2];
    calculateWithLists(old, updated).dispatchUpdates(callback);
    expect(callback.wasMoved(from: 2, to: 1), isTrue);
  });

  test('verify that single onMoved was dispatched case 2', () {
    final old = [1, 2, 3];
    final updated = [3, 1, 2];
    calculateWithLists(old, updated).dispatchUpdates(callback);
    expect(callback.wasMoved(from: 2, to: 0), isTrue);
  });

  test('verify that single onMoved was dispatched case 3', () {
    final old = [1, 2, 3];
    final updated = [2, 1, 3];
    calculateWithLists(old, updated).dispatchUpdates(callback);
    expect(callback.wasMoved(from: 1, to: 0), isTrue);
  });

  test('verify that double onMoved was dispatched case 1', () {
    final old = [1, 2, 3, 4];
    final updated = [2, 1, 4, 3];
    calculateWithLists(old, updated).dispatchUpdates(callback);
    expect(callback.wasMoved(from: 3, to: 1), isTrue);
    expect(callback.wasMoved(from: 2, to: 0), isTrue);
  });
}

DifferenceResult calculateWithLists<T extends Object>(
  List<T> old,
  List<T> updated,
) {
  return MyersDifferenceAlgorithm()
      .differentiate(ListsDifferenceRequest(old, updated));
}

class FakeListUpdateCallback<T extends Object> implements DifferenceConsumer {
  @override
  // ignore: use_to_and_as_if_applicable
  BatchingListUpdateCallback batch() => BatchingListUpdateCallback(this);

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
