import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

/// A language the bundled recognizer can be pinned to.
class VoiceLanguage {
  const VoiceLanguage(this.id, this.name);
  final String id;
  final String name;
}

/// The small surface the controller needs from a speech engine. Keeping this
/// separate makes the voice flow testable without loading native code.
abstract interface class VoiceRecognizer {
  Future<void> load(String modelPath);

  Future<VoiceRecording> start({
    required String language,
    String? initialPrompt,
  });

  Future<void> dispose();
}

/// One active microphone recording. [stop] finalizes the recording and
/// resolves with its transcript; [cancel] discards it. [speechEnded] fires
/// once the speaker has been quiet long enough to finish the turn.
abstract interface class VoiceRecording {
  Stream<void> get speechEnded;
  Future<String> stop();
  Future<void> cancel();
}

/// Owns the offline recognition session for the lifetime of the app.
///
/// The bundled Whisper model is loaded once, then each voice entry records
/// microphone audio and transcribes it locally. No audio leaves the phone and
/// no system speech service is required.
class VoiceInputController extends ChangeNotifier {
  VoiceInputController({
    VoiceRecognizer? recognizer,
    Future<String> Function()? modelPath,
    this.loadTimeout = const Duration(seconds: 45),
    this.maxRecording = const Duration(seconds: 20),
  }) : _recognizer = recognizer ?? WhisperVoiceRecognizer(),
       _modelPath = modelPath ?? WhisperModelStore.instance.path;

  /// Languages exposed in the voice options. Whisper itself supports more,
  /// but these match the entry parser and keep the UI focused.
  static const languages = <VoiceLanguage>[
    VoiceLanguage('ar', 'Arabic'),
    VoiceLanguage('en', 'English'),
    VoiceLanguage('', 'Auto detect (experimental)'),
  ];

  static final shared = VoiceInputController();

  final VoiceRecognizer _recognizer;
  final Future<String> Function() _modelPath;
  final Duration loadTimeout;
  final Duration maxRecording;

  Future<bool>? _loading;
  VoiceRecording? _recording;
  StreamSubscription<void>? _speechEndSub;
  Timer? _maxTimer;
  int _session = 0;

  String transcript = '';
  String? error;
  bool isStarting = false;
  bool isListening = false;
  bool isTranscribing = false;
  bool isFinal = false;

  Future<bool> initialize() async {
    final ready = await (_loading ??= _load());
    if (!ready) _loading = null;
    return ready;
  }

  Future<bool> _load() async {
    try {
      final path = await _modelPath();
      await _recognizer.load(path).timeout(loadTimeout);
      return true;
    } on TimeoutException {
      error =
          'The offline speech model took too long to load. Close voice entry and try again.';
      return false;
    } catch (failure) {
      if (kDebugMode) debugPrint('Voice model load failed: $failure');
      error =
          'The offline speech model could not start. Reinstall the app or restore the model file, then try again.';
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> start({required String locale, required bool onDevice}) async {
    if (isStarting || isListening || isTranscribing) return;
    final session = ++_session;
    isStarting = true;
    error = null;
    transcript = '';
    isFinal = false;
    notifyListeners();
    try {
      if (!await initialize() || session != _session) return;
      final language = _languageCode(locale);
      final recording = await _recognizer.start(
        language: language,
        initialPrompt: _promptFor(language),
      );
      if (session != _session) {
        await recording.cancel();
        return;
      }
      _recording = recording;
      isListening = true;
      _speechEndSub = recording.speechEnded.listen((_) {
        if (session == _session && isListening) unawaited(stop());
      });
      _maxTimer = Timer(maxRecording, () {
        if (session == _session) unawaited(stop());
      });
    } catch (failure) {
      if (session == _session) {
        error = _messageFor(failure);
        isListening = false;
      }
    } finally {
      if (session == _session) {
        isStarting = false;
        notifyListeners();
      }
    }
  }

  Future<void> stop() async {
    final recording = _recording;
    if (recording == null || !isListening) return;
    final session = _session;
    _maxTimer?.cancel();
    _maxTimer = null;
    _speechEndSub?.cancel();
    _speechEndSub = null;
    _recording = null;
    isListening = false;
    isTranscribing = true;
    notifyListeners();
    try {
      final text = _clean(await recording.stop());
      if (session != _session) return;
      transcript = text;
      isFinal = text.isNotEmpty;
      if (text.isEmpty) {
        error =
            'No clear speech was heard. Move closer and try a short phrase.';
      }
    } catch (failure) {
      if (session == _session) error = _messageFor(failure);
    } finally {
      if (session == _session) {
        isTranscribing = false;
        notifyListeners();
      }
    }
  }

  Future<void> cancel() async {
    _session++;
    _maxTimer?.cancel();
    _maxTimer = null;
    _speechEndSub?.cancel();
    _speechEndSub = null;
    final recording = _recording;
    _recording = null;
    isStarting = false;
    isListening = false;
    isTranscribing = false;
    notifyListeners();
    try {
      await recording?.cancel();
    } catch (_) {
      // The sheet may close while the native recorder is still starting.
    }
  }

  @override
  void dispose() {
    _maxTimer?.cancel();
    _speechEndSub?.cancel();
    _speechEndSub = null;
    final recording = _recording;
    _recording = null;
    unawaited(recording?.cancel());
    unawaited(_recognizer.dispose());
    super.dispose();
  }

  static String _languageCode(String locale) {
    final normalized = locale.trim().toLowerCase().replaceAll('-', '_');
    if (normalized.isEmpty) return 'auto';
    final primary = normalized.split('_').first;
    return RegExp(r'^[a-z]{2,3}$').hasMatch(primary) ? primary : 'auto';
  }

  static String? _promptFor(String language) => switch (language) {
    'ar' =>
      'قهوة، غداء، عشاء، بقالة، مواصلات، تسوق، إيجار، فاتورة، ريال يمني، دولار، عشرين، خمسين، مئة.',
    'en' =>
      'Expense entry. Coffee, lunch, dinner, groceries, transport, shopping, rent, bill, Yemeni riyal, US dollar, twenty, fifty, one hundred.',
    _ => null,
  };

  static String _clean(String value) {
    var text = value
        .replaceAll(
          RegExp(
            r'\[(?:blank_audio|music|noise|applause|laughter|sound|silence)\]',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    text = text.replaceAll(RegExp(r'^[\s.,;:!?-]+|[\s.,;:!?-]+$'), '').trim();
    return text;
  }

  static String _messageFor(Object failure) {
    final message = failure.toString().toLowerCase();
    if (message.contains('permission')) {
      return 'Microphone access is unavailable. Allow it in Android app settings, then try again.';
    }
    if (message.contains('model') ||
        message.contains('load') ||
        message.contains('context')) {
      return 'The offline speech model could not start. Reinstall the app or restore the model file, then try again.';
    }
    return 'Speech recognition stopped. Try again.';
  }
}

/// Resolves the bundled Whisper model to a readable file path, copying it out
/// of the APK once on first use.
class WhisperModelStore {
  WhisperModelStore._();
  static final instance = WhisperModelStore._();

  static const assetPath = 'assets/models/whisper/ggml-base-q5_1.bin';
  static const fileName = 'ggml-base-q5_1.bin';
  static const _expectedBytes = 59707625;

  Future<String>? _path;

  Future<String> path() => _path ??= _prepare();

  Future<String> _prepare() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/whisper');
    final file = File('${directory.path}/$fileName');
    if (await file.exists() && await file.length() == _expectedBytes) {
      return file.path;
    }
    final data = await rootBundle.load(assetPath);
    await directory.create(recursive: true);
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return file.path;
  }
}

/// whisper.cpp implementation of [VoiceRecognizer]. The model stays loaded so
/// repeated entries do not pay the model-loading cost again.
class WhisperVoiceRecognizer implements VoiceRecognizer {
  WhisperEngine? _engine;
  Future<WhisperEngine>? _loading;

  @override
  Future<void> load(String modelPath) async {
    _loading ??= WhisperEngine.load(
      modelPath,
      config: const WhisperConfig(
        backend: WhisperBackend.cpu,
        useFlashAttention: true,
      ),
    );
    try {
      _engine = await _loading!;
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  @override
  Future<VoiceRecording> start({
    required String language,
    String? initialPrompt,
  }) async {
    final engine = _engine;
    if (engine == null) {
      throw const WhisperException('The speech model is not loaded');
    }
    if (kDebugMode || kProfileMode) {
      debugPrint('Voice language: $language');
    }
    final recorder = WhisperRecorder();
    if (!await recorder.requestPermission()) {
      throw const WhisperException('Microphone permission was not granted');
    }
    final audio = await recorder.start(
      sampleRate: 16000,
      chunkMilliseconds: 100,
    );
    return _WhisperRecording(
      engine,
      recorder,
      audio,
      TranscribeOptions(
        language: language,
        threads: 4,
        initialPrompt: initialPrompt,
        tokenTimestamps: false,
        noTimestamps: true,
        noContext: true,
        suppressNonSpeechTokens: false,
        greedyBestOf: 1,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    _loading = null;
    try {
      engine?.dispose();
    } catch (_) {
      // A transcription may still be unwinding; the process is exiting.
    }
  }
}

class _WhisperRecording implements VoiceRecording {
  _WhisperRecording(
    this._engine,
    this._recorder,
    Stream<RecordingChunk> audio,
    this._options,
  ) {
    _subscription = audio.listen(
      (chunk) {
        if (chunk.samples.isEmpty) return;
        final samples = Float32List.fromList(chunk.samples);
        _chunks.add(samples);
        _length += samples.length;
        _onLevel(_rms(samples), samples.length);
      },
      onError: (Object failure, StackTrace stackTrace) {
        _failure = failure;
        if (!_done.isCompleted) _done.complete();
      },
      onDone: () {
        if (!_done.isCompleted) _done.complete();
      },
      cancelOnError: false,
    );
  }

  final WhisperEngine _engine;
  final WhisperRecorder _recorder;
  final TranscribeOptions _options;
  final _chunks = <Float32List>[];
  final _done = Completer<void>();
  final _speechEnded = StreamController<void>.broadcast();
  StreamSubscription<RecordingChunk>? _subscription;
  WhisperTask? _task;
  Object? _failure;
  int _length = 0;
  int _quietRun = 0;
  int _silenceRun = 0;
  bool _heardSpeech = false;
  bool _notifiedSpeechEnd = false;
  bool _stopped = false;
  bool _cancelled = false;

  @override
  Stream<void> get speechEnded => _speechEnded.stream;

  @override
  Future<String> stop() async {
    if (_stopped) throw StateError('This recording has already stopped');
    _stopped = true;
    await _stopRecorder();
    await _done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
    await _subscription?.cancel();
    if (_cancelled) return '';
    if (_failure != null) throw _failure!;
    final samples = _trimSilence(_concatenate());
    if (kDebugMode || kProfileMode) {
      debugPrint(
        'Voice capture: ${(_length / 16000).toStringAsFixed(1)}s raw, '
        '${(samples.length / 16000).toStringAsFixed(1)}s speech',
      );
    }
    // Shorter than 100 ms is almost certainly a tap or room noise.
    if (samples.length < 1600) return '';
    if (kDebugMode || kProfileMode) unawaited(_saveDebugWav(samples));
    final audioContext = _audioContextFor(samples.length);
    if (kDebugMode || kProfileMode) {
      debugPrint('Voice decoder context: $audioContext tokens');
    }
    final options = _options.copyWith(audioContext: audioContext);
    final watch = Stopwatch()..start();
    _task = _engine.transcribe(samples, options: options);
    try {
      var result = await _task!.result;
      if (kDebugMode || kProfileMode) {
        debugPrint(
          'Voice transcription: ${watch.elapsedMilliseconds} ms '
          'for ${(samples.length / 16000).toStringAsFixed(1)}s, '
          'language ${result.language} '
          '(${(result.languageProbability * 100).round()}%)',
        );
      }
      if (_cancelled) return '';
      if (_options.language == 'auto' && _needsArabicRetry(result)) {
        if (kDebugMode || kProfileMode) {
          debugPrint('Voice auto language looked unreliable; retrying Arabic');
        }
        final retry = _engine.transcribe(
          samples,
          options: options.copyWith(
            language: 'ar',
            initialPrompt: VoiceInputController._promptFor('ar'),
          ),
        );
        _task = retry;
        final arabic = await retry.result;
        if (!_cancelled && arabic.text.trim().isNotEmpty) result = arabic;
      }
      if (kDebugMode || kProfileMode) {
        debugPrint('Voice total: ${watch.elapsedMilliseconds} ms');
      }
      return result.text;
    } finally {
      _task = null;
    }
  }

  static bool _needsArabicRetry(WhisperResult result) {
    final language = result.language.toLowerCase();
    if (language != 'ar' && language != 'en') return true;
    return result.languageProbability >= 0 && result.languageProbability < 0.45;
  }

  @override
  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    _task?.cancel();
    if (_stopped) return;
    _stopped = true;
    await _subscription?.cancel();
    await _stopRecorder();
  }

  Future<void> _stopRecorder() async {
    try {
      await _recorder.stop().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Keep whatever audio arrived before the recorder stopped.
    } finally {
      _closeSpeechEnd();
    }
  }

  void _onLevel(double rms, int length) {
    if (_notifiedSpeechEnd) return;
    if (rms >= _speechRms) {
      _heardSpeech = true;
      _quietRun = 0;
      _silenceRun = 0;
      return;
    }
    if (!_heardSpeech) {
      _quietRun += length;
      if (_quietRun >= _noSpeechSamples) _notifySpeechEnd();
      return;
    }
    _silenceRun += length;
    if (_silenceRun >= _silenceSamples) _notifySpeechEnd();
  }

  void _notifySpeechEnd() {
    _notifiedSpeechEnd = true;
    if (!_speechEnded.isClosed) _speechEnded.add(null);
  }

  void _closeSpeechEnd() {
    if (!_speechEnded.isClosed) unawaited(_speechEnded.close());
  }

  static double _rms(Float32List samples) {
    var energy = 0.0;
    for (final sample in samples) {
      energy += sample * sample;
    }
    return samples.isEmpty ? 0 : math.sqrt(energy / samples.length);
  }

  static const _speechRms = 0.012;
  static const _silenceSamples = 16000 * 12 ~/ 10; // 1.2 s
  static const _noSpeechSamples = 16000 * 10; // 10 s

  /// Whisper always pads audio to 30 seconds, so keep the decoder context just
  /// large enough for the captured speech. This is the biggest speed win for
  /// short expense phrases.
  static int _audioContextFor(int samples) {
    final tokens = ((samples / 16000 + 2) * 50).ceil();
    final rounded = ((tokens + 63) ~/ 64) * 64;
    return rounded.clamp(256, 1500);
  }

  Future<void> _saveDebugWav(Float32List samples) async {
    try {
      final directory =
          await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/judgy-last-voice.wav');
      await file.writeAsBytes(_wavBytes(samples));
      debugPrint('Voice debug WAV: ${file.path}');
    } catch (failure) {
      debugPrint('Voice debug WAV failed: $failure');
    }
  }

  static Uint8List _wavBytes(Float32List samples) {
    const sampleRate = 16000;
    const bytesPerSample = 2;
    final data = ByteData(44 + samples.length * bytesPerSample);

    void ascii(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        data.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    ascii(0, 'RIFF');
    data.setUint32(4, 36 + samples.length * bytesPerSample, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * bytesPerSample, Endian.little);
    data.setUint16(32, bytesPerSample, Endian.little);
    data.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    data.setUint32(40, samples.length * bytesPerSample, Endian.little);
    for (var index = 0; index < samples.length; index++) {
      final value = samples[index].clamp(-1.0, 1.0);
      data.setInt16(
        44 + index * bytesPerSample,
        (value * 32767).round(),
        Endian.little,
      );
    }
    return data.buffer.asUint8List();
  }

  Float32List _concatenate() {
    final samples = Float32List(_length);
    var offset = 0;
    for (final chunk in _chunks) {
      samples.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return samples;
  }

  /// Trims leading and trailing room noise using 20 ms RMS windows, leaving a
  /// short pad around detected speech. This keeps Whisper from hallucinating
  /// text over the silence that follows the user's phrase.
  static Float32List _trimSilence(Float32List samples) {
    const window = 320; // 20 ms at 16 kHz
    const threshold = 0.008;
    const pad = 1600; // 100 ms
    var first = -1;
    var last = -1;
    for (var start = 0; start < samples.length; start += window) {
      final end = math.min(start + window, samples.length);
      var energy = 0.0;
      for (var index = start; index < end; index++) {
        energy += samples[index] * samples[index];
      }
      final rms = math.sqrt(energy / (end - start));
      if (rms >= threshold) {
        first = first < 0 ? start : first;
        last = end;
      }
    }
    if (first < 0) return Float32List(0);
    final start = math.max(0, first - pad);
    final end = math.min(samples.length, last + pad);
    return Float32List.sublistView(samples, start, end);
  }
}
