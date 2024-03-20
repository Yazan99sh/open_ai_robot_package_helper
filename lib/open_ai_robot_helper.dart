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
  DateTime silenceDuration = DateTime.now();
  DateTime startDuration = DateTime.now();
  StreamController<String?> controller = StreamController<String>();
  StreamController<String> controllerForAudio = StreamController<String>();

  Stream<String?> get getSpeechString => controller.stream;

  List<num> amplitudes = [];

  Future<void> startRecording() async {
    amplitudes = [];
    if (await record.hasPermission()) {
      startDuration = DateTime.now();
      silenceDuration = DateTime.now();
      final path = await getApplicationDocumentsDirectory();
      await Directory('${path.path}/recorder').create(recursive: true);
      await record.start(const RecordConfig(
        noiseSuppress: true,
      ),
          path: '${path.path}/recorder/speech.m4a');
      timer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        Amplitude amplitude = await record.getAmplitude();
        double valume = (amplitude.current - (-45)) / (-45);
        //print('valume: $valume');
        print('amplitude: ${amplitude.current}');
        amplitudes.add(amplitude.current);
        if (amplitude.current > -15) {
          print('Laoud: ---------------------->');
          silenceDuration = DateTime.now();
        } else {
          print('Quite: ---------------------->');
          if (DateTime.now().difference(silenceDuration).inSeconds > 2 ||
              DateTime.now().difference(startDuration).inSeconds > 10) {
            await stopRecording();
            await _transcribe(path);
            await cleanRecording();
          }
        }
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
          for (var g in options.guidance)
            OpenAIChatCompletionChoiceMessageContentItemModel.text(g),
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
    try {
      final textResult =
      await openAIMain.convertAudioToText('${path.path}/recorder/speech.m4a');
      controller.add(textResult);
    } catch (e) {
      controller.add(null);
    }
  }
}
