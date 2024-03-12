import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_ai_robot_helper/open_ai/option.dart';
import 'package:open_ai_robot_helper/open_ai_robot_helper.dart';

final open = OpenAiRobotHelper();

void main() async {
  open.init(
      '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',
      'org-sxjmO2cujjHwd3DMmYATC1T9',
      OpenAiOption(
        character: Character.house,
        guidance: [],
      ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  String text = '';
  String response = '';
  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    open.getSpeechString.listen((event) {
      setState(() {
        isRecording = false;
        text = event;
      });
      sendToGpt();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  sendToGpt() async {
    response = await open.sendANewMessage(text);
    await open.getSpeechAudio(response);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin: mic_stream :: Debug'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            if (isRecording == false) {
              await open.startRecording();
              isRecording = true;
            } else {
              await open.cleanRecording();
              isRecording = false;
            }
            setState(() {});
          },
          tooltip: 'Start Recording',
          child: Icon(isRecording ? Icons.pause : Icons.mic),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                text,
              ),
              Text(
                response,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
