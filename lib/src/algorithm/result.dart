//  Copyright 2019 nyarian
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

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
  final DifferenceConsumer _delegate;
  int _lastEventType = type_none;
  int _lastEventPosition = -1;
  int _lastEventCount = -1;

  BatchingListUpdateCallback(this._delegate);

  void dispatchLastEvent() {
    if (this._lastEventType != type_none) {
      switch (this._lastEventType) {
        case type_add:
          this
              ._delegate
              .onInserted(this._lastEventPosition, this._lastEventCount);
          break;
        case type_remove:
          this
              ._delegate
              .onRemoved(this._lastEventPosition, this._lastEventCount);
          break;
      }
      this._lastEventType = type_none;
    }
  }

  void onInserted(int position, int count) {
    if (this._lastEventType == type_add &&
        position >= this._lastEventPosition &&
        position <= this._lastEventPosition + this._lastEventCount) {
      this._lastEventCount += count;
      this._lastEventPosition = min(position, this._lastEventPosition);
    } else {
      this.dispatchLastEvent();
      this._lastEventPosition = position;
      this._lastEventCount = count;
      this._lastEventType = type_add;
    }
  }

  void onRemoved(int position, int count) {
    if (this._lastEventType == type_remove &&
        this._lastEventPosition >= position &&
        this._lastEventPosition <= position + count) {
      this._lastEventCount += count;
      this._lastEventPosition = position;
    } else {
      this.dispatchLastEvent();
      this._lastEventPosition = position;
      this._lastEventCount = count;
      this._lastEventType = type_remove;
    }
  }

  void onMoved(int fromPosition, int toPosition) {
    this.dispatchLastEvent();
    this._delegate.onMoved(fromPosition, toPosition);
  }


  @override
  BatchingListUpdateCallback batching() => this;
}
