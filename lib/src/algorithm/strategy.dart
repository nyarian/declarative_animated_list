import 'package:reactive_list/src/algorithm/request.dart';
import 'package:reactive_list/src/algorithm/result.dart';

abstract class DifferentiatingStrategy {

  DifferenceResult differentiate(DifferenceRequest request);

}
