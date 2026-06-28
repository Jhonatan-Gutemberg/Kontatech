import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kontatech/utils/secure_storage.dart';
import 'package:kontatech/config/api_config.dart';
import 'loginScreen.dart';
// A importação do loginScreen pode ser necessária
// no novo widget 'MainScreen' se o logout for movido para lá.

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  List despesas = [];
  List grupos = [];
  bool isLoading = true;
  double totalGeral = 0.0;
  String? selectedGrupoId;
  // O 'selectedIndex' foi REMOVIDO daqui

  @override
  void initState() {
    super.initState();
    fetchGruposDoUsuario();
  }

  void _redirectToLogin() {
    // Esta função será chamada pelo widget pai (MainScreen)
    // Mas a lógica de navegação real deve estar lá.
    // Por segurança, verificamos se o contexto ainda é válido.
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> fetchGruposDoUsuario() async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        _redirectToLogin();
        return;
      }

      final url = Uri.parse(apiUrl('/grupos/'));
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          grupos = data;
        });

        if (grupos.isEmpty) {
          if (!mounted) return;
          setState(() => isLoading = false);
        } else {
          selectedGrupoId = grupos.first['id'].toString();
          await fetchDespesas(selectedGrupoId!);
        }
      } else if (response.statusCode == 401) {
        await SecureStorage.deleteToken();
        _redirectToLogin();
      } else {
        print('Erro ao carregar grupos: ${response.statusCode}');
        if (!mounted) return;
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Erro ao buscar grupos: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchDespesas(String grupoId) async {
    // ... (seu código de fetchDespesas permanece o mesmo) ...
    // Apenas adicione verificações 'if (!mounted) return;'
    // antes de qualquer 'setState'
    try {
      final token = await SecureStorage.getToken();
      final url = Uri.parse(
        apiUrl('/despesas/grupos/$grupoId/despesas'),
      );
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          despesas = data;
          totalGeral = despesas.fold(0.0, (sum, item) {
            try {
              return sum + double.parse(item['valor_total'].toString());
            } catch (_) {
              return sum;
            }
          });
          isLoading = false;
        });
      } else {
        print('Erro ao carregar despesas: ${response.statusCode}');
        if (!mounted) return;
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Erro de conexão: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // _logout foi REMOVIDO daqui

  @override
  Widget build(BuildContext context) {
    // O 'switch' e o 'Scaffold' foram REMOVIDOS
    // Este widget agora retorna APENAS o conteúdo do body
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : grupos.isEmpty
        ? const Center(child: Text('Você ainda não participa de nenhum grupo.'))
        : Column(
          children: [
            // seletor de grupo
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButton<String>(
                value: selectedGrupoId,
                isExpanded: true,
                items:
                    grupos.map<DropdownMenuItem<String>>((grupo) {
                      return DropdownMenuItem<String>(
                        value: grupo['id'].toString(),
                        child: Text(grupo['nome']),
                      );
                    }).toList(),
                onChanged: (value) async {
                  setState(() {
                    selectedGrupoId = value;
                    isLoading = true;
                  });
                  await fetchDespesas(value!);
                },
              ),
            ),

            // total
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              color: Colors.blue.shade50,
              child: Text(
                '💰 Total de despesas: R\$ ${totalGeral.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),

            // lista de despesas
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => fetchDespesas(selectedGrupoId!),
                child: ListView.builder(
                  itemCount: despesas.length,
                  itemBuilder: (context, index) {
                    final despesa = despesas[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      elevation: 2,
                      child: ListTile(
                        title: Text(despesa['titulo'] ?? 'Sem título'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Descrição: ${despesa['descricao'] ?? 'Sem descrição'}',
                            ),
                            Text(
                              'Pagador: ${despesa['nome_pagador'] ?? 'Desconhecido'}',
                            ),
                            Text('Data: ${despesa['data'] ?? '-'}'),
                          ],
                        ),
                        trailing: Text(
                          'R\$ ${double.tryParse(despesa['valor_total'].toString())?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
  }
}
