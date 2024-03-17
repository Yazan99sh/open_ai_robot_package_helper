import 'dart:io';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class OpenAIMain {
  Future<void> initOpenAIClient(String appKey, String organizationId) async {
    OpenAI.apiKey = appKey;
    OpenAI.organization = organizationId;
    OpenAI.requestsTimeOut = const Duration(seconds: 120);
    if (kDebugMode) {
      OpenAI.showLogs = true;
      OpenAI.showResponsesLogs = true;
    }
  }

  Future<String> convertAudioToText(String audioPath) async {
    final result = await OpenAI.instance.audio.createTranscription(
      file: File(audioPath),
      model: 'whisper-1',
      prompt: 'Fucos on the higher pitch and ignore the rest , and then detect that language and response with right character focus on arabic and english ',
      responseFormat: OpenAIAudioResponseFormat.json,
    );
    return result.text;
  }

  Future<String> sendAQuestionToChatGpt(messages) async {
    OpenAIChatCompletionModel chatCompletion =
        await OpenAI.instance.chat.create(
      model: "gpt-3.5-turbo",
      messages: messages,
    );
    return chatCompletion.choices.first.message.content?.first.text ??
        'Sorry I can not answer';
  }

  Future<String> generateSpeechAudio(String text) async {
    final Directory path = await getApplicationDocumentsDirectory();
    File speechFile = await OpenAI.instance.audio.createSpeech(
      model: "tts-1",
      input: text,
      voice: "alloy",
      responseFormat: OpenAIAudioSpeechResponseFormat.mp3,
      outputDirectory: await Directory('${path.path}/speech').create(),
      outputFileName: "s",
    );
    return speechFile.path;
  }
}
