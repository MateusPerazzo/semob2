import 'dart:convert';

import 'package:http/http.dart' as http;

// Para outro endereço: flutter run --dart-define=API_URL=http://10.0.2.2:3000
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:3000',
);

/// Erro devolvido pela API, já com a mensagem para mostrar ao usuário.
class ApiException implements Exception {
  final String mensagem;
  final int? status;

  const ApiException(this.mensagem, {this.status});

  /// Token ausente, vencido ou de uma conta que perdeu o acesso.
  bool get sessaoExpirada => status == 401;

  @override
  String toString() => mensagem;
}

/// Faz uma requisição à API e devolve o JSON da resposta (null se vazia).
Future<dynamic> requisitarApi(
  http.Client client,
  String metodo,
  String caminho, {
  String? token,
  Map<String, dynamic>? corpo,
  Map<String, String>? query,
}) async {
  final requisicao = http.Request(
    metodo,
    Uri.parse('$apiUrl$caminho').replace(queryParameters: query),
  );
  if (token != null) requisicao.headers['Authorization'] = 'Bearer $token';
  if (corpo != null) {
    requisicao.headers['Content-Type'] = 'application/json';
    requisicao.body = jsonEncode(corpo);
  }

  final http.Response resposta;
  try {
    resposta = await http.Response.fromStream(await client.send(requisicao));
  } on http.ClientException {
    throw const ApiException(
      'Não foi possível conectar à API em $apiUrl. '
      'Verifique se ela está rodando (pasta server: npm start).',
    );
  }

  final texto = utf8.decode(resposta.bodyBytes);
  final json = texto.isEmpty ? null : jsonDecode(texto);

  if (resposta.statusCode >= 400) {
    throw ApiException(
      json is Map && json['erro'] is String
          ? json['erro'] as String
          : 'Erro ${resposta.statusCode} na API.',
      status: resposta.statusCode,
    );
  }
  return json;
}
