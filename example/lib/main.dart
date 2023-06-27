import 'package:declarative_animated_list/declarative_animated_list.dart';
import 'package:example/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ToDosBloc bloc = ToDosBloc();
    return MaterialApp(
      title: 'Declarative Animated List Demo',
      theme: ThemeData.dark(),
      home: ToDosPage(
        bloc: bloc,
      ),
    );
  }
}

class ToDosPage extends StatelessWidget {
  final ToDosBloc bloc;

  const ToDosPage({required this.bloc, super.key});

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<ToDosState>(
        stream: bloc.toDosState,
        builder: (_, final AsyncSnapshot<ToDosState> snapshot) {
          return _buildBody(context, snapshot);
        },
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<ToDosState> snapshot,
  ) {
    if (snapshot.hasData) {
      return _buildBasedOnState(context, snapshot.data!);
    } else if (snapshot.hasError) {
      return Center(
        child: Text(
          'Error occurred: ${snapshot.error}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildBasedOnState(
    BuildContext context,
    ToDosState state,
  ) {
    final List<ToDoPresentationModel> toDos = state.toDos.toList()
      ..sort(
        (left, right) {
          if (left.isCompleted == right.isCompleted) {
            return left.description.compareTo(right.description);
          } else {
            return left.isCompleted ? 1 : -1;
          }
        },
      );
    if (toDos.isEmpty) {
      return Center(
        child: Icon(
          Icons.delete_outline,
          size: MediaQuery.of(context).size.height * 0.4,
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    } else {
      return DeclarativeList<ToDoPresentationModel>(
        items: toDos,
        insertDuration: const Duration(milliseconds: 500),
        removeDuration: const Duration(milliseconds: 500),
        itemBuilder: (_, model, __, anim) =>
            _buildFadeAndSizeTransitioningTile(anim, model),
        removeBuilder: (_, model, __, anim) =>
            _buildFadeAndSizeTransitioningTile(anim, model),
      );
    }
  }

  Widget _buildFadeAndSizeTransitioningTile(
    Animation<double> animation,
    ToDoPresentationModel model,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SizeTransition(sizeFactor: animation, child: _buildTile(model)),
    );
  }

  Widget _buildTile(ToDoPresentationModel toDo) {
    return ListTile(
      onLongPress: () => bloc.removeToDo.add(RemoveToDoEvent(toDo)),
      title: Text(toDo.description),
      leading: IconButton(
        icon: Icon(toDo.isCompleted ? Icons.check : Icons.sync),
        onPressed: () {
          bloc.changeToDoStatus.add(
            ChangeCompletionStatusEvent(
              toDo,
              shouldBeCompleted: !toDo.isCompleted,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton(
      child: const Icon(Icons.add),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          final size = MediaQuery.sizeOf(ctx);
          return Container(
            height: size.height * 0.5,
            width: size.width * 0.5,
            padding: const EdgeInsets.all(16.0),
            child: Material(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(controller: controller),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () {
                      bloc.addToDo.add(AddToDoEvent(controller.text));
                      Navigator.of(ctx).pop();
                    },
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty('bloc', bloc));
  }
}
