import 'dart:math';

abstract class DifferenceResult {
  void dispatchUpdates(DifferenceConsumer consumer);
}

abstract class DifferenceConsumer {
  void onInserted(int position, int count);

  void onRemoved(int position, int count);

  void onMoved(int from, int to);

  void onChanged(int position, int count, Object payload);

  BatchingListUpdateCallback batching() => BatchingListUpdateCallback(this);
}

class BatchingListUpdateCallback implements DifferenceConsumer {
  static const int type_none = 0;
  static const int type_add = 1;
  static const int type_remove = 2;
  static const int type_change = 3;
  final DifferenceConsumer mWrapped;
  int mLastEventType = 0;
  int mLastEventPosition = -1;
  int mLastEventCount = -1;
  Object mLastEventPayload;

  BatchingListUpdateCallback(this.mWrapped);

  void dispatchLastEvent() {
    if (this.mLastEventType != 0) {
      switch (this.mLastEventType) {
        case 1:
          this
              .mWrapped
              .onInserted(this.mLastEventPosition, this.mLastEventCount);
          break;
        case 2:
          this
              .mWrapped
              .onRemoved(this.mLastEventPosition, this.mLastEventCount);
          break;
        case 3:
          this.mWrapped.onChanged(this.mLastEventPosition, this.mLastEventCount,
              this.mLastEventPayload);
      }

      this.mLastEventPayload = null;
      this.mLastEventType = 0;
    }
  }

  void onInserted(int position, int count) {
    if (this.mLastEventType == 1 &&
        position >= this.mLastEventPosition &&
        position <= this.mLastEventPosition + this.mLastEventCount) {
      this.mLastEventCount += count;
      this.mLastEventPosition = min(position, this.mLastEventPosition);
    } else {
      this.dispatchLastEvent();
      this.mLastEventPosition = position;
      this.mLastEventCount = count;
      this.mLastEventType = 1;
    }
  }

  void onRemoved(int position, int count) {
    if (this.mLastEventType == 2 &&
        this.mLastEventPosition >= position &&
        this.mLastEventPosition <= position + count) {
      this.mLastEventCount += count;
      this.mLastEventPosition = position;
    } else {
      this.dispatchLastEvent();
      this.mLastEventPosition = position;
      this.mLastEventCount = count;
      this.mLastEventType = 2;
    }
  }

  void onMoved(int fromPosition, int toPosition) {
    this.dispatchLastEvent();
    this.mWrapped.onMoved(fromPosition, toPosition);
  }

  void onChanged(int position, int count, Object payload) {
    if (this.mLastEventType == 3 &&
        position <= this.mLastEventPosition + this.mLastEventCount &&
        position + count >= this.mLastEventPosition &&
        this.mLastEventPayload == payload) {
      int previousEnd = this.mLastEventPosition + this.mLastEventCount;
      this.mLastEventPosition = min(position, this.mLastEventPosition);
      this.mLastEventCount =
          max(previousEnd, position + count) - this.mLastEventPosition;
    } else {
      this.dispatchLastEvent();
      this.mLastEventPosition = position;
      this.mLastEventCount = count;
      this.mLastEventPayload = payload;
      this.mLastEventType = 3;
    }
  }

  @override
  BatchingListUpdateCallback batching() {
    return this;
  }
}
