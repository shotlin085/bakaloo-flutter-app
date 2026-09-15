import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/features/scratch_card/presentation/widgets/scratch_reveal.dart';

void main() {
  // The widget is pumped at a fixed 300x300 size, top-left aligned (not
  // Center-wrapped) — Align/Center would place it away from (0,0), and
  // WidgetController.dragFrom/drag use GLOBAL screen coordinates, not
  // coordinates local to the widget under test.
  Future<void> pumpScratcher(
    WidgetTester tester, {
    required bool enabled,
    VoidCallback? onScratchStart,
    VoidCallback? onThresholdReached,
    double thresholdPercent = 55,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 300,
            child: ScratchReveal(
              enabled: enabled,
              brushRadius: 30,
              thresholdPercent: thresholdPercent,
              onScratchStart: onScratchStart,
              onThresholdReached: onThresholdReached,
              foil: const ColoredBox(key: Key('foil'), color: Colors.red),
              child: const ColoredBox(key: Key('prize'), color: Colors.blue),
            ),
          ),
        ),
      ),
    );
  }

  /// A row of separate left-to-right drags — enough coverage to cross any
  /// reasonable threshold on a 24x24 checkpoint grid. Separate `tester.
  /// dragFrom` calls (each a complete, properly-sequenced down/move/up)
  /// proved far more reliable than one continuous multi-segment gesture,
  /// where PanGestureRecognizer's own slop/arena handling swallowed
  /// several of the intermediate moveTo calls.
  Future<void> scratchWholeArea(WidgetTester tester) async {
    for (var row = 0; row <= 10; row++) {
      final y = 20.0 + row * 25;
      await tester.dragFrom(Offset(20, y), const Offset(260, 0));
      await tester.pump();
    }
  }

  testWidgets('foil and clip are both present, not yet revealed, before any scratching (positive)', (tester) async {
    final key = GlobalKey<ScratchRevealState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 300,
            child: ScratchReveal(
              key: key,
              foil: const ColoredBox(key: Key('foil'), color: Colors.red),
              child: const ColoredBox(key: Key('prize'), color: Colors.blue),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('foil')), findsOneWidget);
    expect(find.byType(ClipPath), findsOneWidget);
    expect(key.currentState!.isFullyRevealed, isFalse);
  });

  testWidgets('onScratchStart fires on the first drag regardless of enabled (positive)', (tester) async {
    var started = false;
    await pumpScratcher(tester, enabled: false, onScratchStart: () => started = true);
    // PanGestureRecognizer needs actual movement (beyond touch slop) before
    // it declares itself the winner and fires onPanStart — a bare
    // startGesture with no move never triggers it.
    await tester.dragFrom(const Offset(150, 150), const Offset(40, 0));
    await tester.pump();
    expect(started, isTrue);
  });

  testWidgets('while disabled, scratching leaves no mark and never reaches threshold (negative)', (tester) async {
    var thresholdHit = false;
    await pumpScratcher(tester, enabled: false, onThresholdReached: () => thresholdHit = true);
    await scratchWholeArea(tester);
    expect(thresholdHit, isFalse);
  });

  testWidgets('scratching most of the area while enabled reaches the threshold exactly once (positive)', (tester) async {
    var thresholdHitCount = 0;
    await pumpScratcher(
      tester,
      enabled: true,
      onThresholdReached: () => thresholdHitCount++,
    );
    await scratchWholeArea(tester);
    expect(thresholdHitCount, 1);
  });

  testWidgets('a few small dabs well under the threshold do not trigger it (negative)', (tester) async {
    var thresholdHit = false;
    await pumpScratcher(tester, enabled: true, onThresholdReached: () => thresholdHit = true);
    await tester.dragFrom(const Offset(20, 20), const Offset(15, 0));
    await tester.pump();
    expect(thresholdHit, isFalse);
  });

  testWidgets('reveal() flips isFullyRevealed and needs no further scratching (positive)', (tester) async {
    final key = GlobalKey<ScratchRevealState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 300,
            child: ScratchReveal(
              key: key,
              foil: const ColoredBox(color: Colors.red),
              child: const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    );

    expect(key.currentState!.isFullyRevealed, isFalse);
    key.currentState!.reveal();
    await tester.pump();
    expect(key.currentState!.isFullyRevealed, isTrue);
  });

  testWidgets('once revealed, further scratching is a no-op (negative)', (tester) async {
    final key = GlobalKey<ScratchRevealState>();
    var thresholdHitCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 300,
            child: ScratchReveal(
              key: key,
              enabled: true,
              onThresholdReached: () => thresholdHitCount++,
              foil: const ColoredBox(color: Colors.red),
              child: const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    );

    key.currentState!.reveal();
    await tester.pump();
    await scratchWholeArea(tester);
    expect(thresholdHitCount, 0);
  });
}
