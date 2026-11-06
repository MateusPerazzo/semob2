import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/usuario.dart';
import '../services/api.dart';
import '../services/auth_service.dart';
import '../theme/tema.dart';
import '../widgets/painel.dart';
import '../widgets/selos.dart';
import '../widgets/tabela.dart';

final _data = DateFormat('dd/MM/yyyy');

/// Área do gestor: aprova ou recusa solicitações e revoga acessos.
class UsuariosPage extends StatefulWidget {
  final AuthService auth;
  final Sessao sessao;

  /// Avisa quantas solicitações seguem pendentes (para o contador da aba).
  final ValueChanged<int>? onPendentes;

  const UsuariosPage({
    super.key,
    required this.auth,
    required this.sessao,
    this.onPendentes,
  });

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  List<Usuario>? _usuarios;
  Object? _erro;

  /// Perfil escolhido pelo gestor antes de aprovar, por id.
  final _perfilEscolhido = <String, Perfil>{};
  final _processando = <String>{};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final usuarios = await widget.auth.listarUsuarios(widget.sessao.token);
      if (!mounted) return;
      setState(() {
        _usuarios = usuarios;
        _erro = null;
      });
      widget.onPendentes?.call(
        usuarios.where((u) => u.status == StatusUsuario.pendente).length,
      );
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    }
  }

  Future<void> _alterar(
    Usuario usuario,
    StatusUsuario status, {
    Perfil? perfil,
    required String mensagem,
  }) async {
    setState(() => _processando.add(usuario.id));
    final avisos = ScaffoldMessenger.of(context);

    try {
      await widget.auth.atualizarUsuario(
        widget.sessao.token,
        usuario.id,
        status: status,
        perfil: perfil,
      );
      _perfilEscolhido.remove(usuario.id);
      await _carregar();
      avisos.showSnackBar(SnackBar(content: Text(mensagem)));
    } catch (e) {
      avisos.showSnackBar(
        SnackBar(
          backgroundColor: Cores.critico,
          content: Text(e is ApiException ? e.mensagem : 'Erro: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _processando.remove(usuario.id));
    }
  }

  Future<void> _confirmarRevogacao(Usuario usuario) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revogar acesso'),
        content: Text(
          '${usuario.nome} perde o acesso ao painel e é desconectado na hora. '
          'Você pode liberar o acesso de novo depois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cores.critico),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revogar'),
          ),
        ],
      ),
    );

    if (confirmou == true) {
      await _alterar(
        usuario,
        StatusUsuario.recusado,
        mensagem: 'Acesso de ${usuario.nome} revogado.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarios = _usuarios;

    if (usuarios == null) {
      if (_erro != null) return _mensagemErro();
      return const Padding(
        padding: EdgeInsets.all(60),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final pendentes = usuarios.where((u) => u.status == StatusUsuario.pendente).toList();
    final demais = usuarios.where((u) => u.status != StatusUsuario.pendente).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Painel(
          titulo: 'Solicitações pendentes',
          subtitulo: 'Confira o setor e ajuste o perfil antes de aprovar',
          conteudoSemMargem: true,
          acao: pendentes.isEmpty
              ? null
              : SeloContador(
                  texto: pendentes.length == 1
                      ? '1 pendente'
                      : '${pendentes.length} pendentes',
                  cor: const Color(0xFF8A4B00),
                  fundo: const Color(0xFFFCE8BF),
                ),
          child: pendentes.isEmpty
              ? const EstadoVazio(
                  icone: Icons.how_to_reg_outlined,
                  texto: 'Nenhuma solicitação aguardando aprovação',
                )
              : Column(
                  children: [for (final usuario in pendentes) _solicitacao(usuario)],
                ),
        ),
        const SizedBox(height: 16),
        Painel(
          titulo: 'Contas',
          subtitulo: 'Usuários com acesso liberado ou recusado',
          conteudoSemMargem: true,
          child: Tabela(
            larguraMinima: 820,
            colunas: const [
              ColunaTabela('Nome', flex: 3),
              ColunaTabela('E-mail', flex: 4),
              ColunaTabela('Perfil', flex: 3),
              ColunaTabela('Situação', flex: 2),
              ColunaTabela('Ação', flex: 2, alinharDireita: true),
            ],
            linhas: [for (final usuario in demais) _linhaConta(usuario)],
          ),
        ),
      ],
    );
  }

  Widget _solicitacao(Usuario usuario) {
    final perfil = _perfilEscolhido[usuario.id] ?? usuario.perfil;
    final ocupado = _processando.contains(usuario.id);

    final dados = Row(
      children: [
        _Iniciais(usuario.iniciais),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(usuario.nome, style: Estilos.celulaDestaque),
              const SizedBox(height: 2),
              Text(
                usuario.email,
                overflow: TextOverflow.ellipsis,
                style: Estilos.celula,
              ),
              const SizedBox(height: 2),
              Text(
                [
                  'Setor informado: ${usuario.perfil.setor}',
                  if (usuario.criadoEm != null) 'pedido em ${_data.format(usuario.criadoEm!)}',
                ].join(' · '),
                style: Estilos.subtituloPainel,
              ),
            ],
          ),
        ),
      ],
    );

    final acoes = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Cores.borda),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Perfil>(
              value: perfil,
              borderRadius: BorderRadius.circular(8),
              style: const TextStyle(fontSize: 13, color: Cores.texto),
              items: [
                for (final opcao in Perfil.values)
                  DropdownMenuItem(value: opcao, child: Text(opcao.rotulo)),
              ],
              onChanged: ocupado
                  ? null
                  : (opcao) => setState(() => _perfilEscolhido[usuario.id] = opcao!),
            ),
          ),
        ),
        OutlinedButton(
          onPressed: ocupado
              ? null
              : () => _alterar(
                    usuario,
                    StatusUsuario.recusado,
                    mensagem: 'Solicitação de ${usuario.nome} recusada.',
                  ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Cores.critico,
            side: const BorderSide(color: Color(0xFFF5C2C2)),
            minimumSize: const Size(0, 40),
          ),
          child: const Text('Recusar'),
        ),
        FilledButton(
          onPressed: ocupado
              ? null
              : () => _alterar(
                    usuario,
                    StatusUsuario.aprovado,
                    perfil: perfil,
                    mensagem: '${usuario.nome} aprovado como ${perfil.rotulo}.',
                  ),
          style: FilledButton.styleFrom(
            backgroundColor: Cores.primaria,
            minimumSize: const Size(0, 40),
          ),
          child: const Text('Aprovar'),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Cores.grade)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 760) {
            return Row(
              children: [
                Expanded(child: dados),
                const SizedBox(width: 16),
                acoes,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [dados, const SizedBox(height: 12), acoes],
          );
        },
      ),
    );
  }

  List<Widget> _linhaConta(Usuario usuario) {
    final propria = usuario.id == widget.sessao.usuario.id;
    final ativo = usuario.status == StatusUsuario.aprovado;
    final ocupado = _processando.contains(usuario.id);

    final Widget acao;
    if (propria) {
      acao = const Text('Você', style: Estilos.subtituloPainel);
    } else if (ativo) {
      acao = TextButton(
        onPressed: ocupado ? null : () => _confirmarRevogacao(usuario),
        style: TextButton.styleFrom(foregroundColor: Cores.critico),
        child: const Text('Revogar acesso'),
      );
    } else {
      acao = TextButton(
        onPressed: ocupado
            ? null
            : () => _alterar(
                  usuario,
                  StatusUsuario.aprovado,
                  mensagem: 'Acesso de ${usuario.nome} liberado.',
                ),
        child: const Text('Liberar acesso'),
      );
    }

    return [
      Text(usuario.nome, overflow: TextOverflow.ellipsis, style: Estilos.celulaDestaque),
      Text(usuario.email, overflow: TextOverflow.ellipsis, style: Estilos.celula),
      Text(usuario.perfil.rotulo, overflow: TextOverflow.ellipsis, style: Estilos.celula),
      _SeloSituacao(ativo: ativo),
      acao,
    ];
  }

  Widget _mensagemErro() {
    final erro = _erro;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Cores.criticoFundo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C2C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Não foi possível carregar os usuários',
            style: TextStyle(fontWeight: FontWeight.bold, color: Cores.critico),
          ),
          const SizedBox(height: 6),
          Text(
            erro is ApiException ? erro.mensagem : '$erro',
            style: const TextStyle(fontSize: 12.5, color: Cores.textoSecundario),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() => _erro = null);
              _carregar();
            },
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _Iniciais extends StatelessWidget {
  final String texto;

  const _Iniciais(this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Cores.infoFundo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Cores.primaria,
        ),
      ),
    );
  }
}

class _SeloSituacao extends StatelessWidget {
  final bool ativo;

  const _SeloSituacao({required this.ativo});

  @override
  Widget build(BuildContext context) {
    final cor = ativo ? Cores.sucesso : Cores.critico;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ativo ? Cores.sucessoFundo : Cores.criticoFundo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Text(
        ativo ? 'Ativo' : 'Sem acesso',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cor),
      ),
    );
  }
}
