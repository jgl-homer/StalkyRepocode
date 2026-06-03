import 'package:flutter/widgets.dart';

class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.title,
    required this.description,
    required this.targetKey,
    required this.spriteAsset,
    required this.stepNumber,
    this.tabIndex,
  });

  final String id;
  final String title;
  final String description;
  final GlobalKey? targetKey;
  final String spriteAsset;
  final int stepNumber;
  final int? tabIndex;
}
