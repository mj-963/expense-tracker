import 'package:flutter/material.dart';

class EmptyScreen extends StatelessWidget {
  final String bodyText;
  const EmptyScreen({super.key, this.bodyText = 'Empty Screen'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Placeholder')),
      body: Center(child: Text(bodyText)),
    );
  }
}
