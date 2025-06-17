import 'package:hive_ce/hive.dart';
import 'package:luogo/model/hive_latlng.dart';

@GenerateAdapters([AdapterSpec<HiveLatLng>()])
part 'hive_adapters.g.dart';
