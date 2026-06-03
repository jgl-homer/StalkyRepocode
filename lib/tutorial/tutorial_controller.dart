import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tutorial_step.dart';

class TutorialController extends ChangeNotifier {
  TutorialController({
    required this.steps,
    this.completedPreferenceKey = 'stalky_onboarding_completed',
  });

  final List<TutorialStep> steps;
  final String completedPreferenceKey;

  int _currentIndex = 0;
  bool _isActive = false;

  int get currentIndex => _currentIndex;
  bool get isActive => _isActive;
  bool get isFirstStep => _currentIndex == 0;
  bool get isLastStep => _currentIndex == steps.length - 1;
  TutorialStep? get currentStep =>
      steps.isEmpty || !_isActive ? null : steps[_currentIndex];

  Future<void> startTutorialIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(completedPreferenceKey) ?? false;
    if (!completed) {
      startTutorial();
    }
  }

  void startTutorial() {
    if (steps.isEmpty) return;
    _currentIndex = 0;
    _isActive = true;
    notifyListeners();
  }

  void nextStep() {
    if (!_isActive) return;
    if (isLastStep) {
      finishTutorial();
      return;
    }
    _currentIndex++;
    notifyListeners();
  }

  void previousStep() {
    if (!_isActive || isFirstStep) return;
    _currentIndex--;
    notifyListeners();
  }

  Future<void> finishTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(completedPreferenceKey, true);
    _isActive = false;
    notifyListeners();
  }

  Future<void> skipTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(completedPreferenceKey, true);
    _isActive = false;
    notifyListeners();
  }
}
