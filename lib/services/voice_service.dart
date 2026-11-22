import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceState { idle, listening, speaking, error }

class VoiceService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  VoiceState _state = VoiceState.idle;
  String _recognizedText = '';
  String? _errorMessage;
  bool _isAvailable = false;
  double _speechRate = 0.5;
  double _pitch = 1.0;

  VoiceState get state => _state;
  String get recognizedText => _recognizedText;
  String? get errorMessage => _errorMessage;
  bool get isAvailable => _isAvailable;
  bool get isListening => _state == VoiceState.listening;
  bool get isSpeaking => _state == VoiceState.speaking;

  VoiceService() {
    _init();
  }

  Future<void> _init() async {
    _isAvailable = await _speech.initialize(
      onError: (error) {
        _errorMessage = error.errorMsg;
        _state = VoiceState.error;
        notifyListeners();
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_state == VoiceState.listening) {
            _state = VoiceState.idle;
            notifyListeners();
          }
        }
      },
    );

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(_pitch);

    _tts.setStartHandler(() {
      _state = VoiceState.speaking;
      notifyListeners();
    });

    _tts.setCompletionHandler(() {
      _state = VoiceState.idle;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      _errorMessage = msg;
      _state = VoiceState.error;
      notifyListeners();
    });

    notifyListeners();
  }

  Future<void> startListening() async {
    if (!_isAvailable) return;
    _recognizedText = '';
    _state = VoiceState.listening;
    _errorMessage = null;
    notifyListeners();

    await _speech.listen(
      onResult: (result) {
        _recognizedText = result.recognizedWords;
        notifyListeners();
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      localeId: 'en_US',
      cancelOnError: true,
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _state = VoiceState.idle;
    notifyListeners();
  }

  Future<void> cancelListening() async {
    await _speech.cancel();
    _recognizedText = '';
    _state = VoiceState.idle;
    notifyListeners();
  }

  void clearRecognizedText() {
    _recognizedText = '';
    notifyListeners();
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    _recognizedText = '';
    _state = VoiceState.speaking;
    await _speech.stop();
    notifyListeners();
    await _tts.speak(text);
  }

  Future<void> speakStepByStep(List<String> steps, {int startIndex = 0}) async {
    for (int i = startIndex; i < steps.length; i++) {
      if (_state == VoiceState.idle || _state == VoiceState.speaking) {
        await _tts.speak('Step ${i + 1}: ${steps[i]}');
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        break;
      }
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _state = VoiceState.idle;
    notifyListeners();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _tts.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    await _tts.setPitch(pitch);
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}

class CookingVoiceController {
  final VoiceService _voice;
  final List<String> _steps;
  int _currentStep = 0;
  bool _isActive = false;

  CookingVoiceController(this._voice, this._steps);

  int get currentStep => _currentStep;
  bool get isActive => _isActive;
  bool get isLastStep => _currentStep >= _steps.length - 1;
  String get currentStepText =>
      _currentStep < _steps.length ? _steps[_currentStep] : '';

  Future<void> startCookingMode() async {
    _isActive = true;
    _currentStep = 0;
    await _readCurrentStep();
  }

  Future<void> nextStep() async {
    if (_currentStep < _steps.length - 1) {
      _currentStep++;
      await _readCurrentStep();
    }
  }

  Future<void> previousStep() async {
    if (_currentStep > 0) {
      _currentStep--;
      await _readCurrentStep();
    }
  }

  Future<void> repeatStep() async {
    await _readCurrentStep();
  }

  Future<void> _readCurrentStep() async {
    if (_currentStep < _steps.length) {
      await _voice.speak(
        'Step ${_currentStep + 1}: ${_steps[_currentStep]}'
      );
    }
  }

  Future<void> stopCookingMode() async {
    _isActive = false;
    await _voice.stopSpeaking();
  }
}
