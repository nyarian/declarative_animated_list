import 'package:declarative_animated_list/src/algorithm/myers/myer.dart';
import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late MockListUpdateCallback callback;

  setUp(() {
    callback = MockListUpdateCallback();
    when(callback.batching).thenReturn(BatchingListUpdateCallback(callback));
  });

  // tearDown(() {
  //   reset(callback);
  // });

  test('verify that single onInserted was dispatched with count 1', () {
    final List<int> old = [1, 3];
    final List<int> updated = [1, 2, 3];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    verify(()=>callback.onInserted(1, 1));
  });

  test('verify that single onInserted was dispatched with count 2', () {
    final List<int> old = [1, 4];
    final List<int> updated = [1, 2, 3, 4];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    verify(()=>callback.onInserted(1, 2));
  });

  test('verify that single onRemoved was dispatched with count 1', () {
    final List<int> old = [1, 2, 3];
    final List<int> updated = [1, 3];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    verify(()=>callback.onRemoved(1, 1));
  });

  test('verify that single onRemoved was dispatched with count 2', () {
    final List<int> old = [1, 2, 3, 4];
    final List<int> updated = [1, 4];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    verify(()=>callback.onRemoved(1, 2));
  });

  test('verify that single onMoved was dispatched, case 1', () {
    final List<int> old = [1, 2, 3];
    final List<int> updated = [1, 3, 2];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    verify(()=>callback.onMoved(2, 1));
  });

  test('verify that single onMoved was dispatched case 2', () {
    final List<int> old = [1, 2, 3];
    final List<int> updated = [3, 1, 2];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    verify(()=>callback.onMoved(2, 0));
  });

  test('verify that single onMoved was dispatched case 3', () {
    final List<int> old = [1, 2, 3];
    final List<int> updated = [2, 1, 3];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    verify(()=>callback.onMoved(1, 0));
  });

  test('verify that double onMoved was dispatched case 1', () {
    final List<int> old = [1, 2, 3, 4];
    final List<int> updated = [2, 1, 4, 3];
    final DifferenceResult diff = calculateWithLists(old, updated);
    diff.dispatchUpdates(callback);
    verify(()=>callback.onMoved(3, 1));
    verify(()=>callback.onMoved(2, 0));
  });
}

DifferenceResult calculateWithLists<T>(
    final List<T> old, final List<T> updated) {
  return MyersDifferenceAlgorithm()
      .differentiate(ListsDifferenceRequest(old, updated));
}

class MockListUpdateCallback extends Mock implements DifferenceConsumer {}
