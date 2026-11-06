import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:semob/main.dart';
import 'package:semob/widgets/app_header.dart';

http.Response _json(Object? corpo, [int status = 200]) => http.Response.bytes(
      utf8.encode(corpo == null ? '' : jsonEncode(corpo)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _usuario(String perfil) => {
      'id': '1',
      'nome': 'Fulano de Tal',
      'email': 'fulano@semob.scs.gov.br',
      'perfil': perfil,
      'status': 'aprovado',
    };

/// API falsa: [tokenValido] é o único token aceito; o perfil vem de [perfilNaApi].
MockClient _api({String tokenValido = 'valido', String perfilNaApi = 'operacoes'}) {
  return MockClient((requisicao) async {
    final autorizado = requisicao.headers['Authorization'] == 'Bearer $tokenValido';

    switch (requisicao.url.path) {
      case '/api/destaques':
        return _json({'linhasAtivas': 9, 'cumprimento': 0.99, 'dadosAte': '2026-09-14'});
      case '/api/auth/login':
        return _json({'token': tokenValido, 'usuario': _usuario(perfilNaApi)});
      case '/api/auth/eu':
        return autorizado
            ? _json(_usuario(perfilNaApi))
            : _json({'erro': 'Sua sessão expirou. Entre novamente.'}, 401);
      case '/api/auth/sair':
        return _json(null, 204);
    }

    final rota = requisicao.url.pathSegments.last;
    final periodo = requisicao.url.queryParameters['periodo'];
    return http.Response.bytes(
      await File('test/fixtures/${rota}_$periodo.json').readAsBytes(),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

String _sessaoSalva(String token, String perfil) =>
    jsonEncode({'token': token, 'usuario': _usuario(perfil)});

Future<void> _esperar(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Finder _abaNoMenu(String rotulo) =>
    find.descendant(of: find.byType(AppHeader), matching: find.text(rotulo));

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(1440, 900);
    view.devicePixelRatio = 1;
  });

  testWidgets('recarregar com sessão válida entra direto, com o perfil atualizado pela API',
      (tester) async {
    // Salvo como gestor, mas a API diz que agora é da equipe de operações.
    SharedPreferences.setMockInitialValues({'sessao': _sessaoSalva('valido', 'gestor')});

    await tester.pumpWidget(SemobApp(client: _api()));
    await _esperar(tester);

    expect(find.byType(AppHeader), findsOneWidget);
    expect(_abaNoMenu('Operações'), findsOneWidget);
    expect(_abaNoMenu('Usuários'), findsNothing);
  });

  testWidgets('sessão vencida ou revogada volta para o login e é apagada', (tester) async {
    SharedPreferences.setMockInitialValues({'sessao': _sessaoSalva('vencido', 'gestor')});

    await tester.pumpWidget(SemobApp(client: _api()));
    await _esperar(tester);

    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('sessao'), isNull);
  });

  testWidgets('entrar salva a sessão e sair apaga', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(SemobApp(client: _api()));
    await _esperar(tester);

    await tester.enterText(find.byType(TextField).at(0), 'fulano@semob.scs.gov.br');
    await tester.enterText(find.byType(TextField).at(1), 'qualquer');
    await tester.ensureVisible(find.text('Acessar dashboard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acessar dashboard'));
    await _esperar(tester);

    final preferencias = await SharedPreferences.getInstance();
    expect(find.byType(AppHeader), findsOneWidget);
    expect(preferencias.getString('sessao'), contains('"token":"valido"'));

    await tester.tap(find.byTooltip('Conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await _esperar(tester);

    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    expect(preferencias.getString('sessao'), isNull);
  });
}
