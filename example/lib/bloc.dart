import 'dart:async';
import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';

class ToDosBloc {
  final _addToDoSC = StreamController<AddToDoEvent>();
  final _toDosBS = BehaviorSubject<ToDosState>();
  final _removeToDoSC = StreamController<RemoveToDoEvent>();
  final _changeToDoStatusSC = StreamController<ChangeCompletionStatusEvent>();

  ToDosState get _currentState => _toDosBS.value;

  ToDosBloc() {
    _toDosBS.add(ToDosState.empty());
    _addToDoSC.stream.listen(_addToDo);
    _removeToDoSC.stream.listen(_removeToDo);
    _changeToDoStatusSC.stream.listen(_changeStatus);
    _fetchToDosFromRepository();
  }

  Stream<ToDosState> get toDosState => _toDosBS.stream;

  Sink<AddToDoEvent> get addToDo => _addToDoSC.sink;

  Sink<RemoveToDoEvent> get removeToDo => _removeToDoSC.sink;

  Sink<ChangeCompletionStatusEvent> get changeToDoStatus =>
      _changeToDoStatusSC.sink;

  void _fetchToDosFromRepository() {
    final newState = _currentState
        .populate(List.generate(10, (_) => ToDoPresentationModel.random()));
    _toDosBS.add(newState);
  }

  void _addToDo(final AddToDoEvent event) {
    final newToDo =
        ToDoPresentationModel(event.description, isCompleted: false);
    _toDosBS.add(_currentState.addToDo(newToDo));
  }

  void _removeToDo(final RemoveToDoEvent event) {
    _toDosBS.add(_currentState.removeToDo(event.toDo));
  }

  void _changeStatus(final ChangeCompletionStatusEvent event) {
    final targetToDo =
        event.shouldBeCompleted ? event.toDo.complete() : event.toDo.resume();
    _toDosBS.add(_currentState.replace(event.toDo, targetToDo));
  }

  void dispose() {
    _toDosBS.close();
    _addToDoSC.close();
    _removeToDoSC.close();
    _changeToDoStatusSC.close();
  }
}

class AddToDoEvent with EquatableMixin {
  final String description;

  const AddToDoEvent(this.description);

  @override
  List<Object?> get props => [description];
}

class RemoveToDoEvent with EquatableMixin {
  final ToDoPresentationModel toDo;

  const RemoveToDoEvent(this.toDo);

  @override
  List<Object?> get props => [toDo];
}

class ChangeCompletionStatusEvent with EquatableMixin {
  final ToDoPresentationModel toDo;
  final bool shouldBeCompleted;

  ChangeCompletionStatusEvent(this.toDo, {required this.shouldBeCompleted});

  @override
  List<Object?> get props => [toDo, shouldBeCompleted];
}

class ToDosState with EquatableMixin {
  final BuiltList<ToDoPresentationModel> toDos;
  final Object? error;

  bool get hasError => error != null;

  ToDosState(this.toDos, this.error);

  ToDosState.empty() : this(BuiltList(), null);

  ToDosState copy({
    Iterable<ToDoPresentationModel>? toDos,
    Object? error,
  }) {
    return ToDosState(
      toDos == null ? this.toDos : BuiltList(toDos),
      error ?? this.error,
    );
  }

  ToDosState addToDo(final ToDoPresentationModel toDo) =>
      copy(toDos: toDos.toList()..add(toDo));

  ToDosState removeToDo(final ToDoPresentationModel toDo) =>
      copy(toDos: toDos.toList()..remove(toDo));

  ToDosState populate(final List<ToDoPresentationModel> toDos) =>
      copy(toDos: this.toDos.toList()..addAll(toDos));

  ToDosState withError(final Object error) => copy(error: error);

  ToDosState replace(final ToDoPresentationModel originalToDo,
      final ToDoPresentationModel targetToDo) {
    final index = toDos.indexOf(originalToDo);
    return copy(
      toDos: toDos.toList()
        ..removeAt(index)
        ..insert(index, targetToDo),
    );
  }

  @override
  List<Object?> get props => [toDos, error];
}

class ToDoPresentationModel with EquatableMixin {
  final String description;
  final bool isCompleted;

  ToDoPresentationModel(this.description, {required this.isCompleted});

  ToDoPresentationModel.random()
      : this(_random.nextInt(10000).toString(),
            isCompleted: _random.nextBool());

  ToDoPresentationModel complete() =>
      ToDoPresentationModel(description, isCompleted: true);

  ToDoPresentationModel resume() =>
      ToDoPresentationModel(description, isCompleted: false);

  @override
  List<Object?> get props => [description, isCompleted];
}

final _random = Random();
