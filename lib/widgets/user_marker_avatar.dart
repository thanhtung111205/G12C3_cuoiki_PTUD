import 'package:flutter/material.dart';

class UserMarkerAvatar extends StatelessWidget {
  const UserMarkerAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      child: Icon(Icons.person),
    );
  }
}