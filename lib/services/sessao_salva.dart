import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario.dart';
import 'api.dart';
import 'auth_service.dart';

const _chave = 'sessao';

/// Guarda a sessão no aparelho (no navegador, no localStorage) para que
/// recarregar a página não volte para o login. A API continua decidindo se o
/// token vale: a sessão vence em 8 horas ou quando o gestor revoga o acesso.
class SessaoSalva {
  Future<void> salvar(Sessao sessao) async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setString(_chave, jsonEncode(sessao.toJson()));
    } catch (_) {
      // Sem armazenamento (ex.: navegação privada): só não lembra o login.
    }
  }

  Future<void> apagar() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.remove(_chave);
    } catch (_) {}
  }

  /// Sessão salva ainda válida, com o usuário atualizado pela API; null se
  /// não houver sessão ou se a API recusar o token.
  Future<Sessao?> restaurar(AuthService auth) async {
    final Sessao salva;
    try {
      final preferencias = await SharedPreferences.getInstance();
      final texto = preferencias.getString(_chave);
      if (texto == null) return null;
      salva = Sessao.fromJson(jsonDecode(texto) as Map<String, dynamic>);
    } catch (_) {
      await apagar();
      return null;
    }

    try {
      final usuario = await auth.buscarUsuario(salva.token);
      final atualizada = Sessao(token: salva.token, usuario: usuario);
      await salvar(atualizada);
      return atualizada;
    } on ApiException catch (e) {
      // API fora do ar: entra com o que estava salvo; o painel mostra o erro.
      if (e.status == null) return salva;
      await apagar();
      return null;
    }
  }
}
