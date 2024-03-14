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
  Future<void> init(String appKey, String orgID, OpenAiOption opt) async {
    options = opt;
    openAIMain = OpenAIMain();
    await openAIMain.initOpenAIClient(appKey, orgID);
  }
  Timer? timer;
  DateTime silenceDuration = DateTime.now();
  DateTime startDuration = DateTime.now();
  StreamController<String> controller = StreamController<String>();
  StreamController<String> controllerForAudio = StreamController<String>();

  Stream<String> get getSpeechString => controller.stream;

  Stream<String> get getAudioString => controller.stream;

  Future<void> startRecording() async {
    record = AudioRecorder();
    if (await record.hasPermission()) {
      startDuration = DateTime.now();
      silenceDuration = DateTime.now();
      final path = await getApplicationDocumentsDirectory();
      await Directory('${path.path}/recorder').create(recursive: true);
      await record.start(const RecordConfig(), path: '${path.path}/recorder/speech.m4a');
      timer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        Amplitude amplitude = await record.getAmplitude();
        double valume = (amplitude.current - (-45)) / (-45);
        print('valume: $valume');
        print('amplitude: ${amplitude.current}');
        if (amplitude.current > -10) {
          print('Laoud: ---------------------->');
          silenceDuration = DateTime.now();
          if (DateTime.now().difference(startDuration).inSeconds > 30) {
            await stopRecording();
            final textResult =
                await openAIMain.convertAudioToText('${path.path}/recorder/speech.m4a');
            controller.add(textResult);
            await cleanRecording();
          }
        } else {
          print('Quite: ---------------------->');
          if (DateTime.now().difference(silenceDuration).inSeconds > 3) {
            await stopRecording();
            final textResult =
                await openAIMain.convertAudioToText('${path.path}/recorder/speech.m4a');
            controller.add(textResult);
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
    await stopRecording();
    final path = await getApplicationDocumentsDirectory();
    // delete directory
    await Directory('${path.path}/recorder').delete(recursive: true);
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
    final player = AudioPlayer();
    final path = await openAIMain.generateSpeechAudio(text);
    await player.play(DeviceFileSource(path));
  }
}
