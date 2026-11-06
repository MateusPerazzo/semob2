import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:semob/models/usuario.dart';
import 'package:semob/pages/home_page.dart';
import 'package:semob/services/auth_service.dart';
import 'package:semob/services/operacao_service.dart';
import 'package:semob/widgets/app_header.dart';

/// Responde com os JSONs salvos em test/fixtures (cópias reais da API) e
/// guarda as alterações de usuário enviadas.
class _ApiDeTeste {
  final alteracoes = <Map<String, dynamic>>[];

  late final cliente = MockClient((requisicao) async {
    if (requisicao.method == 'PATCH') {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      alteracoes.add({'id': requisicao.url.pathSegments.last, ...corpo});
      return _json({
        'id': requisicao.url.pathSegments.last,
        'nome': 'Alterado',
        'email': 'alterado@x.com',
        'perfil': corpo['perfil'] ?? 'operacoes',
        'status': corpo['status'],
      });
    }

    final rota = requisicao.url.pathSegments.last;
    final periodo = requisicao.url.queryParameters['periodo'];
    final arquivo = File(
      periodo == null ? 'test/fixtures/$rota.json' : 'test/fixtures/${rota}_$periodo.json',
    );
    return http.Response.bytes(
      await arquivo.readAsBytes(),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  static http.Response _json(Object corpo) => http.Response.bytes(
        utf8.encode(jsonEncode(corpo)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  Widget home(Perfil perfil) {
    return MaterialApp(
      home: HomePage(
        sessao: Sessao(
          token: 'teste',
          usuario: Usuario(
            // Mesmo id do gestor em test/fixtures/usuarios.json.
            id: perfil == Perfil.gestor ? '6aedce602269f081cf1dbe9d' : perfil.name,
            nome: perfil.rotulo,
            email: '${perfil.name}@semob.scs.gov.br',
            perfil: perfil,
          ),
        ),
        onSair: () {},
        service: OperacaoService(client: cliente),
        auth: AuthService(client: cliente),
      ),
    );
  }
}

/// A leitura dos arquivos é IO real: deixa rodar fora do relógio falso do teste.
Future<void> _esperarCarregamento(WidgetTester tester) async {
  // Redesenha antes de procurar o indicador: a aba recém-aberta pode começar carregando.
  await tester.pump();
  for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void _usarTela(WidgetTester tester, Size tamanho) {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _abaNoMenu(String rotulo) =>
    find.descendant(of: find.byType(AppHeader), matching: find.text(rotulo));

const _abas = ['Visão geral', 'Passagens', 'Operações', 'Anomalias', 'Finanças', 'Usuários'];
const _periodos = ['Diário', 'Semanal', 'Mensal'];

void main() {
  for (final tamanho in [const Size(1440, 900), const Size(390, 844)]) {
    testWidgets(
      'todas as abas e períodos renderizam sem overflow em ${tamanho.width.toInt()}px',
      (tester) async {
        _usarTela(tester, tamanho);
        await tester.pumpWidget(_ApiDeTeste().home(Perfil.gestor));
        await _esperarCarregamento(tester);

        final menu = find.byType(ListView).first;

        for (final periodo in _periodos) {
          // No celular o menu de abas rola; volta para o início a cada período.
          // A aba Usuários não tem seletor de período: volta para a Visão geral.
          await tester.drag(menu, const Offset(2000, 0));
          await tester.pumpAndSettle();
          await tester.tap(_abaNoMenu('Visão geral'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(periodo));
          await _esperarCarregamento(tester);

          for (final aba in _abas) {
            await tester.dragUntilVisible(_abaNoMenu(aba), menu, const Offset(-80, 0));
            await tester.tap(_abaNoMenu(aba));
            await _esperarCarregamento(tester);

            final erro = tester.takeException();
            expect(
              erro,
              isNull,
              reason: '$aba / $periodo\n'
                  '${erro is FlutterError ? erro.toStringDeep() : erro}',
            );
            expect(find.text('Não foi possível carregar os dados da API'), findsNothing);
          }
        }
      },
    );
  }

  final abasPorPerfil = {
    Perfil.gestor: _abas,
    Perfil.operacoes: ['Visão geral', 'Operações', 'Anomalias'],
    Perfil.financeiro: ['Visão geral', 'Passagens', 'Finanças'],
  };

  for (final MapEntry(key: perfil, value: liberadas) in abasPorPerfil.entries) {
    testWidgets('${perfil.rotulo} vê só as abas do seu perfil', (tester) async {
      _usarTela(tester, const Size(1440, 900));
      await tester.pumpWidget(_ApiDeTeste().home(perfil));
      await _esperarCarregamento(tester);

      for (final aba in _abas) {
        expect(
          _abaNoMenu(aba),
          liberadas.contains(aba) ? findsOneWidget : findsNothing,
          reason: aba,
        );
      }
    });
  }

  testWidgets('gestor vê o contador e aprova uma solicitação com o perfil escolhido',
      (tester) async {
    _usarTela(tester, const Size(1440, 900));
    final api = _ApiDeTeste();
    await tester.pumpWidget(api.home(Perfil.gestor));
    await _esperarCarregamento(tester);

    // Uma solicitação pendente no fixture: contador "1" na aba.
    expect(
      find.descendant(of: find.byType(AppHeader), matching: find.text('1')),
      findsOneWidget,
    );

    await tester.tap(_abaNoMenu('Usuários'));
    await _esperarCarregamento(tester);

    expect(find.text('Maria Aparecida dos Santos'), findsOneWidget);
    expect(find.text('Você'), findsOneWidget);
    expect(find.text('Liberar acesso'), findsOneWidget);

    // Troca o perfil pedido (Financeiro) para Operações antes de aprovar.
    await tester.tap(find.text('Equipe Financeira').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipe de Operações').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aprovar'));
    await _esperarCarregamento(tester);

    expect(api.alteracoes, [
      {'id': '6aedcebd35eac061583f5b7b', 'status': 'aprovado', 'perfil': 'operacoes'},
    ]);
  });
}
