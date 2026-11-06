import 'package:flutter/material.dart';

import '../models/operacao.dart';
import '../models/usuario.dart';
import '../services/api.dart';
import '../services/auth_service.dart';
import '../services/operacao_service.dart';
import '../theme/tema.dart';
import '../utils/formatacao.dart';
import '../widgets/app_header.dart';
import '../widgets/seletor_periodo.dart';
import 'anomalias_page.dart';
import 'financas_page.dart';
import 'operacoes_page.dart';
import 'passagens_page.dart';
import 'usuarios_page.dart';
import 'visao_geral_page.dart';

class _Aba {
  final String rotulo;
  final IconData icone;
  final String subtitulo;

  /// Perfis que veem a aba.
  final Set<Perfil> perfis;

  /// Conteúdo a partir dos dados do período. Null na aba Usuários,
  /// que não depende do período.
  final Widget Function(DadosPainel dados)? construir;

  const _Aba(this.rotulo, this.icone, this.subtitulo, this.perfis, this.construir);
}

const _todos = {Perfil.gestor, Perfil.operacoes, Perfil.financeiro};
const _operacoes = {Perfil.gestor, Perfil.operacoes};
const _financeiro = {Perfil.gestor, Perfil.financeiro};

final _abas = [
  _Aba(
    'Visão geral',
    Icons.grid_view_outlined,
    'Resumo consolidado da operação municipal',
    _todos,
    (dados) => VisaoGeralPage(dados: dados),
  ),
  _Aba(
    'Passagens',
    Icons.person_outline,
    'Fluxo, perfil e demanda de passageiros',
    _financeiro,
    (dados) => PassagensPage(dados: dados),
  ),
  _Aba(
    'Operações',
    Icons.directions_bus_outlined,
    'Quilometragem, viagens e desempenho das linhas',
    _operacoes,
    (dados) => OperacoesPage(dados: dados),
  ),
  _Aba(
    'Anomalias',
    Icons.warning_amber_outlined,
    'Desvios detectados automaticamente nos dados da operação',
    _operacoes,
    (dados) => AnomaliasPage(dados: dados),
  ),
  _Aba(
    'Finanças',
    Icons.payments_outlined,
    'Receita tarifária e desempenho financeiro',
    _financeiro,
    (dados) => FinancasPage(dados: dados),
  ),
  const _Aba(
    'Usuários',
    Icons.manage_accounts_outlined,
    'Solicitações de acesso e contas da plataforma',
    {Perfil.gestor},
    null,
  ),
];

class HomePage extends StatefulWidget {
  final Sessao sessao;
  final VoidCallback onSair;
  final OperacaoService? service;
  final AuthService? auth;

  const HomePage({
    super.key,
    required this.sessao,
    required this.onSair,
    this.service,
    this.auth,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final OperacaoService _service =
      widget.service ?? OperacaoService(token: widget.sessao.token);
  late final AuthService _auth = widget.auth ?? AuthService();

  late final List<_Aba> _abasDoPerfil = _abas
      .where((aba) => aba.perfis.contains(widget.sessao.usuario.perfil))
      .toList();

  int _abaSelecionada = 0;
  Periodo _periodo = Periodo.semanal;
  late Future<DadosPainel> _dados;

  /// Solicitações de acesso aguardando o gestor.
  int _pendentes = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
    if (widget.sessao.usuario.perfil == Perfil.gestor) _contarPendentes();
  }

  void _carregar() {
    _dados = _service.buscarPainel(_periodo);
  }

  Future<void> _contarPendentes() async {
    try {
      final usuarios = await _auth.listarUsuarios(widget.sessao.token);
      if (!mounted) return;
      setState(() {
        _pendentes = usuarios.where((u) => u.status == StatusUsuario.pendente).length;
      });
    } catch (_) {
      // Sem contador: a aba Usuários mostra o erro quando aberta.
    }
  }

  @override
  Widget build(BuildContext context) {
    final aba = _abasDoPerfil[_abaSelecionada];

    return Scaffold(
      backgroundColor: Cores.fundo,
      body: FutureBuilder(
        future: _dados,
        builder: (context, snapshot) {
          return Column(
            children: [
              AppHeader(
                abas: [
                  for (final a in _abasDoPerfil)
                    AbaMenu(
                      a.rotulo,
                      a.icone,
                      contador: a.construir == null ? _pendentes : 0,
                    ),
                ],
                abaSelecionada: _abaSelecionada,
                onSelecionarAba: (index) {
                  setState(() => _abaSelecionada = index);
                },
                usuario: widget.sessao.usuario,
                onSair: widget.onSair,
                erro: snapshot.hasError,
                situacaoDados: snapshot.hasData
                    ? 'Dados até ${formatarDiaMes(snapshot.data!.resumo.fim)}'
                    : null,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _cabecalho(aba, snapshot.data),
                            const SizedBox(height: 20),
                            _conteudo(aba, snapshot),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _cabecalho(_Aba aba, DadosPainel? dados) {
    final usaPeriodo = aba.construir != null;
    final resumo = dados?.resumo;
    final intervalo = resumo == null || !usaPeriodo
        ? ''
        : resumo.inicio == resumo.fim
            ? ' · ${formatarDiaMes(resumo.fim)}'
            : ' · ${formatarDiaMes(resumo.inicio)} a ${formatarDiaMes(resumo.fim)}';

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      spacing: 20,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(aba.rotulo, style: Estilos.tituloPagina),
            const SizedBox(height: 4),
            Text('${aba.subtitulo}$intervalo', style: Estilos.subtituloPagina),
          ],
        ),
        if (usaPeriodo)
          SeletorPeriodo(
            selecionado: _periodo,
            onSelecionar: (periodo) {
              setState(() {
                _periodo = periodo;
                _carregar();
              });
            },
          ),
      ],
    );
  }

  Widget _conteudo(_Aba aba, AsyncSnapshot<DadosPainel> snapshot) {
    final construir = aba.construir;
    if (construir == null) {
      return UsuariosPage(
        auth: _auth,
        sessao: widget.sessao,
        onPendentes: (total) => setState(() => _pendentes = total),
      );
    }

    if (snapshot.hasError) {
      return _erro(snapshot.error!);
    }

    // Enquanto recarrega outro período, mantém os dados anteriores na tela.
    if (!snapshot.hasData) {
      return const Padding(
        padding: EdgeInsets.all(60),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return construir(snapshot.data!);
  }

  Widget _erro(Object erro) {
    final sessaoExpirada = erro is ApiException && erro.sessaoExpirada;

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
          Text(
            sessaoExpirada ? 'Sessão encerrada' : 'Não foi possível carregar os dados da API',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Cores.critico,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            erro is ApiException
                ? erro.mensagem
                : 'Verifique se a API está rodando em ${OperacaoService.baseUrl} '
                    '(pasta server: npm start).\n$erro',
            style: const TextStyle(fontSize: 12.5, color: Cores.textoSecundario),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: sessaoExpirada ? widget.onSair : () => setState(_carregar),
            child: Text(sessaoExpirada ? 'Entrar novamente' : 'Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
