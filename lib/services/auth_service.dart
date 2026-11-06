import 'package:http/http.dart' as http;

import '../models/usuario.dart';
import 'api.dart';

/// Login, solicitações de acesso e gestão de contas.
class AuthService {
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<Sessao> entrar(String email, String senha) async {
    final json = await requisitarApi(
      _client,
      'POST',
      '/api/auth/login',
      corpo: {'email': email, 'senha': senha},
    ) as Map<String, dynamic>;

    return Sessao(
      token: json['token'] as String,
      usuario: Usuario.fromJson(json['usuario'] as Map<String, dynamic>),
    );
  }

  /// Cria a conta como pendente; o gestor precisa aprovar.
  Future<void> solicitarAcesso({
    required String nome,
    required String email,
    required Perfil perfil,
    required String senha,
  }) async {
    await requisitarApi(
      _client,
      'POST',
      '/api/auth/solicitar',
      corpo: {'nome': nome, 'email': email, 'perfil': perfil.name, 'senha': senha},
    );
  }

  /// Usuário dono do token, com perfil e situação atualizados.
  Future<Usuario> buscarUsuario(String token) async {
    final json = await requisitarApi(_client, 'GET', '/api/auth/eu', token: token);
    return Usuario.fromJson(json as Map<String, dynamic>);
  }

  /// Encerra a sessão na API. Falhas são ignoradas: o app sai de qualquer jeito.
  Future<void> sair(String token) async {
    try {
      await requisitarApi(_client, 'POST', '/api/auth/sair', token: token);
    } catch (_) {}
  }

  Future<Destaques> buscarDestaques() async {
    final json = await requisitarApi(_client, 'GET', '/api/destaques');
    return Destaques.fromJson(json as Map<String, dynamic>);
  }

  /// Só para o gestor.
  Future<List<Usuario>> listarUsuarios(String token) async {
    final json = await requisitarApi(_client, 'GET', '/api/usuarios', token: token);
    return (json as List)
        .map((item) => Usuario.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Aprova, recusa ou revoga uma conta e, opcionalmente, troca o perfil.
  Future<Usuario> atualizarUsuario(
    String token,
    String id, {
    StatusUsuario? status,
    Perfil? perfil,
  }) async {
    final json = await requisitarApi(
      _client,
      'PATCH',
      '/api/usuarios/$id',
      token: token,
      corpo: {'status': ?status?.name, 'perfil': ?perfil?.name},
    );
    return Usuario.fromJson(json as Map<String, dynamic>);
  }
}
