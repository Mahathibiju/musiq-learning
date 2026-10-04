import 'package:flutter/foundation.dart';

class SongProgressService extends ChangeNotifier {
  int _xp = 0;

  int get xp => _xp;

  void songAnalyzed() => _award(20);
  void singingAttemptCompleted() => _award(30);
  void sectionImproved() => _award(50);
  void songCompleted() => _award(100);
  void sectionPracticed() => _award(10);
  void loopSessionCompleted() => _award(15);

  void _award(int amount) {
    _xp += amount;
    notifyListeners();
  }
}
