import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

final audioServiceProvider =
    Provider<AudioService>((ref) => AudioService.instance);

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  Future<void> speak(String text) async {
    await _init();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}

class AudioStopObserver extends NavigatorObserver {
  @override
  void didPop(Route route, Route? previousRoute) {
    AudioService.instance.stop();
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    AudioService.instance.stop();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    AudioService.instance.stop();
  }
}
