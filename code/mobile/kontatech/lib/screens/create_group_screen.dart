import 'package:flutter/material.dart';

class CreateGroupScreen extends StatelessWidget {
  static const routeName = '/create-group';
  const CreateGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Endpoint: POST /grupos/
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Grupo')),
      body: const Center(child: Text('Formulário criar grupo -> POST /grupos/')),
    );
  }
}