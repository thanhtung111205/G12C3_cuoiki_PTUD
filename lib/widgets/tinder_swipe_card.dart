import 'package:flutter/material.dart';

class TinderSwipeCard extends StatelessWidget {
  const TinderSwipeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 300,
        width: 200,
        child: Center(
          child: Text('Tinder Swipe Card'),
        ),
      ),
    );
  }
}