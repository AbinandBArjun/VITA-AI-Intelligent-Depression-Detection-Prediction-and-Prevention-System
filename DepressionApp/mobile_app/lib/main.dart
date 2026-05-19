import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/consent_screen.dart';
import 'screens/home_screen.dart';

import 'services/permission_service.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  bool accepted = false;

  bool loading = true;

  @override
  void initState() {

    super.initState();

    checkConsent();
  }

  Future<void> checkConsent() async {

    SharedPreferences prefs =
        await SharedPreferences.getInstance();

    bool consent =
        prefs.getBool("user_consent") ?? false;

    if (consent) {

      await PermissionService
          .requestAllPermissions();
    }

    setState(() {

      accepted = consent;

      loading = false;
    });
  }

  Future<void> saveConsent() async {

    SharedPreferences prefs =
        await SharedPreferences.getInstance();

    await prefs.setBool(
      "user_consent",
      true,
    );

    await PermissionService
        .requestAllPermissions();

    setState(() {

      accepted = true;
    });
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {

      return MaterialApp(

        debugShowCheckedModeBanner: false,

        home: Scaffold(

          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      home: accepted

          ? HomeScreen()

          : ConsentScreen(
              onAccept: saveConsent,
            ),
    );
  }
}