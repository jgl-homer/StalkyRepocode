import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tutorial_controller.dart';

class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.controller,
  });

  final TutorialController controller;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Rect? _targetRect() {
    final key = widget.controller.currentStep?.targetKey;
    final context = key?.currentContext;
    if (context == null) return null;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _pulseController]),
      builder: (context, _) {
        final step = widget.controller.currentStep;
        if (!widget.controller.isActive || step == null) {
          return const SizedBox.shrink();
        }

        final media = MediaQuery.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final screen = Offset.zero & media.size;
        final target = _targetRect();
        final spotlight = target;
        final layout = _resolveLayout(
          size: media.size,
          target: spotlight,
        );

        return Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      spotlight: spotlight,
                      screen: screen,
                      overlayColor: isDark
                          ? const Color(0xD9000000)
                          : const Color(0x99000000),
                    ),
                  ),
                ),
                if (spotlight != null)
                  _GlowFrame(
                    rect: spotlight,
                    pulse: _pulseController.value,
                  ),
                Positioned(
                  left: layout.mascotRect.left,
                  top: layout.mascotRect.top,
                  width: layout.mascotRect.width,
                  height: layout.mascotRect.height,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-0.08, 0.08),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Image.asset(
                      step.spriteAsset,
                      key: ValueKey(step.spriteAsset),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  left: layout.cardRect.left,
                  top: layout.cardRect.top,
                  width: layout.cardRect.width,
                  child: _DialogCard(
                    controller: widget.controller,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _OverlayLayout _resolveLayout({
    required Size size,
    required Rect? target,
  }) {
    const margin = 16.0;
    const cardHeight = 312.0;
    final cardWidth = math.min(size.width - (margin * 2), 330.0);
    const mascotSize = 104.0;
    final cardLeft = (size.width - cardWidth) / 2;
    final cardTop = (size.height * 0.51).clamp(
      margin + mascotSize + 10,
      size.height - cardHeight - 118,
    );

    final cardRect = Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight);
    final mascotRect = Rect.fromLTWH(
      cardRect.left + 12,
      cardRect.top - mascotSize - 10,
      mascotSize,
      mascotSize,
    );

    return _OverlayLayout(
      cardRect: cardRect,
      mascotRect: mascotRect,
    );
  }
}

class _OverlayLayout {
  const _OverlayLayout({
    required this.cardRect,
    required this.mascotRect,
  });

  final Rect cardRect;
  final Rect mascotRect;
}

class _DialogCard extends StatelessWidget {
  const _DialogCard({
    required this.controller,
  });

  final TutorialController controller;

  @override
  Widget build(BuildContext context) {
    final step = controller.currentStep!;
    final total = controller.steps.length;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF202124) : scheme.surface;
    final helperColor = isDark
        ? scheme.primary.withValues(alpha: 0.18)
        : scheme.primary.withValues(alpha: 0.16);
    final inactiveDotColor = scheme.onSurface.withValues(alpha: 0.14);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(step.id),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.22),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Stalky dice:',
                    style: TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${step.stepNumber}/$total',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              step.description,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
                height: 1.42,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (step.targetKey != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: helperColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.primary,
                    width: 1,
                  ),
                ),
                child: Text(
                  'Este es el elemento que estoy explicando.',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: List.generate(total, (index) {
                final active = index == controller.currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 28 : 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: active ? scheme.primary : inactiveDotColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(
                  onPressed: controller.skipTutorial,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurface.withValues(alpha: 0.72),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  child: const Text(
                    'Omitir',
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Atras',
                  onPressed:
                      controller.isFirstStep ? null : controller.previousStep,
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: scheme.onSurface,
                  disabledColor: scheme.onSurface.withValues(alpha: 0.22),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: controller.isLastStep
                      ? controller.finishTutorial
                      : controller.nextStep,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    controller.isLastStep ? 'Finalizar' : 'Siguiente',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowFrame extends StatelessWidget {
  const _GlowFrame({
    required this.rect,
    required this.pulse,
  });

  final Rect rect;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final pulseOutset = 3 + (pulse * 7);
    final borderWidth = 2.4 + (pulse * 1.2);
    final glowBlur = 18 + (pulse * 18);
    final glowSpread = 1 + (pulse * 5);

    return Positioned.fromRect(
      rect: rect.inflate(pulseOutset),
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20 + pulseOutset),
            border: Border.all(
              color: const Color(0xFFF5C84C),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xDDF5C84C),
                blurRadius: glowBlur,
                spreadRadius: glowSpread,
              ),
              BoxShadow(
                color: const Color(0x66F5C84C),
                blurRadius: glowBlur + 18,
                spreadRadius: glowSpread + 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.spotlight,
    required this.screen,
    required this.overlayColor,
  });

  final Rect? spotlight;
  final Rect screen;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(screen);
    if (spotlight != null) {
      overlay.addRRect(
        RRect.fromRectAndRadius(spotlight!, const Radius.circular(18)),
      );
      overlay.fillType = PathFillType.evenOdd;
    }

    canvas.drawPath(
      overlay,
      Paint()..color = overlayColor,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.spotlight != spotlight ||
        oldDelegate.screen != screen ||
        oldDelegate.overlayColor != overlayColor;
  }
}
