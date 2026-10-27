import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:judgy/services/voice_input_controller.dart';

class FakeRecording implements VoiceRecording {
  FakeRecording({this.result = 'coffee four dollars'});

  String result;
  Object? stopError;
  Completer<String>? blocked;
  bool cancelled = false;
  int stopCalls = 0;
  final speechEnd = StreamController<void>.broadcast();

  @override
  Stream<void> get speechEnded => speechEnd.stream;

  @override
  Future<String> stop() async {
    stopCalls++;
    final pending = blocked;
    String value;
    if (pending != null) {
      value = await pending.future;
    } else if (stopError != null) {
      throw stopError!;
    } else {
      value = result;
    }
    if (!speechEnd.isClosed) await speechEnd.close();
    return value;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (!speechEnd.isClosed) await speechEnd.close();
  }
}

class FakeRecognizer implements VoiceRecognizer {
  int loads = 0;
  int starts = 0;
  String? loadedPath;
  String? language;
  String? prompt;
  Object? loadError;
  Object? startError;
  FakeRecording? recording;
  bool disposed = false;

  @override
  Future<void> load(String modelPath) async {
    loads++;
    loadedPath = modelPath;
    if (loadError != null) throw loadError!;
  }

  @override
  Future<VoiceRecording> start({
    required String language,
    String? initialPrompt,
  }) async {
    starts++;
    this.language = language;
    prompt = initialPrompt;
    if (startError != null) throw startError!;
    return recording = FakeRecording();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  late FakeRecognizer recognizer;
  late VoiceInputController controller;

  setUp(() {
    recognizer = FakeRecognizer();
    controller = VoiceInputController(
      recognizer: recognizer,
      modelPath: () async => '/tmp/ggml-base-q5_1.bin',
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('loads the bundled model and starts recording', () async {
    await controller.start(locale: '', onDevice: false);

    expect(recognizer.loads, 1);
    expect(recognizer.loadedPath, '/tmp/ggml-base-q5_1.bin');
    expect(recognizer.starts, 1);
    expect(controller.isStarting, isFalse);
    expect(controller.isListening, isTrue);
    expect(controller.error, isNull);
  });

  test('normalizes device locales and stops with a transcript', () async {
    await controller.start(locale: 'ar_YE', onDevice: true);
    expect(recognizer.language, 'ar');
    expect(recognizer.prompt, isNotNull);

    await controller.stop();

    expect(controller.isListening, isFalse);
    expect(controller.isTranscribing, isFalse);
    expect(controller.transcript, 'coffee four dollars');
    expect(controller.isFinal, isTrue);
    expect(controller.error, isNull);
  });

  test('uses auto language and no prompt when no locale is set', () async {
    await controller.start(locale: '', onDevice: false);

    expect(recognizer.language, 'auto');
    expect(recognizer.prompt, isNull);
  });

  test('surfaces microphone permission failures', () async {
    recognizer.startError = StateError('Microphone permission was not granted');

    await controller.start(locale: 'en', onDevice: false);

    expect(controller.isListening, isFalse);
    expect(controller.error, contains('Microphone access'));
  });

  test('reports an empty transcript as no speech', () async {
    await controller.start(locale: 'en', onDevice: false);
    recognizer.recording!.result = '  [BLANK_AUDIO]  ';

    await controller.stop();

    expect(controller.transcript, isEmpty);
    expect(controller.isFinal, isFalse);
    expect(controller.error, contains('No clear speech'));
  });

  test('cancel ignores a late transcription result', () async {
    await controller.start(locale: 'en', onDevice: false);
    final recording = recognizer.recording!;
    recording.blocked = Completer<String>();

    final pending = controller.stop();
    await Future<void>.delayed(Duration.zero);
    expect(controller.isTranscribing, isTrue);

    await controller.cancel();
    recording.blocked!.complete('late words');
    await pending;

    expect(controller.transcript, isEmpty);
    expect(controller.error, isNull);
    expect(controller.isTranscribing, isFalse);
    expect(recording.stopCalls, 1);
  });

  test('auto-stops when the speaker goes quiet', () async {
    await controller.start(locale: 'en', onDevice: false);
    final recording = recognizer.recording!;

    recording.speechEnd.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controller.isListening, isFalse);
    expect(controller.transcript, 'coffee four dollars');
    expect(recording.stopCalls, 1);
  });

  test('auto-stops after the maximum recording duration', () async {
    controller = VoiceInputController(
      recognizer: recognizer,
      modelPath: () async => '/tmp/model.bin',
      maxRecording: const Duration(milliseconds: 30),
    );

    await controller.start(locale: 'en', onDevice: false);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(controller.isListening, isFalse);
    expect(controller.transcript, 'coffee four dollars');
  });

  test('retries model loading after a failure', () async {
    recognizer.loadError = StateError('failed to load model');

    await controller.start(locale: 'en', onDevice: false);
    expect(controller.error, contains('offline speech model'));
    expect(recognizer.starts, 0);

    recognizer.loadError = null;
    await controller.start(locale: 'en', onDevice: false);

    expect(recognizer.loads, 2);
    expect(controller.isListening, isTrue);
  });

  test('does not request the microphone when the model is missing', () async {
    controller = VoiceInputController(
      recognizer: recognizer,
      modelPath: () async => throw StateError('model missing'),
    );

    await controller.start(locale: 'en', onDevice: false);

    expect(recognizer.starts, 0);
    expect(controller.isListening, isFalse);
    expect(controller.error, contains('offline speech model'));
  });
}
