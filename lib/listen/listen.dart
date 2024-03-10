import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:mic_stream/mic_stream.dart';
import 'package:path_provider/path_provider.dart';

enum Command {
  start,
  stop,
  change,
}

int screenWidth = 0;

class ListenToMic {
  Stream<Uint8List>? stream;
  late StreamSubscription listener;
  List<double>? waveSamples;
  List<double>? intensitySamples;
  int sampleIndex = 0;
  double localMax = 0;
  double localMin = 0;
  bool isRecording = false;
  bool memRecordingState = false;
  late bool isActive;
  DateTime? startTime;

  void controlMicStream({Command command = Command.change}) async {
    switch (command) {
      case Command.change:
        _changeListening();
        break;
      case Command.start:
        _startListening();
        break;
      case Command.stop:
        _stopListening();
        break;
    }
  }

  Future<bool> _changeListening() async =>
      !isRecording ? await _startListening() : _stopListening();

  late int bytesPerSample;
  late int samplesPerSecond;
  bool isSpeaking = false;

  Future<bool> _startListening() async {
    if (isRecording) return false;
    // Default option. Set to false to disable request permission dialogue
    MicStream.shouldRequestPermission(true);

    stream = MicStream.microphone(
        audioSource: AudioSource.DEFAULT,
        sampleRate: 48000,
        channelConfig: ChannelConfig.CHANNEL_IN_MONO,
        audioFormat: AudioFormat.ENCODING_PCM_16BIT);
    listener =
        stream!.transform(MicStream.toSampleStream).listen(_processSamples);
    listener.onError(print);
    print(
        "Start listening to the microphone, sample rate is ${await MicStream.sampleRate}, bit depth is ${await MicStream.bitDepth}, bufferSize: ${await MicStream.bufferSize}");

    localMax = 0;
    localMin = 0;

    bytesPerSample = await MicStream.bitDepth ~/ 8;
    samplesPerSecond = await MicStream.sampleRate;
    isRecording = true;
    startTime = DateTime.now();
    return true;
  }

  double silenceThreshold = 25;

  double calculateAverageAmplitude(List<double> samples) {
    double sum = 0.0;
    for (final sample in samples) {
      sum += sample.abs();
    }
    return sum / samples.length;
  }
  DateTime silenceDuration = DateTime.now();
  void _processSamples(_sample) async {
    if (screenWidth == 0) return;

    double sample = 0;
    if ("${_sample.runtimeType}" == "(int, int)" ||
        "${_sample.runtimeType}" == "(double, double)") {
      sample = 0.5 * (_sample.$1 + _sample.$2);
    } else {
      sample = _sample.toDouble();
    }
    waveSamples ??= List.filled(screenWidth, 0);
    final overridden = waveSamples![sampleIndex];
    waveSamples![sampleIndex] = sample;
    sampleIndex = (sampleIndex + 1) % screenWidth;

    if (overridden == localMax) {
      localMax = 0;
      for (final val in waveSamples!) {
        localMax = max(localMax, val);
      }
    } else if (overridden == localMin) {
      localMin = 0;
      for (final val in waveSamples!) {
        localMin = min(localMin, val);
      }
    } else {
      if (sample > 0)
        localMax = max(localMax, sample);
      else
        localMin = min(localMin, sample);
    }
    final double averageAmplitude =
        calculateAverageAmplitude(waveSamples ?? []);
    // Detect silence
    if (averageAmplitude < silenceThreshold) {
      isSpeaking = false; // Assuming you keep track of sample duration
      if (silenceDuration.difference(DateTime.now()).inSeconds > 30) {
        _stopListening(); // Stop recording when silence is long enough

      }
    } else {
      isSpeaking = true;
      silenceDuration = DateTime.now();
    }
  }

  bool _stopListening() {
    if (!isRecording) return false;
    print("Stop listening to the microphone");
    listener.cancel();
    isRecording = false;
    waveSamples = List.filled(screenWidth, 0);
    intensitySamples = List.filled(screenWidth, 0);
    startTime = null;
    return true;
  }
  Future<void> _saveAudioFile(List<int> bytes) async {
    const filename = 'speech.mp3';
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$filename';

    // Use `File.writeAsBytes` to save the WAV file
    await File(filePath).writeAsBytes(bytes);
  }
}
