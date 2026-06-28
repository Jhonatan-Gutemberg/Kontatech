import 'package:flutter/material.dart';

class ExpensesListScreen extends StatelessWidget {
  static const routeName = '/expenses';
  const ExpensesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Endpoint: GET /despesas/grupos/{grupo_id}/despesas
    return Scaffold(
      appBar: AppBar(title: const Text('Despesas do Grupo')),
      body: const Center(child: Text('Listagem de despesas por grupo')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/create-expense'),
        child: const Icon(Icons.add),
      ),
    );
  }
}