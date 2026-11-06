/// Perfil de acesso. O nome do enum é o valor usado pela API.
/// As abas liberadas para cada perfil ficam em pages/home_page.dart.
enum Perfil {
  gestor(
    'Gestor Municipal',
    'GM',
    'Gestão (gestor municipal)',
    'Acesso completo e aprovação de contas',
  ),
  operacoes(
    'Equipe de Operações',
    'OP',
    'Operações',
    'Visão geral + Operações + Anomalias',
  ),
  financeiro(
    'Equipe Financeira',
    'FN',
    'Financeiro',
    'Visão geral + Passagens + Finanças',
  );

  final String rotulo;
  final String sigla;

  /// Nome do setor no formulário de "Criar conta".
  final String setor;

  /// Resumo do que o perfil vê, usado na tela de login.
  final String acesso;

  const Perfil(this.rotulo, this.sigla, this.setor, this.acesso);

  static Perfil? deNome(Object? nome) =>
      values.where((perfil) => perfil.name == nome).firstOrNull;
}

enum StatusUsuario {
  pendente,
  aprovado,
  recusado;

  static StatusUsuario deNome(Object? nome) =>
      values.where((status) => status.name == nome).firstOrNull ?? pendente;
}

class Usuario {
  final String id;
  final String nome;
  final String email;
  final Perfil perfil;
  final StatusUsuario status;
  final DateTime? criadoEm;

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    this.status = StatusUsuario.aprovado,
    this.criadoEm,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as String,
      nome: json['nome'] as String? ?? '',
      email: json['email'] as String? ?? '',
      // Perfil desconhecido cai no mais restrito que ainda vê dados.
      perfil: Perfil.deNome(json['perfil']) ?? Perfil.operacoes,
      status: StatusUsuario.deNome(json['status']),
      criadoEm: DateTime.tryParse(json['criadoEm'] as String? ?? '')?.toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'perfil': perfil.name,
        'status': status.name,
        'criadoEm': criadoEm?.toUtc().toIso8601String(),
      };

  /// Até duas iniciais, ex.: "Gestor Municipal" -> "GM".
  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (partes.isEmpty) return '?';
    final letras = partes.length == 1
        ? partes.first.substring(0, 1)
        : '${partes.first[0]}${partes.last[0]}';
    return letras.toUpperCase();
  }
}

/// Usuário logado e o token enviado à API.
class Sessao {
  final String token;
  final Usuario usuario;

  const Sessao({required this.token, required this.usuario});

  factory Sessao.fromJson(Map<String, dynamic> json) {
    return Sessao(
      token: json['token'] as String,
      usuario: Usuario.fromJson(json['usuario'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {'token': token, 'usuario': usuario.toJson()};
}

/// Números exibidos no painel azul da tela de login.
class Destaques {
  final int? linhasAtivas;
  final double? cumprimento;
  final DateTime? dadosAte;

  const Destaques({this.linhasAtivas, this.cumprimento, this.dadosAte});

  factory Destaques.fromJson(Map<String, dynamic> json) {
    return Destaques(
      linhasAtivas: (json['linhasAtivas'] as num?)?.toInt(),
      cumprimento: (json['cumprimento'] as num?)?.toDouble(),
      dadosAte: DateTime.tryParse(json['dadosAte'] as String? ?? ''),
    );
  }
}
