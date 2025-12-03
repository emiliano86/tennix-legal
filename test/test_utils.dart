import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

/// Setup automatic mocking of SharedPreferences for all tests.
void setupMockSharedPreferences() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });
}
