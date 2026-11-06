import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../services/api.dart';
import '../services/auth_service.dart';
import '../theme/tema.dart';
import '../utils/formatacao.dart';

/// Mostra os perfis de teste. Na versão final rode com
/// --dart-define=PERFIS_DEMO=false e use PERFIS_DEMO=false no server/.env.
const mostrarPerfisDemo = bool.fromEnvironment('PERFIS_DEMO', defaultValue: true);

const _senhaDemo = 'semob2026';
const _emailsDemo = {
  Perfil.gestor: 'gestor@semob.scs.gov.br',
  Perfil.operacoes: 'operacoes@semob.scs.gov.br',
  Perfil.financeiro: 'financeiro@semob.scs.gov.br',
};

const _textoClaro = Color(0xFFD6E2F2);
const _textoClaroMudo = Color(0xFFC9D8EC);

enum _Modo { entrar, criarConta }

class LoginPage extends StatefulWidget {
  final AuthService auth;
  final ValueChanged<Sessao> onEntrar;

  const LoginPage({super.key, required this.auth, required this.onEntrar});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final Future<Destaques> _destaques = widget.auth.buscarDestaques();

  _Modo _modo = _Modo.entrar;

  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _focoSenha = FocusNode();

  final _nome = TextEditingController();
  final _emailCadastro = TextEditingController();
  final _senhaCadastro = TextEditingController();
  Perfil? _setor;
  bool _aceitouTermos = false;

  bool _senhaVisivel = false;
  bool _enviando = false;
  String? _erro;
  String? _sucesso;

  @override
  void dispose() {
    for (final controle in [_email, _senha, _nome, _emailCadastro, _senhaCadastro]) {
      controle.dispose();
    }
    _focoSenha.dispose();
    super.dispose();
  }

  void _trocarModo(_Modo modo) {
    setState(() {
      _modo = modo;
      _erro = null;
      _sucesso = null;
      _senhaVisivel = false;
    });
  }

  void _preencher(Perfil perfil) {
    setState(() {
      _email.text = _emailsDemo[perfil]!;
      _senha.text = _senhaDemo;
      _erro = null;
    });
  }

  Future<void> _entrar() async {
    final email = _email.text.trim();
    final senha = _senha.text;
    if (email.isEmpty || senha.isEmpty) {
      setState(() => _erro = 'Informe o e-mail e a senha.');
      return;
    }

    await _enviar(() async {
      widget.onEntrar(await widget.auth.entrar(email, senha));
    });
  }

  Future<void> _solicitarAcesso() async {
    final nome = _nome.text.trim();
    final email = _emailCadastro.text.trim();
    final senha = _senhaCadastro.text;

    final erro = nome.isEmpty
        ? 'Informe seu nome completo.'
        : !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
            ? 'Informe um e-mail válido.'
            : _setor == null
                ? 'Selecione seu setor.'
                : senha.length < 6
                    ? 'A senha deve ter pelo menos 6 caracteres.'
                    : !_aceitouTermos
                        ? 'Confirme a declaração para enviar a solicitação.'
                        : null;
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }

    await _enviar(() async {
      await widget.auth.solicitarAcesso(
        nome: nome,
        email: email,
        perfil: _setor!,
        senha: senha,
      );
      setState(() {
        _modo = _Modo.entrar;
        _email.text = email;
        _senha.clear();
        _nome.clear();
        _emailCadastro.clear();
        _senhaCadastro.clear();
        _setor = null;
        _aceitouTermos = false;
        _sucesso = 'Solicitação enviada. Você poderá entrar assim que o '
            'gestor municipal aprovar o seu acesso.';
      });
    });
  }

  Future<void> _enviar(Future<void> Function() acao) async {
    setState(() {
      _enviando = true;
      _erro = null;
      _sucesso = null;
    });
    try {
      await acao();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.fundo,
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 960) return _formulario(compacto: true);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 46, child: _PainelInstitucional(destaques: _destaques)),
                  Expanded(flex: 54, child: _formulario(compacto: false)),
                ],
              );
            },
          ),
          const Positioned(right: 16, bottom: 16, child: _BotaoAjuda()),
        ],
      ),
    );
  }

  Widget _formulario({required bool compacto}) {
    final entrar = _modo == _Modo.entrar;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compacto ? 16 : 48,
                compacto ? 24 : 40,
                compacto ? 16 : 48,
                80,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (compacto) ...[
                      const _Marca(fundoEscuro: false),
                      const SizedBox(height: 32),
                    ],
                    Text(
                      entrar ? 'Bem-vindo de volta' : 'Solicitar acesso',
                      style: TextStyle(
                        fontSize: compacto ? 28 : 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Cores.texto,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entrar
                          ? 'Entre com suas credenciais para acessar o painel operacional.'
                          : 'Preencha seus dados. O gestor municipal analisa e libera o seu acesso.',
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.4,
                        color: Cores.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _SeletorModo(
                      modo: _modo,
                      onSelecionar: _enviando ? null : _trocarModo,
                    ),
                    const SizedBox(height: 28),
                    if (_sucesso != null) ...[
                      _Aviso(texto: _sucesso!, sucesso: true),
                      const SizedBox(height: 20),
                    ],
                    ...(entrar ? _camposEntrar() : _camposCriarConta()),
                    if (_erro != null) ...[
                      const SizedBox(height: 20),
                      _Aviso(texto: _erro!, sucesso: false),
                    ],
                    const SizedBox(height: 28),
                    _BotaoPrincipal(
                      rotulo: entrar ? 'Acessar dashboard' : 'Solicitar acesso',
                      carregando: _enviando,
                      onPressed: entrar ? _entrar : _solicitarAcesso,
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Acesso restrito a usuários autorizados pela SEMOB-SCS',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Cores.textoMudo),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _camposEntrar() {
    return [
      if (mostrarPerfisDemo) ...[
        const Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'PERFIS DE DEMONSTRAÇÃO',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Cores.textoSecundario,
              ),
            ),
            Text(
              'Clique para preencher',
              style: TextStyle(fontSize: 13, color: Cores.textoMudo),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final perfil in Perfil.values) ...[
          _CartaoPerfil(
            perfil: perfil,
            email: _emailsDemo[perfil]!,
            selecionado: _email.text.trim().toLowerCase() == _emailsDemo[perfil],
            onTap: _enviando ? null : () => _preencher(perfil),
          ),
          const SizedBox(height: 12),
        ],
        const _AvisoSenhaDemo(),
        const SizedBox(height: 28),
      ],
      AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Campo(
              rotulo: 'E-mail institucional',
              child: TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: _decoracao('nome@saocaetanodosul.sp.gov.br'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _focoSenha.requestFocus(),
              ),
            ),
            const SizedBox(height: 20),
            _Campo(
              rotulo: 'Senha',
              acao: _LinkTexto(
                texto: 'Esqueci minha senha',
                onTap: () => _mostrarEsqueciSenha(context),
              ),
              child: TextField(
                controller: _senha,
                focusNode: _focoSenha,
                obscureText: !_senhaVisivel,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                decoration: _decoracao('Digite sua senha', sufixo: _alternarSenha()),
                onSubmitted: (_) => _entrar(),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _camposCriarConta() {
    return [
      _Campo(
        rotulo: 'Nome completo',
        child: TextField(
          controller: _nome,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: _decoracao('Digite seu nome'),
        ),
      ),
      const SizedBox(height: 20),
      _Campo(
        rotulo: 'E-mail institucional',
        child: TextField(
          controller: _emailCadastro,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: _decoracao('nome@saocaetanodosul.sp.gov.br'),
        ),
      ),
      const SizedBox(height: 20),
      _Campo(
        rotulo: 'Setor',
        child: DropdownButtonFormField<Perfil>(
          initialValue: _setor,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Cores.texto),
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          decoration: _decoracao('Selecione seu setor'),
          hint: const Text(
            'Selecione seu setor',
            style: TextStyle(fontSize: 15.5, color: Cores.texto),
          ),
          style: const TextStyle(fontSize: 15.5, color: Cores.texto),
          items: [
            // Operações e Financeiro primeiro: são os pedidos mais comuns.
            for (final perfil in [Perfil.operacoes, Perfil.financeiro, Perfil.gestor])
              DropdownMenuItem(value: perfil, child: Text(perfil.setor)),
          ],
          onChanged: (perfil) => setState(() => _setor = perfil),
        ),
      ),
      const SizedBox(height: 20),
      _Campo(
        rotulo: 'Senha',
        child: TextField(
          controller: _senhaCadastro,
          obscureText: !_senhaVisivel,
          autofillHints: const [AutofillHints.newPassword],
          decoration: _decoracao('Mínimo de 6 caracteres', sufixo: _alternarSenha()),
        ),
      ),
      const SizedBox(height: 20),
      InkWell(
        onTap: () => setState(() => _aceitouTermos = !_aceitouTermos),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _aceitouTermos,
                activeColor: Cores.primaria,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (valor) => setState(() => _aceitouTermos = valor ?? false),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Declaro que as informações são verdadeiras e concordo com os '
                'termos de uso e a política de privacidade.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Cores.textoSecundario,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _alternarSenha() {
    return IconButton(
      tooltip: _senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
      icon: Icon(
        _senhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: Cores.textoMudo,
        size: 20,
      ),
      onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
    );
  }
}

InputDecoration _decoracao(String dica, {Widget? sufixo}) {
  OutlineInputBorder borda(Color cor, [double largura = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cor, width: largura),
      );

  return InputDecoration(
    hintText: dica,
    hintStyle: const TextStyle(fontSize: 15.5, color: Cores.textoMudo),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    suffixIcon: sufixo == null
        ? null
        : Padding(padding: const EdgeInsets.only(right: 6), child: sufixo),
    border: borda(Cores.borda),
    enabledBorder: borda(Cores.borda),
    focusedBorder: borda(Cores.primaria, 1.6),
  );
}

void _mostrarEsqueciSenha(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Esqueci minha senha'),
      content: const SizedBox(
        width: 420,
        child: Text(
          'A recuperação de senha pelo próprio app ainda não está disponível. '
          'Procure a equipe da SEMOB-SCS para redefinir o seu acesso.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}

/// Ícone do ônibus com o nome da secretaria.
class _Marca extends StatelessWidget {
  final bool fundoEscuro;

  const _Marca({this.fundoEscuro = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: fundoEscuro ? Colors.white.withValues(alpha: 0.12) : Cores.primaria,
            borderRadius: BorderRadius.circular(14),
            border: fundoEscuro
                ? Border.all(color: Colors.white.withValues(alpha: 0.16))
                : null,
          ),
          child: const Icon(Icons.directions_bus_outlined, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SEMOB-SCS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: fundoEscuro ? Colors.white : Cores.texto,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Secretaria de Mobilidade Urbana',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: fundoEscuro ? _textoClaroMudo : Cores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lado azul da tela larga: apresentação e números reais da operação.
class _PainelInstitucional extends StatelessWidget {
  final Future<Destaques> destaques;

  const _PainelInstitucional({required this.destaques});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Cores.primaria,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -170,
              right: -150,
              child: _Anel(
                tamanho: 460,
                espessura: 70,
                cor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Positioned(
              left: -200,
              bottom: -280,
              child: _Anel(
                tamanho: 640,
                espessura: 90,
                cor: const Color(0xFF2A9BC0).withValues(alpha: 0.22),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final largo = constraints.maxWidth >= 620;

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          largo ? 52 : 40,
                          40,
                          largo ? 52 : 40,
                          36,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Marca(),
                            const Spacer(),
                            const SizedBox(height: 40),
                            const _SeloPlataforma(),
                            const SizedBox(height: 28),
                            Text(
                              'Decisões mais rápidas para uma cidade em movimento.',
                              style: TextStyle(
                                fontSize: largo ? 44 : 36,
                                height: 1.18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              'Monitore a operação do transporte municipal, acompanhe '
                              'indicadores e identifique anomalias em um único ambiente.',
                              style: TextStyle(fontSize: 18, height: 1.6, color: _textoClaro),
                            ),
                            const SizedBox(height: 36),
                            _numeros(),
                            const SizedBox(height: 40),
                            const Spacer(),
                            const Text(
                              'Prefeitura Municipal de São Caetano do Sul',
                              style: TextStyle(fontSize: 14, color: _textoClaroMudo),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _numeros() {
    return FutureBuilder(
      future: destaques,
      builder: (context, snapshot) {
        final dados = snapshot.data;
        final cumprimento = dados?.cumprimento;
        final dadosAte = dados?.dadosAte;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CartaoDestaque(
                    icone: Icons.directions_bus_outlined,
                    valor: dados?.linhasAtivas?.toString() ?? '—',
                    rotulo: 'linhas ativas',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CartaoDestaque(
                    icone: Icons.grid_view_outlined,
                    valor: cumprimento == null ? '—' : formatarPercentual(cumprimento),
                    rotulo: 'cumprimento',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CartaoDestaque(
                    icone: Icons.event_available_outlined,
                    valor: dadosAte == null ? '—' : formatarDiaMes(dadosAte),
                    rotulo: 'dados até',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              snapshot.hasError
                  ? 'Números indisponíveis: a API não respondeu.'
                  : 'Linhas e cumprimento dos últimos 30 dias com dados.',
              style: const TextStyle(fontSize: 12.5, color: _textoClaroMudo),
            ),
          ],
        );
      },
    );
  }
}

class _Anel extends StatelessWidget {
  final double tamanho;
  final double espessura;
  final Color cor;

  const _Anel({required this.tamanho, required this.espessura, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cor, width: espessura),
      ),
    );
  }
}

class _SeloPlataforma extends StatelessWidget {
  const _SeloPlataforma();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF3DDC97),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'Plataforma integrada de mobilidade',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoDestaque extends StatelessWidget {
  final IconData icone;
  final String valor;
  final String rotulo;

  const _CartaoDestaque({required this.icone, required this.valor, required this.rotulo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 24, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(rotulo, style: const TextStyle(fontSize: 14, color: _textoClaro)),
        ],
      ),
    );
  }
}

/// Alternância "Entrar" / "Criar conta".
class _SeletorModo extends StatelessWidget {
  final _Modo modo;
  final ValueChanged<_Modo>? onSelecionar;

  const _SeletorModo({required this.modo, required this.onSelecionar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE4E9F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: _botao(_Modo.entrar, 'Entrar')),
          Expanded(child: _botao(_Modo.criarConta, 'Criar conta')),
        ],
      ),
    );
  }

  Widget _botao(_Modo valor, String rotulo) {
    final selecionado = valor == modo;

    return Semantics(
      button: true,
      selected: selecionado,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selecionado ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selecionado
              ? [
                  BoxShadow(
                    color: Cores.texto.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onSelecionar == null ? null : () => onSelecionar!(valor),
            child: SizedBox(
              height: 48,
              child: Center(
                child: Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: selecionado ? FontWeight.w700 : FontWeight.w600,
                    color: selecionado ? Cores.primaria : Cores.textoSecundario,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartaoPerfil extends StatelessWidget {
  final Perfil perfil;
  final String email;
  final bool selecionado;
  final VoidCallback? onTap;

  const _CartaoPerfil({
    required this.perfil,
    required this.email,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selecionado ? Cores.primaria : Cores.borda,
        width: selecionado ? 1.6 : 1,
      ),
    );

    return Material(
      color: Colors.white,
      shape: forma,
      child: InkWell(
        customBorder: forma,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selecionado ? Cores.infoFundo : Cores.fundo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  perfil.sigla,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selecionado ? Cores.primaria : Cores.textoSecundario,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perfil.rotulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Cores.texto,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${perfil.acesso} · $email',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Cores.textoMudo),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Cores.textoMudo, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisoSenhaDemo extends StatelessWidget {
  const _AvisoSenhaDemo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF6E7B0)),
      ),
      child: const Text.rich(
        TextSpan(
          text: 'Senha dos perfis: ',
          children: [
            TextSpan(
              text: _senhaDemo,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        style: TextStyle(fontSize: 14, color: Color(0xFF8A4B00)),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final String rotulo;
  final Widget? acao;
  final Widget child;

  const _Campo({required this.rotulo, this.acao, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                rotulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Cores.texto,
                ),
              ),
            ),
            ?acao,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _LinkTexto extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;

  const _LinkTexto({required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(
          texto,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Cores.primaria,
          ),
        ),
      ),
    );
  }
}

/// Mensagem de erro (vermelha) ou de sucesso (verde) acima do botão.
class _Aviso extends StatelessWidget {
  final String texto;
  final bool sucesso;

  const _Aviso({required this.texto, required this.sucesso});

  @override
  Widget build(BuildContext context) {
    final cor = sucesso ? Cores.sucesso : Cores.critico;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sucesso ? Cores.sucessoFundo : Cores.criticoFundo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            sucesso ? Icons.check_circle_outline : Icons.error_outline,
            size: 20,
            color: cor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 14, height: 1.4, color: cor),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoPrincipal extends StatelessWidget {
  final String rotulo;
  final bool carregando;
  final VoidCallback onPressed;

  const _BotaoPrincipal({
    required this.rotulo,
    required this.carregando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Cores.primaria.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: FilledButton(
          onPressed: carregando ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Cores.primaria,
            disabledBackgroundColor: Cores.primaria.withValues(alpha: 0.75),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: carregando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rotulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward, size: 20, color: Colors.white),
                  ],
                ),
        ),
      ),
    );
  }
}

class _BotaoAjuda extends StatelessWidget {
  const _BotaoAjuda();

  @override
  Widget build(BuildContext context) {
    const forma = CircleBorder(side: BorderSide(color: Cores.borda));

    return Tooltip(
      message: 'Ajuda',
      child: Material(
        color: Colors.white,
        shape: forma,
        elevation: 2,
        child: InkWell(
          customBorder: forma,
          onTap: () => _mostrarAjuda(context),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Cores.texto,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarAjuda(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Como acessar'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cada perfil vê uma parte do painel:'),
              const SizedBox(height: 12),
              for (final perfil in Perfil.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${perfil.rotulo}: ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: perfil.acesso),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Ainda não tem conta? Use "Criar conta". O gestor municipal '
                'analisa a solicitação e libera o acesso.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}
