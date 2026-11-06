import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:semob/models/usuario.dart';
import 'package:semob/pages/login_page.dart';
import 'package:semob/services/auth_service.dart';

http.Response _json(Object corpo, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(corpo)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// API falsa: senha certa é semob2026; guarda as solicitações de acesso.
class _ApiDeTeste {
  final solicitacoes = <Map<String, dynamic>>[];

  late final auth = AuthService(
    client: MockClient((requisicao) async {
      switch (requisicao.url.path) {
        case '/api/destaques':
          return _json({'linhasAtivas': 9, 'cumprimento': 0.964, 'dadosAte': '2026-09-14'});
        case '/api/auth/login':
          final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
          if (corpo['senha'] != 'semob2026') {
            return _json({'erro': 'E-mail ou senha incorretos.'}, 401);
          }
          return _json({
            'token': 'abc',
            'usuario': {
              'id': '1',
              'nome': 'Gestor Municipal',
              'email': corpo['email'],
              'perfil': 'gestor',
              'status': 'aprovado',
            },
          });
        case '/api/auth/solicitar':
          solicitacoes.add(jsonDecode(requisicao.body) as Map<String, dynamic>);
          return _json({'mensagem': 'ok'}, 201);
      }
      return _json({'erro': 'rota desconhecida'}, 404);
    }),
  );
}

void _usarTela(WidgetTester tester, Size tamanho) {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Deixa as respostas falsas chegarem fora do relógio do teste.
Future<void> _esperar(WidgetTester tester) async {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

/// Rola até o elemento antes de tocar: o formulário passa da altura da tela.
Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
}

void main() {
  for (final tamanho in [const Size(1440, 900), const Size(1024, 700), const Size(390, 844)]) {
    testWidgets('login e cadastro sem overflow em ${tamanho.width.toInt()}px', (tester) async {
      _usarTela(tester, tamanho);
      await tester.pumpWidget(
        MaterialApp(home: LoginPage(auth: _ApiDeTeste().auth, onEntrar: (_) {})),
      );
      await _esperar(tester);

      expect(find.text('Bem-vindo de volta'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Painel azul com números reais só aparece em tela larga.
      if (tamanho.width >= 960) {
        expect(find.text('96,4%'), findsOneWidget);
        expect(find.text('9'), findsOneWidget);
      }

      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();
      expect(find.text('Nome completo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('perfil de demonstração preenche os campos e entra', (tester) async {
    _usarTela(tester, const Size(1440, 900));
    Sessao? sessao;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(auth: _ApiDeTeste().auth, onEntrar: (s) => sessao = s),
      ),
    );
    await _esperar(tester);

    await _tocar(tester, find.text('Gestor Municipal'));
    await tester.pump();
    expect(find.text('gestor@semob.scs.gov.br'), findsOneWidget);

    await _tocar(tester, find.text('Acessar dashboard'));
    await _esperar(tester);

    expect(sessao?.token, 'abc');
    expect(sessao?.usuario.perfil, Perfil.gestor);
  });

  testWidgets('senha errada mostra a mensagem da API', (tester) async {
    _usarTela(tester, const Size(1440, 900));
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(auth: _ApiDeTeste().auth, onEntrar: (_) {})),
    );
    await _esperar(tester);

    await tester.enterText(find.byType(TextField).at(0), 'gestor@semob.scs.gov.br');
    await tester.enterText(find.byType(TextField).at(1), 'errada');
    await _tocar(tester, find.text('Acessar dashboard'));
    await _esperar(tester);

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
  });

  testWidgets('criar conta valida os campos e envia a solicitação', (tester) async {
    _usarTela(tester, const Size(1440, 900));
    final api = _ApiDeTeste();
    await tester.pumpWidget(MaterialApp(home: LoginPage(auth: api.auth, onEntrar: (_) {})));
    await _esperar(tester);

    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    await _tocar(tester, find.text('Solicitar acesso').last);
    await tester.pump();
    expect(find.text('Informe seu nome completo.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Maria Santos');
    await tester.enterText(find.byType(TextField).at(1), 'maria@saocaetanodosul.sp.gov.br');
    await _tocar(tester, find.text('Selecione seu setor').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Financeiro').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), '123456');

    await _tocar(tester, find.text('Solicitar acesso').last);
    await tester.pump();
    expect(find.text('Confirme a declaração para enviar a solicitação.'), findsOneWidget);

    await _tocar(tester, find.byType(Checkbox));
    await _tocar(tester, find.text('Solicitar acesso').last);
    await _esperar(tester);

    expect(api.solicitacoes, [
      {
        'nome': 'Maria Santos',
        'email': 'maria@saocaetanodosul.sp.gov.br',
        'perfil': 'financeiro',
        'senha': '123456',
      },
    ]);
    // Volta para "Entrar" com o e-mail preenchido e o aviso de aprovação.
    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    expect(find.textContaining('Solicitação enviada'), findsOneWidget);
  });
}
