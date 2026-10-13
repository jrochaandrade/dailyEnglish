import 'package:flutter_test/flutter_test.dart';

import 'package:daily_english/core/utils/sm2.dart';

void main() {
  group('spaced review intervals', () {
    test('advances with Good from 24 hours through the configured milestones',
        () {
      var interval = 0;
      var repetitions = 0;
      var easeFactor = 2.5;
      const expected = [1, 3, 7, 14, 30, 60, 90];

      for (final expectedInterval in expected) {
        final result = computeSM2(
          currentInterval: interval,
          easeFactor: easeFactor,
          repetitions: repetitions,
          quality: 4,
        );
        interval = result.interval;
        repetitions = result.repetitions;
        easeFactor = result.easeFactor;

        expect(result.interval, expectedInterval);
      }
    });

    test('Hard repeats the current step and Easy skips one step', () {
      final hard = computeSM2(
        currentInterval: 7,
        easeFactor: 2.5,
        repetitions: 3,
        quality: 3,
      );
      final easy = computeSM2(
        currentInterval: 7,
        easeFactor: 2.5,
        repetitions: 3,
        quality: 5,
      );

      expect(hard.interval, 7);
      expect(easy.interval, 30);
    });

    test('failure restarts the review at 24 hours', () {
      final result = computeSM2(
        currentInterval: 60,
        easeFactor: 2.5,
        repetitions: 8,
        quality: 0,
      );

      expect(result.interval, 1);
      expect(result.repetitions, 0);
      expect(result.easeFactor, closeTo(1.7, 0.0001));
    });
  });
}
