import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Owns the plugin callbacks for the lifetime of the app. The speech plugin
/// initializes only once; keeping callbacks here avoids retaining a closed sheet.
class VoiceInputController extends ChangeNotifier {
  VoiceInputController({
    SpeechToText? speech,
    Future<bool> Function()? supportsOnDevice,
  }) : _speech = speech ?? SpeechToText(),
       _supportsOnDevice = supportsOnDevice ?? _nativeOnDeviceSupport;
  final Future<bool> Function() _supportsOnDevice;
  static Future<bool> _nativeOnDeviceSupport() async =>
      await const MethodChannel(
        'judgy/speech',
      ).invokeMethod<bool>('supportsOnDevice') ??
      false;
  static final shared = VoiceInputController();
  final SpeechToText _speech;
  Future<bool>? _initialization;
  List<LocaleName> locales = const [];
  String? systemLocale;
  String transcript = '';
  String? error;
  bool isListening = false;
  bool isStarting = false;
  bool isFinal = false;
  int _session = 0;

  Future<bool> initialize() async {
    final ready = await (_initialization ??= _initialize());
    if (!ready) _initialization = null;
    return ready;
  }

  Future<bool> _initialize() async {
    try {
      final ready = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            isListening = false;
            notifyListeners();
          }
        },
        onError: (failure) {
          isListening = false;
          error = switch (failure.errorMsg) {
            'error_permission' ||
            'error_permission_denied' ||
            'error_audio_error' =>
              'Microphone access is unavailable. Allow it in Android app settings, then try again.',
            'error_no_match' || 'error_speech_timeout' =>
              'No clear speech was heard. Move closer and try a short phrase.',
            'error_network' || 'error_network_timeout' =>
              'The recognizer could not connect. Try on-device recognition or check your connection.',
            'error_language_not_supported' || 'error_language_unavailable' =>
              'This language is unavailable. Install its speech pack or choose another language.',
            _ =>
              'Speech recognition stopped. Check your language and speech pack, then try again.',
          };
          notifyListeners();
        },
      );
      if (!ready) {
        error =
            'Speech recognition is unavailable. Check microphone permission and your installed speech service.';
        return false;
      }
      locales = await _speech.locales();
      systemLocale = (await _speech.systemLocale())?.localeId;
      return true;
    } catch (_) {
      error =
          'Could not start speech recognition. You can still enter the expense manually.';
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> start({required String locale, required bool onDevice}) async {
    if (isStarting || isListening) return;
    final session = ++_session;
    isStarting = true;
    error = null;
    transcript = '';
    isFinal = false;
    notifyListeners();
    try {
      if (!await initialize() || session != _session) return;
      if (onDevice && !await _supportsOnDevice()) {
        error =
            'Strict on-device speech needs Android 12 or newer and an available on-device speech service. Install its language pack, or explicitly turn off on-device mode in Voice options.';
        return;
      }
      if (session != _session) return;
      // Locale IDs come from the installed recognizer, not a hardcoded dialect.
      final selected = locales.any((l) => l.localeId == locale)
          ? locale
          : systemLocale;
      isListening = true;
      notifyListeners();
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: selected,
          onDevice: onDevice,
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        ),
        onResult: (result) {
          if (session != _session) return;
          transcript = result.recognizedWords;
          isFinal = result.finalResult;
          if (isFinal) isListening = false;
          notifyListeners();
        },
      );
      if (session != _session) await _speech.cancel();
    } catch (_) {
      if (session == _session) {
        isListening = false;
        error = onDevice
            ? 'On-device recognition could not start. Install an offline language pack or turn off on-device mode.'
            : 'Speech recognition could not start. Check microphone permission and try again.';
      }
    } finally {
      isStarting = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {
      error = 'Listening stopped. Try again if the transcript is incomplete.';
    }
    isListening = false;
    notifyListeners();
  }

  Future<void> cancel() async {
    _session++;
    isListening = false;
    try {
      await _speech.cancel();
    } catch (_) {
      /* The sheet may close before initialization finishes. */
    }
    notifyListeners();
  }
}
