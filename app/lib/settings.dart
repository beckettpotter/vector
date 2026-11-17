import 'package:flutter/foundation.dart';

/// User choices shared by the screens. Saved across restarts in task 12.
class AppSettings extends ChangeNotifier {
  bool _useFeet = false;
  bool get useFeet => _useFeet;
  set useFeet(bool v) {
    if (v == _useFeet) return;
    _useFeet = v;
    notifyListeners();
  }
}
