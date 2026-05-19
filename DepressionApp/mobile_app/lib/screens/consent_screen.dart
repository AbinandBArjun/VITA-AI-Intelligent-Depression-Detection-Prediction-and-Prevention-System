import 'package:flutter/material.dart';

class ConsentScreen extends StatelessWidget {

  final VoidCallback onAccept;

  const ConsentScreen({required this.onAccept});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: Text("User Consent"),
      ),

      body: Padding(
        padding: EdgeInsets.all(20),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Text(
              "This app periodically processes temporary camera frames during active app usage for facial emotion analysis, along with phone usage behavior, to estimate depression risk. Images are processed temporarily and are not permanently stored.",
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 40),

            ElevatedButton(
              onPressed: onAccept,
              child: Text("I Agree"),
            )

          ],
        ),
      ),
    );
  }
}