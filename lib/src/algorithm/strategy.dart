import 'package:declarative_animated_list/src/algorithm/myers/myer.dart';
import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';

abstract class DifferentiatingStrategy {
  DifferenceResult differentiate(DifferenceRequest request);
}

class DifferentiatingStrategyFactory {
  factory DifferentiatingStrategyFactory() =>
      const DifferentiatingStrategyFactory._constant();

  const DifferentiatingStrategyFactory._constant();

  DifferentiatingStrategy create() => MyersDifferenceAlgorithm();
}
