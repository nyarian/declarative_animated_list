import 'dart:math';

abstract class DifferenceResult {
  void dispatchUpdates(DifferenceConsumer consumer);
}

abstract class DifferenceConsumer {
  void onInserted(int position, int count);

  void onRemoved(int position, int count);

  void onMoved(int from, int to);

  BatchingListUpdateCallback batching() => BatchingListUpdateCallback(this);
}

class BatchingListUpdateCallback implements DifferenceConsumer {
  static const int type_none = 0;
  static const int type_add = 1;
  static const int type_remove = 2;
  final DifferenceConsumer mWrapped;
  int mLastEventType = type_none;
  int mLastEventPosition = -1;
  int mLastEventCount = -1;
  Object mLastEventPayload;

  BatchingListUpdateCallback(this.mWrapped);

  void dispatchLastEvent() {
    if (this.mLastEventType != type_none) {
      switch (this.mLastEventType) {
        case type_add:
          this
              .mWrapped
              .onInserted(this.mLastEventPosition, this.mLastEventCount);
          break;
        case type_remove:
          this
              .mWrapped
              .onRemoved(this.mLastEventPosition, this.mLastEventCount);
          break;
      }

      this.mLastEventPayload = null;
      this.mLastEventType = type_none;
    }
  }

  void onInserted(int position, int count) {
    if (this.mLastEventType == type_add &&
        position >= this.mLastEventPosition &&
        position <= this.mLastEventPosition + this.mLastEventCount) {
      this.mLastEventCount += count;
      this.mLastEventPosition = min(position, this.mLastEventPosition);
    } else {
      this.dispatchLastEvent();
      this.mLastEventPosition = position;
      this.mLastEventCount = count;
      this.mLastEventType = type_add;
    }
  }

  void onRemoved(int position, int count) {
    if (this.mLastEventType == type_remove &&
        this.mLastEventPosition >= position &&
        this.mLastEventPosition <= position + count) {
      this.mLastEventCount += count;
      this.mLastEventPosition = position;
    } else {
      this.dispatchLastEvent();
      this.mLastEventPosition = position;
      this.mLastEventCount = count;
      this.mLastEventType = type_remove;
    }
  }

  void onMoved(int fromPosition, int toPosition) {
    this.dispatchLastEvent();
    this.mWrapped.onMoved(fromPosition, toPosition);
  }


  @override
  BatchingListUpdateCallback batching() => this;
}
