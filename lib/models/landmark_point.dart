import 'package:hive/hive.dart';
part 'landmark_point.g.dart';

@HiveType(typeId: 1) // typeIdはユニークにする
class LandmarkPoint extends HiveObject {
  @HiveField(0)
  final double x;

  @HiveField(1)
  final double y;

  LandmarkPoint({required this.x, required this.y});
}