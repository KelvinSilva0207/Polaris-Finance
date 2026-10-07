import 'package:drift/native.dart';

import 'app_database.dart';

AppDatabase createMemoryDatabase() => AppDatabase(NativeDatabase.memory());
