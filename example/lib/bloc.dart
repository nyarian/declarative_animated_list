import 'dart:async';
import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';

class ToDosBloc {
  final StreamController<AddToDoEvent> _addToDoSC = StreamController();
  final BehaviorSubject<ToDosState> _toDosBS = BehaviorSubject();
  final StreamController<RemoveToDoEvent> _removeToDoSC = StreamController();
  final StreamController<ChangeCompletionStatusEvent> _changeToDoStatusSC =
      StreamController();

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
    final ToDosState newState = _currentState
        .populate(List.generate(10, (_) => ToDoPresentationModel.random()));
    _toDosBS.add(newState);
  }

  void _addToDo(final AddToDoEvent event) {
    final ToDoPresentationModel newToDo =
        ToDoPresentationModel(event.description, false);
    _toDosBS.add(_currentState.addToDo(newToDo));
  }

  void _removeToDo(final RemoveToDoEvent event) {
    _toDosBS.add(_currentState.removeToDo(event.toDo));
  }

  void _changeStatus(final ChangeCompletionStatusEvent event) {
    final ToDoPresentationModel targetToDo =
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

class AddToDoEvent with EquatableMixinBase, EquatableMixin {
  final String description;

  AddToDoEvent(this.description);

  @override
  List get props => [description];
}

class RemoveToDoEvent with EquatableMixinBase, EquatableMixin {
  final ToDoPresentationModel toDo;

  RemoveToDoEvent(this.toDo);

  @override
  List get props => [toDo];
}

class ChangeCompletionStatusEvent with EquatableMixinBase, EquatableMixin {
  final ToDoPresentationModel toDo;
  final bool shouldBeCompleted;

  ChangeCompletionStatusEvent(this.toDo, this.shouldBeCompleted);

  @override
  List get props => [toDo, shouldBeCompleted];
}

class ToDosState with EquatableMixinBase, EquatableMixin {
  final BuiltList<ToDoPresentationModel> toDos;
  final Object error;

  bool get hasError => error != null;

  ToDosState(this.toDos, this.error);

  ToDosState.empty() : this(BuiltList(), null);

  ToDosState copy(
      {final Iterable<ToDoPresentationModel> toDos, final Object error}) {
    return ToDosState(
        toDos == null ? this.toDos : BuiltList(toDos), error ?? this.error);
  }

  ToDosState addToDo(final ToDoPresentationModel toDo) =>
      copy(toDos: this.toDos.toList()..add(toDo));

  ToDosState removeToDo(final ToDoPresentationModel toDo) =>
      copy(toDos: this.toDos.toList()..remove(toDo));

  ToDosState populate(final List<ToDoPresentationModel> toDos) =>
      copy(toDos: this.toDos.toList()..addAll(toDos));

  ToDosState withError(final Object error) => copy(error: error);

  ToDosState replace(final ToDoPresentationModel originalToDo,
      final ToDoPresentationModel targetToDo) {
    final int index = this.toDos.indexOf(originalToDo);
    return copy(
        toDos: this.toDos.toList()
          ..removeAt(index)
          ..insert(index, targetToDo));
  }

  @override
  List get props => [toDos, error];
}

class ToDoPresentationModel with EquatableMixinBase, EquatableMixin {
  final String description;
  final bool completed;

  ToDoPresentationModel(this.description, this.completed);

  ToDoPresentationModel.random()
      : this(_random.nextInt(10000).toString(), _random.nextBool());

  ToDoPresentationModel complete() =>
      ToDoPresentationModel(this.description, true);

  ToDoPresentationModel resume() =>
      ToDoPresentationModel(this.description, false);

  @override
  List get props => [description, completed];
}

Random _random = Random();
