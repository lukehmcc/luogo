import 'package:hive_ce/hive.dart';
import 'package:luogo/model/hive_latlng.dart';
import 'package:luogo/model/user_state.dart';

// Put any new hive ready class here
@GenerateAdapters([AdapterSpec<HiveLatLng>(), AdapterSpec<UserState>()])
part 'hive_adapters.g.dart';
