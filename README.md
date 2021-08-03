# Declarative animated list

An implementation of animated list widget that will be automatically updated based on different lists snippets.
Based on [Android's DiffUtil](https://github.com/aosp-mirror/platform_frameworks_support/blob/d79202da157cdd94c2d0c0b6ee57170a97d12c93/recyclerview/recyclerview/src/main/java/androidx/recyclerview/widget/DiffUtil.java) with slight changes to support Flutter's declarative UI.

![](demo.gif)

```dart

//Create a list tile, wrapped with an animation applying widget
Widget _buildAnimatedTile(final Animation<double> animation, final PresentationModel model) {
  return FadeTransition(
    opacity: animation,
    child: SizeTransition(
      sizeFactor: animation,
      axisAlignment: 0.0,
      child: SomeWidget(model),
    ),
  );
}

Widget _buildRemovingTile(final Animation<double> animation, final PresentationModel model) { 
  //... 
}

final DeclarativeList<PresentationModel> declarativeList = DeclarativeList(
  items: presentationModels,
  itemBuilder: (BuildContext ctx, PresentationModel model, int index, Animation<double> animation) {
    return _buildAnimatedTile(animation, model);
  },
  removeBuilder: (BuildContext ctx, PresentationModel model, int index, Animation<double> animation) {
    return _buildRemovingTile(animation, model);
  }  
);


```

And... that's it!

## Getting Started

#### 1. Add dependency to your `pubspec.yaml`

```yaml
dependencies:
  declarative_animated_list: ^0.1.0-nullsafety.0
```

#### 2. Import it

```dart
import 'package:declarative_animated_list/declarative_animated_list.dart';
```

#### 3. Use it! Refer to the `examples` folder if needed.