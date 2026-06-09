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

// SuperMemo SM-2 algorithm.
// quality: 0–2 = Incorrect, 3 = Hard, 4 = Good, 5 = Easy
SM2Result computeSM2({
  required int currentInterval,
  required double easeFactor,
  required int repetitions,
  required int quality,
}) {
  int newInterval;
  int newRepetitions;

  if (quality >= 3) {
    if (repetitions == 0) {
      newInterval = quality == 5 ? 3 : 1;
    } else if (repetitions == 1) {
      newInterval = quality == 5 ? 8 : 6;
    } else {
      final base = (currentInterval * easeFactor).round();
      newInterval = quality == 5 ? (base * 1.3).round() : base;
      if (newInterval < 1) newInterval = 1;
    }
    newRepetitions = repetitions + 1;
  } else {
    newInterval = 1;
    newRepetitions = 0;
  }

  double newEaseFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  if (newEaseFactor < 1.3) newEaseFactor = 1.3;

  // Due at midnight of the target day so cards appear when the user opens the app that day.
  final now = DateTime.now();
  final nextReviewAt = DateTime(now.year, now.month, now.day).add(Duration(days: newInterval));

  return SM2Result(
    interval: newInterval,
    easeFactor: newEaseFactor,
    repetitions: newRepetitions,
    nextReviewAt: nextReviewAt,
  );
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
