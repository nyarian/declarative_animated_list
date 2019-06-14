import 'package:declarative_animated_list/src/algorithm/myers/myer.dart';
import 'package:declarative_animated_list/src/algorithm/myers/result.dart';
import 'package:declarative_animated_list/src/reactive_list.dart';
import 'package:mockito/mockito.dart';
import 'package:test_api/test_api.dart';

void main() {
  MockListUpdateCallback callback;

  setUp(() {
    callback = MockListUpdateCallback();
  });

  tearDown(() {
    callback = null;
  });

  test('verify that single onInserted was dispatched with count 1', () {
    final List<int> old = [1, 3];
    final List<int> updated = [1, 2, 3];
    final DiffResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdatesTo(callback);
    verify(callback.onInserted(1, 1));
  });

  test('verify that single onInserted was dispatched with count 2', () {
    final List<int> old = [1, 4];
    final List<int> updated = [1, 2, 3, 4];
    final DiffResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdatesTo(callback);
    verify(callback.onInserted(1, 2));
  });

  test('verify that single onRemoved was dispatched with count 1', () {
    final List<int> old = [1, 2, 3];
    final List<int> updated = [1, 3];
    final DiffResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdatesTo(callback);
    verify(callback.onRemoved(1, 1));
  });

  test('verify that single onRemoved was dispatched with count 2', () {
    final List<int> old = [1, 2, 3, 4];
    final List<int> updated = [1, 4];
    final DiffResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdatesTo(callback);
    verify(callback.onRemoved(1, 2));
  });

  test(
      'verify that single onMoved was dispatched, case 1',
      () {
    final List<int> old = [1, 2, 3];
    final List<int> updated = [1, 3, 2];
    final DiffResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdatesTo(callback);
    verify(callback.onMoved(2, 1));
  });

  test(
      'verify that single onMoved was dispatched case 2',
      () {
    final List<int> old = [1, 2, 3];
    final List<int> updated = [3, 1, 2];
    final DiffResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdatesTo(callback);
    verify(callback.onMoved(2, 0));
  });

  test(
      'verify that single onMoved was dispatched case 3',
      () {
    final List<int> old = [1, 2, 3];
    final List<int> updated = [2, 1, 3];
    final DiffResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdatesTo(callback);
    verify(callback.onMoved(1, 0));
  });

  test(
      'verify that double onMoved was dispatched case 1',
      () {
    final List<int> old = [1, 2, 3, 4];
    final List<int> updated = [2, 1, 4, 3];
    final DiffResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdatesTo(callback);
    verify(callback.onMoved(3, 1));
    verify(callback.onMoved(2, 0));
  });
}

DiffResult calculateWithLists<T>(final List<T> old, final List<T> updated) {
  return MyersDifferenceAlgorithm().calculateDiff(ListsCallback(old, updated));
}

class MockListUpdateCallback extends Mock implements ListUpdateCallback {}
