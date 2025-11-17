import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class TtsController extends ChangeNotifier {
  static final TtsController _instance = TtsController._internal();
  factory TtsController() => _instance;

  TtsController._internal() {
    _flutterTts.setCompletionHandler(() {
      _currentKey = null;
      notifyListeners();
    });
  }

  final FlutterTts _flutterTts = FlutterTts();
  String? _currentKey; // format: "title_index"

  String? get currentKey => _currentKey;

  Future<void> speak(String text, String key) async {
    await _flutterTts.stop(); // stop any previous
    _currentKey = key;
    notifyListeners();
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _currentKey = null;
    notifyListeners();
  }

  bool isPlaying(String key) => _currentKey == key;
}
