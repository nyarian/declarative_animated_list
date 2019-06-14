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

abstract class DifferenceRequest {
  int get oldSize;

  int get newSize;

  bool areEqual(final int oldPosition, final int newPosition);
}

class ListsDifferenceRequest<T> implements DifferenceRequest {
  final List<T> old;
  final List<T> updated;
  final EqualityCheck<T> equalityCheck;

  ListsDifferenceRequest(this.old, this.updated,
      {final EqualityCheck<T> equalityCheck})
      : this.equalityCheck = equalityCheck ?? _equalsOperatorCheck;

  @override
  int get oldSize => old.length;

  @override
  int get newSize => updated.length;

  @override
  bool areEqual(final int oldPosition, final int newPosition) {
    return equalityCheck(old[oldPosition], updated[newPosition]);
  }
}

final EqualityCheck<Object> _equalsOperatorCheck =
    (final Object left, final Object right) => left == right;

typedef EqualityCheck<T> = bool Function(T, T);

typedef PayloadDefinition<T> = Object Function(T, T);
