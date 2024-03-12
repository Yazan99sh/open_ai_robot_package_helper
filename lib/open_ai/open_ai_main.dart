import 'dart:io';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/foundation.dart';

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
      responseFormat: OpenAIAudioResponseFormat.json,
    );
    return result.text;
  }
}
