import 'package:usage_stats/usage_stats.dart';

class UsageService {

  static const List<String> socialApps = [

    'com.instagram.android',
    'com.facebook.katana',
    'com.whatsapp',
    'com.google.android.youtube',
    'com.twitter.android',
    'com.snapchat.android',
    'com.zhiliaoapp.musically',

  ];

  static Future<Map<String, dynamic>> getUsage() async {

    DateTime endDate = DateTime.now();

    DateTime startDate =
        endDate.subtract(Duration(hours: 24));

    List<UsageInfo> usageStats =
        await UsageStats.queryUsageStats(
      startDate,
      endDate,
    );

    double totalUsage = 0;

    double socialUsage = 0;

    double nightUsage = 0;

    int unlockEstimate = 0;

    List<Map<String, dynamic>> topApps = [];

    for (var stat in usageStats) {

      if (stat.totalTimeInForeground == null) {
        continue;
      }

      int timeMs =
          int.tryParse(stat.totalTimeInForeground!) ?? 0;

      double hours =
          timeMs / (1000 * 60 * 60);

      totalUsage += hours;

      // =====================================
      // SOCIAL MEDIA USAGE
      // =====================================

      if (socialApps.contains(stat.packageName)) {

        socialUsage += hours;
      }

      // =====================================
      // TOP APPS
      // =====================================

      if (hours > 0.05) {

        topApps.add({

          "package": stat.packageName,

          "hours": hours,
        });
      }

      // =====================================
      // UNLOCK ESTIMATION
      // =====================================

      if (hours > 0.01) {

        unlockEstimate +=
            (hours * 8).toInt();
      }
    }

    // =====================================
    // NIGHT USAGE
    // =====================================

    DateTime nightStart = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      0,
      0,
    );

    DateTime nightEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      5,
      0,
    );

    List<UsageInfo> nightStats =
        await UsageStats.queryUsageStats(
      nightStart,
      nightEnd,
    );

    for (var stat in nightStats) {

      if (stat.totalTimeInForeground != null) {

        int timeMs =
            int.tryParse(
                  stat.totalTimeInForeground!,
                ) ??
                0;

        nightUsage +=
            timeMs / (1000 * 60 * 60);
      }
    }

    // =====================================
    // SORT TOP APPS
    // =====================================

    topApps.sort(
      (a, b) =>
          b['hours'].compareTo(a['hours']),
    );

    // =====================================
    // LIMIT TOP APPS
    // =====================================

    if (topApps.length > 5) {

      topApps = topApps.sublist(0, 5);
    }

    return {

      "screen_time":
          totalUsage,

      "night_usage":
          nightUsage,

      "social_media_hours":
          socialUsage,

      "unlock_count":
          unlockEstimate,

      "top_apps":
          topApps,
    };
  }
}