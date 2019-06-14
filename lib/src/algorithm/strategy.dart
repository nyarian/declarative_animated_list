import 'package:declarative_animated_list/src/algorithm/request.dart';
import 'package:declarative_animated_list/src/algorithm/result.dart';

abstract class DifferentiatingStrategy {

  DifferenceResult differentiate(DifferenceRequest request);

}
