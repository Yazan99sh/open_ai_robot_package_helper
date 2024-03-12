library open_ai_robot_helper;

import 'dart:async';
import 'dart:io';

import 'package:open_ai_robot_helper/open_ai/open_ai_main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class OpenAiRobotHelper {
  late OpenAIMain openAIMain;
  late AudioRecorder record;

  Future<void> init(String appKey, String orgID) async {
    openAIMain = OpenAIMain();
    await openAIMain.initOpenAIClient(appKey, orgID);
  }

  Timer? timer;
  DateTime silenceDuration = DateTime.now();
  DateTime startDuration = DateTime.now();
  StreamController<String> controller = StreamController<String>();

  Stream<String> get getSpeechString => controller.stream;

  Future<void> startRecording() async {
    record = AudioRecorder();
    if (await record.hasPermission()) {
      startDuration = DateTime.now();
      silenceDuration = DateTime.now();
      final path = await getApplicationDocumentsDirectory();
      await record.start(const RecordConfig(), path: '${path.path}/speech.m4a');
      timer ??= Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        Amplitude amplitude = await record.getAmplitude();
        double valume = (amplitude.current - (-45) ) / (-45);
        print('valume: $valume');
        print('amplitude: ${amplitude.current}');
        if (amplitude.current > -10) {
          print('Laoud: ---------------------->');
          silenceDuration = DateTime.now();
          if (DateTime.now().difference(startDuration).inSeconds > 60) {
            await stopRecording();
            final textResult =
                await openAIMain.convertAudioToText('${path.path}/speech.m4a');
            controller.add('textResult');
            await cleanRecording(false);
          }
        } else {
          print('Quite: ---------------------->');
          if (DateTime.now().difference(silenceDuration).inSeconds > 10) {
            await stopRecording();
            final textResult =
                await openAIMain.convertAudioToText('${path.path}/speech.m4a');
            controller.add('textResult');
            await cleanRecording(false);
          }
        }
      });
    }
  }

  Future<void> stopRecording() async {
    timer?.cancel();
    await record.stop();
  }

  Future<void> cleanRecording(bool dispose) async {
    await stopRecording();
    if (dispose) {
      await record.dispose();
    }
    final path = await getApplicationDocumentsDirectory();
    // delete directory
    await Directory('${path.path}/speech.m4a').delete(recursive: true);
  }
}
