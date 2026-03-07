import 'package:my_first_flutter_app/entity/RecordItem.dart';

class UserBest50Entity {
  final int additionalRating;
  final Charts charts;

  UserBest50Entity({
  required this.additionalRating,
  required this.charts,
});
}



class Charts {
  final List<RecordItem> dx;
  final List<RecordItem> sd;
  
  Charts({
    required this.dx,
    required this.sd,
  });
}