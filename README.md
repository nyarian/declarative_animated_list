# Declarative animated list

An implementation of animated list widget that will be automatically updated based on different lists snippets.
Based on [Android's DiffUtil](https://github.com/aosp-mirror/platform_frameworks_support/blob/d79202da157cdd94c2d0c0b6ee57170a97d12c93/recyclerview/recyclerview/src/main/java/androidx/recyclerview/widget/DiffUtil.java) with slight changes to support Flutter's declarative UI.

![](demo.gif)

```dart

// Create a list tile, wrapped with an animation applying widget
Widget _buildAnimatedTile(Animation<double> animation, PresentationModel model) {
  return FadeTransition(
    opacity: animation,
    child: SizeTransition(
      sizeFactor: animation,
      child: SomeWidget(model),
    ),
  );
}

Widget _buildRemovingTile(final Animation<double> animation, final PresentationModel model) { 
  //... 
}

final declarativeList = DeclarativeList<PresentationModel>(
  items: presentationModels,
  itemBuilder: (ctx, model, index, animation) => _buildAnimatedTile(animation, model),
  removeBuilder: (ctx, model, index, animation) => _buildRemovingTile(animation, model),
);
```
