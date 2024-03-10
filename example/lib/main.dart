import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_ai_robot_helper/listen/listen.dart';
import 'package:open_ai_robot_helper/open_ai_robot_helper.dart';

void main() async {
  final open = OpenAiRobotHelper();
  open.init('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',
      'org-sxjmO2cujjHwd3DMmYATC1T9');
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
  final listenToMic = ListenToMic();
  int page = 0;
  late AnimationController controller;
  Color _iconColor = Colors.white;

  Color _getBgColor() => (listenToMic.isRecording) ? Colors.red : Colors.cyan;

  Icon _getIcon() =>
      (listenToMic.isRecording) ? Icon(Icons.stop) : Icon(Icons.keyboard_voice);

  @override
  void initState() {
    print("Init application");
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setState(() {
      initPlatformState();
    });
  }

  Future<void> initPlatformState() async {
    if (!mounted) return;
    listenToMic.isActive = true;

    Statistics(false);

    controller =
        AnimationController(duration: Duration(seconds: 1), vsync: this)
          ..addListener(() {
            if (listenToMic.isRecording) setState(() {});
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed)
              controller.reverse();
            else if (status == AnimationStatus.dismissed) controller.forward();
          })
          ..forward();
  }

  void _controlPage(int index) => setState(() => page = index);

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Plugin: mic_stream :: Debug'),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              listenToMic.controlMicStream();
              setState(() {
              });
            },
            child: _getIcon(),
            foregroundColor: _iconColor,
            backgroundColor: _getBgColor(),
            tooltip: (listenToMic.isRecording)
                ? "Stop recording"
                : "Start recording",
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.broken_image),
                label: "Sound Wave",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.broken_image),
                label: "Intensity Wave",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.view_list),
                label: "Statistics",
              )
            ],
            backgroundColor: Colors.black26,
            elevation: 20,
            currentIndex: page,
            onTap: _controlPage,
          ),
          body: (page == 0 || page == 1)
              ? CustomPaint(
                  painter: page == 0
                      ? WavePainter(
                          samples: listenToMic.waveSamples,
                          color: _getBgColor(),
                          index: listenToMic.sampleIndex,
                          localMax: listenToMic.localMax,
                          localMin: listenToMic.localMin,
                          context: context,
                        )
                      : IntensityPainter(
                          samples: listenToMic.intensitySamples,
                          color: _getBgColor(),
                          index: listenToMic.sampleIndex,
                          localMax: listenToMic.localMax,
                          localMin: listenToMic.localMin,
                          context: context,
                        ))
              : Statistics(
                  listenToMic.isRecording,
                  startTime: listenToMic.startTime,
                )),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      listenToMic.isActive = true;
      print("Resume app");

      listenToMic.controlMicStream(
          command:
              listenToMic.memRecordingState ? Command.start : Command.stop);
    } else if (listenToMic.isActive) {
      listenToMic.memRecordingState = listenToMic.isRecording;
      listenToMic.controlMicStream(command: Command.stop);

      print("Pause app");
      listenToMic.isActive = false;
    }
  }

  @override
  void dispose() {
    listenToMic.listener.cancel();
    controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class WavePainter extends CustomPainter {
  int? index;
  double? localMax;
  double? localMin;
  List<double>? samples;
  late List<Offset> points;
  Color? color;
  BuildContext? context;
  Size? size;

  WavePainter(
      {this.samples,
      this.color,
      this.context,
      this.index,
      this.localMax,
      this.localMin});

  @override
  void paint(Canvas canvas, Size? size) {
    this.size = context!.size;
    size = this.size;
    if (size == null) return;
    screenWidth = size.width.toInt();

    Paint paint = new Paint()
      ..color = color!
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    samples ??= List.filled(screenWidth, 0);
    index ??= 0;
    points = toPoints(samples!, index!);

    Path path = new Path();
    path.addPolygon(points, false);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldPainting) => true;

  // Maps a list of ints and their indices to a list of points on a cartesian grid
  List<Offset> toPoints(List<double> samples, int index) {
    List<Offset> points = [];
    double totalMax = max(-1 * localMin!, localMax!);
    double maxHeight = 0.5 * size!.height;
    for (int i = 0; i < screenWidth; i++) {
      double height = maxHeight +
          ((totalMax == 0 || index == 0)
              ? 0
              : (samples[(i + index) % index] / totalMax * maxHeight));
      var point = Offset(i.toDouble(), height);
      points.add(point);
    }
    return points;
  }
}

class IntensityPainter extends CustomPainter {
  int? index;
  double? localMax;
  double? localMin;
  List<double>? samples;
  late List<Offset> points;
  Color? color;
  BuildContext? context;
  Size? size;

  IntensityPainter(
      {this.samples,
      this.color,
      this.context,
      this.index,
      this.localMax,
      this.localMin});

  @override
  void paint(Canvas canvas, Size? size) {}

  @override
  bool shouldRepaint(CustomPainter oldPainting) => true;

  // Maps a list of ints and their indices to a list of points on a cartesian grid
  List<Offset> toPoints(List<int>? samples) {
    return points;
  }

  double project(double val, double max, double height) {
    if (max == 0) {
      return 0.5 * height;
    }
    var rv = val / max * 0.5 * height;
    return rv;
  }
}

class Statistics extends StatelessWidget {
  final bool isRecording;
  final DateTime? startTime;

  final String url = "https://github.com/anarchuser/mic_stream";

  Statistics(this.isRecording, {this.startTime});

  @override
  Widget build(BuildContext context) {
    return ListView(children: <Widget>[
      ListTile(
          leading: Icon(Icons.title),
          title: Text("Microphone Streaming Example App")),
      ListTile(
        leading: Icon(Icons.keyboard_voice),
        title: Text((isRecording ? "Recording" : "Not recording")),
      ),
      ListTile(
          leading: Icon(Icons.access_time),
          title: Text((isRecording
              ? DateTime.now().difference(startTime!).toString()
              : "Not recording"))),
    ]);
  }
}

Iterable<T> eachWithIndex<E, T>(
    Iterable<T> items, E Function(int index, T item) f) {
  var index = 0;

  for (final item in items) {
    f(index, item);
    index = index + 1;
  }

  return items;
}
