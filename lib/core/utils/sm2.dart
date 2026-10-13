class SM2Result {
  final int interval;
  final double easeFactor;
  final int repetitions;
  final DateTime nextReviewAt;

  const SM2Result({
    required this.interval,
    required this.easeFactor,
    required this.repetitions,
    required this.nextReviewAt,
  });
}

/// Intervals used by the study reviews, in days.
///
/// The first interval is one day (24 hours). Keeping these milestones
/// explicit makes the same progression available to English and Contest
/// cards, regardless of the card's previous interval value.
const spacedReviewIntervals = <int>[1, 3, 7, 14, 30, 60, 90];

// Spaced repetition algorithm.
// quality: 0–2 = Incorrect, 3 = Hard, 4 = Good, 5 = Easy
SM2Result computeSM2({
  required int currentInterval,
  required double easeFactor,
  required int repetitions,
  required int quality,
}) {
  final currentMilestone = _milestoneIndex(currentInterval);
  late final int newInterval;
  late final int newRepetitions;

  if (quality < 3) {
    // A failed recall comes back tomorrow and starts the progression again.
    newInterval = spacedReviewIntervals.first;
    newRepetitions = 0;
  } else {
    newRepetitions = repetitions + 1;

    switch (quality) {
      case 3:
        // Hard: repeat the current step instead of pushing the card forward.
        newInterval =
            currentInterval > 0 ? currentInterval : spacedReviewIntervals.first;
      case 5:
        // Easy: skip one step. This gives a meaningful benefit without
        // jumping straight from the first review to a long period.
        final nextIndex =
            (currentMilestone + 2).clamp(0, spacedReviewIntervals.length - 1);
        newInterval = spacedReviewIntervals[nextIndex];
      default:
        // Good: move to the next configured milestone.
        final nextIndex =
            (currentMilestone + 1).clamp(0, spacedReviewIntervals.length - 1);
        newInterval = spacedReviewIntervals[nextIndex];
    }
  }

  double newEaseFactor =
      easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  if (newEaseFactor < 1.3) newEaseFactor = 1.3;

  // Due at midnight of the target day so cards appear when the user opens the app that day.
  final now = DateTime.now();
  final nextReviewAt =
      DateTime(now.year, now.month, now.day).add(Duration(days: newInterval));

  return SM2Result(
    interval: newInterval,
    easeFactor: newEaseFactor,
    repetitions: newRepetitions,
    nextReviewAt: nextReviewAt,
  );
}

int _milestoneIndex(int interval) {
  if (interval <= 0) return -1;

  for (var index = 0; index < spacedReviewIntervals.length; index++) {
    if (interval < spacedReviewIntervals[index]) return index - 1;
  }

  return spacedReviewIntervals.length - 1;
}

String formatInterval(int days) {
  if (days <= 0) return 'hoje';
  if (days == 1) return 'amanhã';
  if (days < 7) return 'em $days dias';
  final weeks = (days / 7).round();
  if (weeks <= 4) return weeks == 1 ? 'em 1 semana' : 'em $weeks semanas';
  final months = (days / 30).round();
  if (months < 12) return months == 1 ? 'em 1 mês' : 'em $months meses';
  final years = (days / 365).round();
  return years == 1 ? 'em 1 ano' : 'em $years anos';
}
