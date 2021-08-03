import 'package:declarative_animated_list/declarative_animated_list.dart';
import 'package:example/bloc.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
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

  const ToDosPage({Key key, @required this.bloc}) : super(key: key);

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<ToDosState>(
          stream: bloc.toDosState,
          builder: (_, final AsyncSnapshot<ToDosState> snapshot) {
            return _buildBody(context, bloc, snapshot);
          }),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildBody(final BuildContext context, final ToDosBloc bloc,
      final AsyncSnapshot<ToDosState> snapshot) {
    if (snapshot.hasData) {
      return _buildBasedOnState(context, snapshot, bloc);
    } else if (snapshot.hasError) {
      return Center(
          child: Text(
        "Error occurred: ${snapshot.error}",
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, color: Colors.black),
      ));
    } else {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
  }

  Widget _buildBasedOnState(final BuildContext context,
      final AsyncSnapshot<ToDosState> snapshot, final ToDosBloc bloc) {
    final ToDosState viewModel = snapshot.data;
    final List<ToDoPresentationModel> toDos = viewModel.toDos.toList()
      ..sort((left, right) {
        if (left.completed == right.completed) {
          return left.description.compareTo(right.description);
        } else {
          return left.completed ? 1 : -1;
        }
      });
    if (toDos.isEmpty) {
      return Center(
          child: Container(
        child: Icon(
          Icons.delete_outline,
          size: MediaQuery.of(context).size.height * 0.4,
          color: Theme.of(context).accentColor,
        ),
      ));
    } else {
      return DeclarativeList(
        items: toDos,
        insertDuration: const Duration(milliseconds: 500),
        removeDuration: const Duration(milliseconds: 500),
        itemBuilder:
            (_, ToDoPresentationModel model, __, Animation<double> anim) =>
                _buildFadeAndSizeTransitioningTile(anim, model, bloc),
        removeBuilder:
            (_, ToDoPresentationModel model, __, Animation<double> anim) =>
                _buildFadeAndSizeTransitioningTile(anim, model, bloc),
      );
    }
  }

  Widget _buildFadeAndSizeTransitioningTile(final Animation<double> anim,
      final ToDoPresentationModel model, final ToDosBloc bloc) {
    return FadeTransition(
      opacity: anim,
      child: SizeTransition(
        sizeFactor: anim,
        axisAlignment: 0.0,
        child: _buildTile(model, bloc),
      ),
    );
  }

  Widget _buildTile(final ToDoPresentationModel toDo, final ToDosBloc bloc) {
    return ListTile(
      title: Text(toDo.description),
      leading: IconButton(
        icon: Icon(
          toDo.completed ? Icons.check : Icons.sync,
        ),
        onPressed: () => bloc.changeToDoStatus
            .add(ChangeCompletionStatusEvent(toDo, !toDo.completed)),
      ),
      onLongPress: () => bloc.removeToDo.add(RemoveToDoEvent(toDo)),
    );
  }

  Widget _buildFab(final BuildContext context) {
    return FloatingActionButton(
      child: Icon(Icons.add),
      onPressed: () => showDialog(
          context: context,
          builder: (final BuildContext ctx) {
            final TextEditingController controller = TextEditingController();
            final Size size = MediaQuery.of(ctx).size;
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
                      icon: Icon(Icons.check),
                      onPressed: () {
                        bloc.addToDo.add(AddToDoEvent(controller.text));
                        Navigator.of(ctx).pop();
                      },
                    )
                  ],
                ),
              ),
            );
          }),
    );
  }
}
