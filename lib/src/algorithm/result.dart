import 'dart:math';

abstract class DifferenceResult {
  void dispatchUpdates(DifferenceConsumer consumer);
}

abstract class DifferenceConsumer {
  void onInserted(int position, int count);

  void onRemoved(int position, int count);

  void onMoved(int from, int to);

  // ignore: use_to_and_as_if_applicable
  BatchingListUpdateCallback batch() => BatchingListUpdateCallback(this);
}

class BatchingListUpdateCallback implements DifferenceConsumer {
  static const _typeNone = 0;
  static const _typeAdd = 1;
  static const _typeRemove = 2;
  final DifferenceConsumer _delegate;
  var _lastEventType = _typeNone;
  var _lastEventPosition = -1;
  var _lastEventCount = -1;

  BatchingListUpdateCallback(this._delegate);

  void dispatchLastEvent() {
    if (_lastEventType != _typeNone) {
      switch (_lastEventType) {
        case _typeAdd:
          _delegate.onInserted(_lastEventPosition, _lastEventCount);
          break;
        case _typeRemove:
          _delegate.onRemoved(_lastEventPosition, _lastEventCount);
          break;
      }
      _lastEventType = _typeNone;
    }
  }

  @override
  void onInserted(int position, int count) {
    if (_lastEventType == _typeAdd &&
        position >= _lastEventPosition &&
        position <= _lastEventPosition + _lastEventCount) {
      _lastEventCount += count;
      _lastEventPosition = min(position, _lastEventPosition);
    } else {
      dispatchLastEvent();
      _lastEventPosition = position;
      _lastEventCount = count;
      _lastEventType = _typeAdd;
    }
  }

  @override
  void onRemoved(int position, int count) {
    if (_lastEventType == _typeRemove &&
        _lastEventPosition >= position &&
        _lastEventPosition <= position + count) {
      _lastEventCount += count;
      _lastEventPosition = position;
    } else {
      dispatchLastEvent();
      _lastEventPosition = position;
      _lastEventCount = count;
      _lastEventType = _typeRemove;
    }
  }

  @override
  void onMoved(int fromPosition, int toPosition) {
    dispatchLastEvent();
    _delegate.onMoved(fromPosition, toPosition);
  }

  @override
  BatchingListUpdateCallback batch() => this;
}
