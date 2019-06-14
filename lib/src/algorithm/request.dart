abstract class DifferenceRequest {
  int get oldSize;

  int get newSize;

  bool isTheSameConceptualEntity(final int oldPosition, final int newPosition);

  bool areInstancesEqual(final int oldPosition, final int newPosition);

  Object getChangePayload(final int oldPosition, final int newPosition) => null;
}

class ListsDifferenceRequest<T> implements DifferenceRequest {
  final List<T> old;
  final List<T> updated;
  final EqualityCheck<T> identityCheck;
  final EqualityCheck<T> equalityCheck;
  final PayloadDefinition<T> payloadDefinition;

  ListsDifferenceRequest(this.old, this.updated,
      {final EqualityCheck<T> identityCheck,
      final EqualityCheck<T> equalityCheck,
      final PayloadDefinition<T> payloadDefinition})
      : this.identityCheck = identityCheck ?? _equalsOperatorCheck,
        this.equalityCheck = equalityCheck ?? _equalsOperatorCheck,
        this.payloadDefinition = payloadDefinition ?? ((_, __) => null);

  @override
  int get oldSize => old.length;

  @override
  int get newSize => updated.length;

  @override
  bool isTheSameConceptualEntity(final int oldPosition, final int newPosition) {
    return identityCheck(old[oldPosition], updated[newPosition]);
  }

  @override
  bool areInstancesEqual(final int oldPosition, final int newPosition) {
    return equalityCheck(old[oldPosition], updated[newPosition]);
  }

  @override
  Object getChangePayload(final int oldPosition, final int newPosition) {
    return payloadDefinition(old[oldPosition], updated[newPosition]);
  }
}

final EqualityCheck<Object> _equalsOperatorCheck =
    (final Object left, final Object right) => left == right;

typedef EqualityCheck<T> = bool Function(T, T);

typedef PayloadDefinition<T> = Object Function(T, T);
