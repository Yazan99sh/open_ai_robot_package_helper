library open_ai_robot_helper;

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:open_ai_robot_helper/open_ai/open_ai_main.dart';
import 'package:open_ai_robot_helper/open_ai/option.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class OpenAiRobotHelper {
  late OpenAIMain openAIMain;
  late OpenAiOption options;
  List<OpenAIChatCompletionChoiceMessageModel> messages = [];
  late AudioRecorder record;
  late AudioPlayer player;

  Future<void> init(String appKey, String orgID, OpenAiOption opt) async {
    options = opt;
    openAIMain = OpenAIMain();
    await openAIMain.initOpenAIClient(appKey, orgID);
    player = AudioPlayer();
    record = AudioRecorder();
  }

  Timer? timer;
  DateTime startDuration = DateTime.now();
  StreamController<String> controller = StreamController<String>();
  StreamController<String> controllerForAudio = StreamController<String>();

  Stream<String> get getSpeechString => controller.stream;

  List<num> amplitudes = [];

  Future<void> startRecording() async {
    amplitudes = [];
    if (await record.hasPermission()) {
      startDuration = DateTime.now();
      final path = await getApplicationDocumentsDirectory();
      await Directory('${path.path}/recorder').create(recursive: true);
      await record.start(
          const RecordConfig(
            noiseSuppress: true,
          ),
          path: '${path.path}/recorder/speech.m4a');
      timer = Timer.periodic(const Duration(milliseconds: 25), (timer) async {
        Amplitude amplitude = await record.getAmplitude();
        amplitudes.add(amplitude.current);
        if (DateTime.now().difference(startDuration).inSeconds > 15 ||
            _checkAmplitude(amplitudes)) {
          await stopRecording();
          await _transcribe(path);
          await cleanRecording();
        }
        print('amplitude: ${amplitude.current}');
      });
    }
  }

  Future<void> stopRecording() async {
    timer?.cancel();
    await record.stop();
    //await record.dispose();
  }

  Future<void> cleanRecording() async {
    try {
      amplitudes = [];
      await stopRecording();
      final path = await getApplicationDocumentsDirectory();
      // delete directory
      await Directory('${path.path}/recorder').delete(recursive: true);
    } catch (e) {
      print(e);
    }
  }

  void clearUserQuestion() {
    messages.clear();
  }

  Future<String> sendANewMessage(String newMessage) async {
    if (messages.isEmpty) {
      messages.add(OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
              options.character.characterPrompt),
        ],
        role: OpenAIChatMessageRole.system,
      ));
      for (var g in options.guidance)
        messages.add(OpenAIChatCompletionChoiceMessageModel(
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
                g),
          ],
          role: OpenAIChatMessageRole.system,
        ));
    }
    messages.add(OpenAIChatCompletionChoiceMessageModel(
      content: [
        OpenAIChatCompletionChoiceMessageContentItemModel.text(newMessage),
      ],
      role: OpenAIChatMessageRole.user,
    ));
    final result = await openAIMain.sendAQuestionToChatGpt(messages);
    messages.add(OpenAIChatCompletionChoiceMessageModel(
      content: [
        OpenAIChatCompletionChoiceMessageContentItemModel.text(result),
      ],
      role: OpenAIChatMessageRole.assistant,
    ));
    return result;
  }

  Future<void> getSpeechAudio(String text) async {
    final path = await openAIMain.generateSpeechAudio(text);
    await player.play(DeviceFileSource(path));
  }

  _transcribe(Directory path) async {
    if (_isSomeOneSpeaking() == false) {
      controller.add('');
      return;
    }
    try {
      final textResult = await openAIMain
          .convertAudioToText('${path.path}/recorder/speech.m4a');
      controller.add(textResult);
    } catch (e) {
      controller.add('');
    }
  }

  _checkAmplitude(List<num> amplitudes) {
    bool speechFinish = false;
    int index = 0;
    for (var i = 0; i < amplitudes.length - 1; i++) {
      print('amplitude: ${amplitudes[i]} index : $i');
      if (amplitudes[i] >= -5 && amplitudes[i + 1] < -5) {
        speechFinish = true;
        index = i;
      }
    }
    return speechFinish && (amplitudes.length - index) >= 125;
  }

  _isSomeOneSpeaking() {
    int count = 0;
    int maximum = -100;
    for (var i = 0; i < amplitudes.length - 1; i++) {
      print('amplitude: ${amplitudes[i]} index : $i');
      if (amplitudes[i] > -3) {
        count++;
      }
      if (maximum <= amplitudes[i]) {
        maximum = amplitudes[i].toInt();
      }
    }
    var percent = ((count * 100) / amplitudes.length);
    print(
        'count: $count  length: ${amplitudes.length} percent: $percent max: $maximum');
    return count > 0;
  }
  void _addGuiding(String guidance) async {
    options.guidance.add(guidance);
  }
}
