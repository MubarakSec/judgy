import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/services/voice_input_controller.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class FakeSpeech extends SpeechToText {
  FakeSpeech() : super.withMethodChannel();
  Completer<bool>? initialization;
  SpeechErrorListener? errorCallback;
  SpeechStatusListener? statusCallback;
  SpeechResultListener? resultCallback;
  SpeechListenOptions? options;
  int listenCalls = 0;
  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    dynamic debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    errorCallback = onError;
    statusCallback = onStatus;
    return initialization == null ? true : initialization!.future;
  }

  @override
  Future<List<LocaleName>> locales() async => [
    LocaleName('ar_YE', 'Arabic (Yemen)'),
    LocaleName('en_US', 'English'),
  ];
  @override
  Future<LocaleName?> systemLocale() async =>
      LocaleName('ar_YE', 'Arabic (Yemen)');
  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    dynamic cancelOnError = false,
    dynamic partialResults = true,
    dynamic onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    dynamic sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    listenCalls++;
    resultCallback = onResult;
    options = listenOptions;
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<void> stop() async {}
}

void main() {
  test(
    'strict offline mode does not start an unavailable native recognizer',
    () async {
      final speech = FakeSpeech();
      final voice = VoiceInputController(
        speech: speech,
        supportsOnDevice: () async => false,
      );
      await voice.start(locale: '', onDevice: true);
      expect(speech.listenCalls, 0);
      expect(voice.isStarting, isFalse);
      expect(voice.isListening, isFalse);
      expect(voice.error, contains('Android 12'));
    },
  );
  test(
    'explicit online mode and chosen installed language reach the recognizer',
    () async {
      final speech = FakeSpeech();
      final voice = VoiceInputController(
        speech: speech,
        supportsOnDevice: () async => false,
      );
      await voice.start(locale: 'en_US', onDevice: false);
      expect(speech.listenCalls, 1);
      expect(speech.options!.localeId, 'en_US');
      expect(speech.options!.onDevice, isFalse);
      speech.errorCallback!(
        SpeechRecognitionError('error_speech_timeout', false),
      );
      expect(voice.isListening, isFalse);
      expect(voice.error, contains('No clear speech'));
    },
  );
  test(
    'closing a sheet during permission initialization prevents a late microphone start',
    () async {
      final ready = Completer<bool>();
      final speech = FakeSpeech()..initialization = ready;
      final voice = VoiceInputController(
        speech: speech,
        supportsOnDevice: () async => true,
      );
      final starting = voice.start(locale: '', onDevice: true);
      await voice.cancel();
      ready.complete(true);
      await starting;
      expect(speech.listenCalls, 0);
      expect(voice.isListening, isFalse);
      expect(voice.isStarting, isFalse);
    },
  );
  test(
    'late recognition results from a cancelled session are ignored',
    () async {
      final speech = FakeSpeech();
      final voice = VoiceInputController(
        speech: speech,
        supportsOnDevice: () async => true,
      );
      await voice.start(locale: '', onDevice: true);
      expect(speech.options!.localeId, 'ar_YE');
      final result = speech.resultCallback!;
      await voice.cancel();
      result(SpeechRecognitionResult([], 1));
      expect(voice.transcript, isEmpty);
    },
  );
}
