import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/usage_service.dart';
import '../services/api_service.dart';
import '../services/video_emotion_service.dart';

import 'dart:async';
import 'package:camera/camera.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen>
    with WidgetsBindingObserver {

  double phoneScore = 0;

  double emotionScore = 30;

  double unifiedScore = 40;

  double hrvScore = 40;

  double textScore = 50;

  String emotion = "neutral";

  bool loading = true;

  List<double> weeklyScores = [];

  String agenticAI =
      "Seek professional help if score becomes consistently high.";

  bool agenticLoading = false;

  Timer? _emotionTimer;

  CameraDescription? _camera;

  // =========================================================
  // XAI VARIABLES
  // =========================================================

  Map<String, dynamic>? xaiData;

  String captumText = "";

  double fairnessConfidence = 0;

  String fairnessStatement = "";

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {

    super.initState();

    WidgetsBinding.instance
        .addObserver(this);

    initializeApp();
  }

  Future<void> initializeApp() async {

    await loadWeeklyScores();

    await loadTextScore();

    await initPassiveEmotionMonitoring();

    setState(() {

      loading = false;
    });
  }

  // =========================================================
  // APP LIFECYCLE
  // =========================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) async {

    if (state ==
        AppLifecycleState.paused) {

      VideoEmotionService.stop();
    }

    if (state ==
        AppLifecycleState.resumed) {

      if (_camera != null) {

        await VideoEmotionService
            .startContinuous();
      }
    }
  }

  // =========================================================
  // CAMERA + EMOTION
  // =========================================================

  Future<void>
      initPassiveEmotionMonitoring() async {

    try {

      final cameras =
          await availableCameras();

      _camera = cameras.firstWhere(

        (c) =>

            c.lensDirection ==
            CameraLensDirection.front,

        orElse: () => cameras.first,
      );

      await VideoEmotionService
          .init(_camera!);

      await VideoEmotionService
          .startContinuous();

      startEmotionUpdates();

    } catch (e) {

      print("Emotion init error: $e");
    }
  }

  void startEmotionUpdates() {

    _emotionTimer?.cancel();

    _emotionTimer = Timer.periodic(

      Duration(seconds: 30),

      (timer) async {

        await updateLiveScores();
      },
    );
  }

  // =========================================================
  // LIVE UPDATE
  // =========================================================

  Future<void> updateLiveScores() async {

    try {

      if (VideoEmotionService
          .frames
          .isEmpty) {

        return;
      }

      var usage =
          await UsageService.getUsage();

      List<File> frames = [

        VideoEmotionService
            .frames
            .last
      ];

      var result =

          await ApiService
              .getUnifiedScoreWithVideo(

        usage,

        textScore,

        frames,
      );

      setState(() {

        emotionScore =

            (result["emotion_score"] ?? 30)
                .toDouble();

        emotion =

            result["emotion"] ??
                "neutral";

        phoneScore =

            (result["phone_score"] ?? 0)
                .toDouble();

        hrvScore =

            (result["hrv_score"] ?? 40)
                .toDouble();

        unifiedScore =

            (result["unified_score"] ?? 40)
                .toDouble();

        // =====================================================
        // XAI
        // =====================================================

        xaiData = result["xai"];

        captumText =

            result["xai"]["captum"];

        fairnessConfidence =

            (result["xai"]["fairness"]
                    ["fairness_confidence"])
                .toDouble();

        fairnessStatement =

            result["xai"]["fairness"]
                ["statement"];
      });

      await saveDailyScore(
          unifiedScore);

      await loadAgentic();

    } catch (e) {

      print("Live update error: $e");
    }
  }

  // =========================================================
  // TEXT SCORE
  // =========================================================

  Future<void> loadTextScore() async {

    try {

      var igResult =

          await ApiService
              .getInstagramScore(

        'your_instagram_username',
      );

      textScore =

          (igResult['avg_text_score'] ?? 50)
              .toDouble();

      SharedPreferences prefs =

          await SharedPreferences
              .getInstance();

      await prefs.setDouble(

        "text_score",

        textScore,
      );

    } catch (e) {

      SharedPreferences prefs =

          await SharedPreferences
              .getInstance();

      textScore =

          prefs.getDouble(
                "text_score",
              ) ??
              50;

      print("Text score error: $e");
    }
  }

  // =========================================================
  // WEEKLY SCORES
  // =========================================================

  Future<void> loadWeeklyScores() async {

  SharedPreferences prefs =
      await SharedPreferences
          .getInstance();

  List<double> scores = [];

  for (int i = 6; i >= 0; i--) {

    DateTime day =

        DateTime.now()
            .subtract(Duration(days: i));

    String key =

        day
            .toIso8601String()
            .split("T")[0];

    List<String> values =
        prefs.getStringList(key) ?? [];

    if (values.isEmpty) {

      scores.add(0);

    } else {

      List<double> nums =

          values
              .map(
                (e) =>
                    double.tryParse(e) ?? 0,
              )
              .toList();

      double avg =

          nums.reduce((a, b) => a + b) /

          nums.length;

      scores.add(avg);
    }
  }

  setState(() {

    weeklyScores = scores;
  });
}

  Future<void> saveDailyScore(
  double score,
) async {

  SharedPreferences prefs =
      await SharedPreferences
          .getInstance();

  String today =

      DateTime.now()
          .toIso8601String()
          .split("T")[0];

  List<String> existing =

      prefs.getStringList(today) ?? [];

  existing.add(score.toString());

  await prefs.setStringList(
    today,
    existing,
  );

  await loadWeeklyScores();
}

  // =========================================================
  // AGENTIC AI
  // =========================================================

  Future<void> loadAgentic() async {

    try {

      setState(() {

        agenticLoading = true;
      });

      final result =

          await ApiService.getAgentic({

        "unified_score":
            unifiedScore,

        "phone_score":
            phoneScore,

        "emotion":
            emotion,

        "emotion_score":
            emotionScore,

        "hrv_score":
            hrvScore,

        "text_score":
            textScore,
      });

      setState(() {

        agenticAI =

            result["agentic_ai"] ??

            "No advice available";
      });

    } catch (e) {

      print("Agentic AI error: $e");

    } finally {

      setState(() {

        agenticLoading = false;
      });
    }
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {

    WidgetsBinding.instance
        .removeObserver(this);

    _emotionTimer?.cancel();

    VideoEmotionService.dispose();

    super.dispose();
  }

  // =========================================================
  // UI HELPER
  // =========================================================

  Widget buildItem(
    String title,
    dynamic value,
  ) {

    return Padding(

      padding:
          const EdgeInsets.symmetric(
        vertical: 10,
      ),  

      child: Column(

        children: [

          Text(

            title,

            style:
                TextStyle(fontSize: 16),
          ),

          SizedBox(height: 5),

          Text(

            value is num

                ? value.toStringAsFixed(1)

                : value.toString(),

            style: TextStyle(

              fontSize: 22,

              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: Text(
          "Depression Risk Monitor",
        ),
      ),

      body: loading

          ? Center(

              child:
                  CircularProgressIndicator(),
            )

          : Stack(

              children: [

                // =====================================================
                // PASSIVE CAMERA
                // =====================================================

                Positioned(

                  bottom: 10,

                  right: 10,

                  child: SizedBox(

                    width: 120,

                    height: 160,

                    child: Opacity(

                      opacity: 0.15,

                      child: _camera != null &&
                              VideoEmotionService
                                      .controller !=
                                  null

                          ? CameraPreview(

                              VideoEmotionService
                                  .controller!,
                            )

                          : Container(),
                    ),
                  ),
                ),

                // =====================================================
                // MAIN UI
                // =====================================================

                ListView(

                  padding:
                      EdgeInsets.all(16),

                  children: [

                    Container(

                      padding:
                          EdgeInsets.all(14),

                      decoration:
                          BoxDecoration(

                        color:
                            Colors.green.shade50,

                        borderRadius:
                            BorderRadius.circular(
                                12),
                      ),

                      child: Row(

                        children: [

                          Icon(

                            Icons.visibility,

                            color:
                                Colors.green,
                          ),

                          SizedBox(width: 10),

                          Expanded(

                            child: Text(

                              "Passive emotion monitoring active",

                              style: TextStyle(

                                fontSize: 16,

                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),

                    SizedBox(height: 25),

                    Text(

                      "Unified Depression Score",

                      style: TextStyle(

                        fontSize: 22,

                        fontWeight:
                            FontWeight.bold,
                      ),

                      textAlign:
                          TextAlign.center,
                    ),

                    SizedBox(height: 12),

                    Text(

                      "${unifiedScore.toStringAsFixed(1)} / 100",

                      style: TextStyle(

                        fontSize: 42,

                        fontWeight:
                            FontWeight.bold,

                        color:
                            unifiedScore > 70

                                ? Colors.red

                                : Colors.green,
                      ),

                      textAlign:
                          TextAlign.center,
                    ),

                    SizedBox(height: 30),

                    

                    buildItem(
                      "Phone Usage Score",
                      phoneScore,
                    ),

                    buildItem(
                      "Detected Emotion",
                      emotion,
                    ),

                    buildItem(
                      "Emotion Score",
                      emotionScore,
                    ),

                    buildItem(
                      "HRV Score",
                      hrvScore,
                    ),
                    

                    buildItem(
                      "Text Score",
                      textScore,
                    ),

                    SizedBox(height: 30),

                    // =====================================================
                    // VITA AI ASSESSMENT
                    // =====================================================

                    Container(

                      padding: EdgeInsets.all(16),

                      decoration: BoxDecoration(

                        color: Colors.orange.shade50,

                        borderRadius:
                            BorderRadius.circular(14),
                      ),

                      child: Column(

                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [

                          Text(

                            "Vita AI Assessment",

                            style: TextStyle(

                              fontSize: 22,

                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 15),

                          Text(
                            "Phone Usage Contribution: "
                            "${xaiData?["shap"]["Phone Usage"] ?? 0}",
                          ),

                          Text(
                            "Behavior Contribution: "
                            "${xaiData?["shap"]["Behavior"] ?? 0}",
                          ),

                          Text(
                            "Emotion Contribution: "
                            "${xaiData?["shap"]["Emotion"] ?? 0}",
                          ),

                          Text(
                            "HRV Contribution: "
                            "${xaiData?["shap"]["HRV"] ?? 0}",
                          ),

                          Text(
                            "Instagram Contribution: "
                            "${xaiData?["shap"]["Instagram Text"] ?? 0}",
                          ),

                          SizedBox(height: 15),

                          Text(

                            "Facial Analysis:",

                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 5),

                          Text(captumText),

                          SizedBox(height: 15),

                          Text(

                            "Fairness Confidence: "
                            "${fairnessConfidence.toStringAsFixed(1)}%",

                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 5),

                          Text(fairnessStatement),
                        ],
                      ),
                    ),

                    SizedBox(height: 25),

                    // =====================================================
                    // AI ADVICE
                    // =====================================================

                    Container(

                      padding:
                          EdgeInsets.all(16),

                      decoration:
                          BoxDecoration(

                        color:
                            Colors.blue.shade50,

                        borderRadius:
                            BorderRadius.circular(
                                14),
                      ),

                      child: Column(

                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [

                          Row(

                            children: [

                              Icon(

                                Icons.psychology,

                                color:
                                    Colors.blue,
                              ),

                              SizedBox(width: 10),

                              Text(

                                "Vita AI Advice",

                                style: TextStyle(

                                  fontSize: 20,

                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 15),

                          agenticLoading

                              ? Center(

                                  child:
                                      CircularProgressIndicator(),
                                )

                              : Text(

                                  agenticAI,

                                  style: TextStyle(

                                    fontSize: 16,

                                    height: 1.5,
                                  ),
                                ),
                        ],
                      ),
                    ),

                    SizedBox(height: 30),

                    Text(

                      "Mental Wellness Trajectory",

                      style: TextStyle(

                        fontSize: 20,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 10),

                    SizedBox(

                      height: 220,

                      child: LineChart(

                        LineChartData(
                          
                          minY: 0,
                          maxY: 100,
                          
                          gridData:
                              FlGridData(show: true),

                          titlesData: FlTitlesData(

  leftTitles: AxisTitles(

    sideTitles: SideTitles(

      showTitles: true,

      reservedSize: 40,

      interval: 20,

      getTitlesWidget: (value, meta) {

        return Text(

          value.toInt().toString(),

          style: TextStyle(fontSize: 12),
        );
      },
    ),
  ),

  bottomTitles: AxisTitles(

    sideTitles: SideTitles(

      showTitles: true,

      getTitlesWidget: (value, meta) {

        List<String> days = [

          "Mon",

          "Tue",

          "Wed",

          "Thu",

          "Fri",

          "Sat",

          "Sun"
        ];

        int index = value.toInt();

        if (index >= 0 &&
            index < days.length) {

          return Text(

            days[index],

            style: TextStyle(fontSize: 12),
          );
        }

        return Container();
      },
    ),
  ),

  topTitles: AxisTitles(

    sideTitles:
        SideTitles(showTitles: false),
  ),

  rightTitles: AxisTitles(

    sideTitles:
        SideTitles(showTitles: false),
  ),
),

                          borderData:
                              FlBorderData(show: true),

                          lineBarsData: [

                            LineChartBarData(

                              spots:
                                  weeklyScores
                                      .asMap()
                                      .entries
                                      .map(

                                        (e) => FlSpot(

                                          e.key.toDouble(),

                                          e.value,
                                        ),
                                      )
                                      .toList(),

                              isCurved: true,

                              color: Colors.blue,

                              barWidth: 3,

                              belowBarData:
                                  BarAreaData(

                                show: true,

                                color:
                                    Colors.blue
                                        .withOpacity(
                                            0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 25),


                    SizedBox(height: 30),
                  ],
                ),
              ],
            ),
    );
  }
} 