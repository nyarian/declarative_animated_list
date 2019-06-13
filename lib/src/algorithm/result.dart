import 'dart:math';

abstract class DifferenceResult {
  void dispatchUpdates(DifferenceResultConsumer consumer);
}

abstract class DifferenceResultConsumer {
  void onInsert(final int position, final int count);

  void onRemove(final int position, final int count);

  void onMove(final int oldPosition, final int newPosition);

  void onChange(final int position, final int count, final Object payload);

  BatchedListUpdateConsumer batched() => BatchedListUpdateConsumer(this);
}

class BatchedListUpdateConsumer implements DifferenceResultConsumer {
  static const int type_none = 0;
  static const int type_add = 1;
  static const int type_remove = 2;
  static const int type_change = 3;
  final DifferenceResultConsumer _delegate;
  int _lastEventType = 0;
  int _lastEventPosition = -1;
  int _lastEventCount = -1;
  Object _lastEventPayload;

  BatchedListUpdateConsumer(this._delegate);

  @override
  void onInsert(final int position, final int count) {
    if (this._lastEventType == 1 &&
        position >= this._lastEventPosition &&
        position <= this._lastEventPosition + this._lastEventCount) {
      this._lastEventCount += count;
      this._lastEventPosition = min(position, this._lastEventPosition);
    } else {
      this.dispatchLastEvent();
      this._lastEventPosition = position;
      this._lastEventCount = count;
      this._lastEventType = 1;
    }
  }

  @override
  void onRemove(final int position, final int count) {
    if (this._lastEventType == 2 &&
        this._lastEventPosition >= position &&
        this._lastEventPosition <= position + count) {
      this._lastEventCount += count;
      this._lastEventPosition = position;
    } else {
      this.dispatchLastEvent();
      this._lastEventPosition = position;
      this._lastEventCount = count;
      this._lastEventType = 2;
    }
  }

  @override
  void onMove(final int oldPosition, final int newPosition) {
    this.dispatchLastEvent();
    this._delegate.onMove(oldPosition, newPosition);
  }

  @override
  void onChange(final int position, final int count, final Object payload) {
    if (this._lastEventType == 3 &&
        position <= this._lastEventPosition + this._lastEventCount &&
        position + count >= this._lastEventPosition &&
        this._lastEventPayload == payload) {
      int previousEnd = this._lastEventPosition + this._lastEventCount;
      this._lastEventPosition = min(position, this._lastEventPosition);
      this._lastEventCount =
          max(previousEnd, position + count) - this._lastEventPosition;
    } else {
      this.dispatchLastEvent();
      this._lastEventPosition = position;
      this._lastEventCount = count;
      this._lastEventPayload = payload;
      this._lastEventType = 3;
    }
  }

  void dispatchLastEvent() {
    if (this._lastEventType != 0) {
      switch (this._lastEventType) {
        case type_add:
          this
              ._delegate
              .onInsert(this._lastEventPosition, this._lastEventCount);
          break;
        case type_remove:
          this
              ._delegate
              .onRemove(this._lastEventPosition, this._lastEventCount);
          break;
        case type_change:
          this._delegate.onChange(this._lastEventPosition, this._lastEventCount,
              this._lastEventPayload);
      }

      this._lastEventPayload = null;
      this._lastEventType = 0;
    }
  }

  @override
  BatchedListUpdateConsumer batched() {
    return this;
  }
}
