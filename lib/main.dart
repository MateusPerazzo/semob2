import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models/usuario.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';
import 'services/operacao_service.dart';
import 'services/sessao_salva.dart';
import 'theme/tema.dart';

void main() {
  runApp(const SemobApp());
}

class SemobApp extends StatefulWidget {
  /// Cliente HTTP da API; os testes passam um falso.
  final http.Client? client;

  const SemobApp({super.key, this.client});

  @override
  State<SemobApp> createState() => _SemobAppState();
}

class _SemobAppState extends State<SemobApp> {
  late final _auth = AuthService(client: widget.client);
  final _sessaoSalva = SessaoSalva();

  Sessao? _sessao;

  /// Enquanto confere a sessão salva, não mostra o login (evita piscar).
  bool _restaurando = true;

  @override
  void initState() {
    super.initState();
    _restaurar();
  }

  Future<void> _restaurar() async {
    Sessao? sessao;
    try {
      sessao = await _sessaoSalva.restaurar(_auth);
    } catch (_) {
      // Qualquer problema na sessão salva: segue para o login.
    }
    if (!mounted) return;
    setState(() {
      _sessao = sessao;
      _restaurando = false;
    });
  }

  void _entrar(Sessao sessao) {
    setState(() => _sessao = sessao);
    _sessaoSalva.salvar(sessao);
  }

  Future<void> _sair() async {
    final sessao = _sessao;
    setState(() => _sessao = null);
    await _sessaoSalva.apagar();
    if (sessao != null) await _auth.sair(sessao.token);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SEMOB-SCS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Cores.primaria),
        scaffoldBackgroundColor: Cores.fundo,
      ),
      home: _tela(),
    );
  }

  Widget _tela() {
    if (_restaurando) {
      return const Scaffold(
        backgroundColor: Cores.fundo,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final sessao = _sessao;
    if (sessao == null) {
      return LoginPage(auth: _auth, onEntrar: _entrar);
    }

    return HomePage(
      key: ValueKey(sessao.token),
      sessao: sessao,
      auth: _auth,
      service: OperacaoService(client: widget.client, token: sessao.token),
      onSair: _sair,
    );
  }
}
