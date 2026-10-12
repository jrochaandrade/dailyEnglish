import 'package:shared_preferences/shared_preferences.dart';

class MockTestTargets {
  final double overallTarget;
  final double listeningMin;
  final double readingMin;
  final double writingMin;
  final double speakingMin;

  const MockTestTargets({
    this.overallTarget = 7.0,
    this.listeningMin = 6.0,
    this.readingMin = 6.0,
    this.writingMin = 6.0,
    this.speakingMin = 6.0,
  });

  static const _keyOverall = 'mock_target_overall';
  static const _keyListening = 'mock_target_listening';
  static const _keyReading = 'mock_target_reading';
  static const _keyWriting = 'mock_target_writing';
  static const _keySpeaking = 'mock_target_speaking';

  static Future<MockTestTargets> load() async {
    final prefs = await SharedPreferences.getInstance();
    return MockTestTargets(
      overallTarget: prefs.getDouble(_keyOverall) ?? 7.0,
      listeningMin: prefs.getDouble(_keyListening) ?? 6.0,
      readingMin: prefs.getDouble(_keyReading) ?? 6.0,
      writingMin: prefs.getDouble(_keyWriting) ?? 6.0,
      speakingMin: prefs.getDouble(_keySpeaking) ?? 6.0,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyOverall, overallTarget);
    await prefs.setDouble(_keyListening, listeningMin);
    await prefs.setDouble(_keyReading, readingMin);
    await prefs.setDouble(_keyWriting, writingMin);
    await prefs.setDouble(_keySpeaking, speakingMin);
  }

  bool isReached(
      double listening, double reading, double writing, double speaking) {
    double round(double v) => (v * 2).round() / 2;
    final avg = (listening + reading + writing + speaking) / 4;
    final rounded = round(avg);
    return rounded >= overallTarget &&
        round(listening) >= listeningMin &&
        round(reading) >= readingMin &&
        round(writing) >= writingMin &&
        round(speaking) >= speakingMin;
  }
}
