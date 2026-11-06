import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../theme/tema.dart';

class AbaMenu {
  final String rotulo;
  final IconData icone;

  /// Número em destaque ao lado do rótulo (ex.: solicitações pendentes).
  final int contador;

  const AbaMenu(this.rotulo, this.icone, {this.contador = 0});
}

class AppHeader extends StatelessWidget {
  final List<AbaMenu> abas;
  final int abaSelecionada;
  final ValueChanged<int> onSelecionarAba;

  /// Texto da situação dos dados, ex.: "Dados até 30/10". Null enquanto carrega.
  final String? situacaoDados;
  final bool erro;

  final Usuario usuario;
  final VoidCallback onSair;

  const AppHeader({
    super.key,
    required this.abas,
    required this.abaSelecionada,
    required this.onSelecionarAba,
    required this.usuario,
    required this.onSair,
    this.situacaoDados,
    this.erro = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Cores.primaria,
      child: Column(
        children: [
          _Centralizado(
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.directions_bus_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SEMOB-SCS',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Inteligência de Mobilidade',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFC9D8EC),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _situacao(compacto: MediaQuery.sizeOf(context).width < 640),
                  const SizedBox(width: 12),
                  _MenuUsuario(
                    usuario: usuario,
                    onSair: onSair,
                    compacto: MediaQuery.sizeOf(context).width < 900,
                  ),
                ],
              ),
            ),
          ),
          // Faixa do menu, mais escura para se destacar do cabeçalho.
          Container(
            color: Cores.primariaEscura,
            child: _Centralizado(
              child: SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: abas.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) =>
                      Center(child: _aba(index)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Em telas estreitas mostra só o indicador colorido, com o texto na dica.
  Widget _situacao({required bool compacto}) {
    final Color cor;
    final String titulo;

    if (erro) {
      cor = const Color(0xFFFF8A80);
      titulo = 'API indisponível';
    } else if (situacaoDados == null) {
      cor = const Color(0xFFC9D8EC);
      titulo = 'Carregando...';
    } else {
      cor = const Color(0xFF3DDC97);
      titulo = 'Sistema operacional';
    }

    final indicador = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
      ),
    );

    if (compacto) {
      return Tooltip(
        message: [titulo, ?situacaoDados].join(' · '),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: indicador,
        ),
      );
    }

    return Row(
      children: [
        indicador,
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (situacaoDados != null)
              Text(
                situacaoDados!,
                style: const TextStyle(
                  color: Color(0xFFC9D8EC),
                  fontSize: 10.5,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _aba(int index) {
    final aba = abas[index];
    final selecionada = index == abaSelecionada;
    final cor = selecionada ? Cores.primaria : Colors.white;
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: selecionada
            ? Colors.white
            : Colors.white.withValues(alpha: 0.28),
      ),
    );

    // Cada aba é um botão: fundo branco na selecionada, contorno nas demais.
    return Semantics(
      button: true,
      selected: selecionada,
      child: Material(
        color: selecionada
            ? Colors.white
            : Colors.white.withValues(alpha: 0.08),
        shape: forma,
        child: InkWell(
          onTap: () => onSelecionarAba(index),
          customBorder: forma,
          hoverColor: selecionada
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.14),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(aba.icone, size: 18, color: cor),
                const SizedBox(width: 8),
                Text(
                  aba.rotulo,
                  style: TextStyle(
                    color: cor,
                    fontSize: 14,
                    fontWeight: selecionada ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                if (aba.contador > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Cores.alertaClaro,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${aba.contador}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Iniciais do usuário logado; o menu mostra nome, perfil e "Sair".
class _MenuUsuario extends StatelessWidget {
  final Usuario usuario;
  final VoidCallback onSair;
  final bool compacto;

  const _MenuUsuario({
    required this.usuario,
    required this.onSair,
    required this.compacto,
  });

  @override
  Widget build(BuildContext context) {
    final iniciais = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        usuario.iniciais,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return PopupMenuButton<void>(
      tooltip: 'Conta',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(usuario.nome, style: Estilos.celulaDestaque),
              Text(usuario.email, style: Estilos.subtituloPainel),
              const SizedBox(height: 4),
              Text(usuario.perfil.rotulo, style: Estilos.celula),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: onSair,
          child: const Row(
            children: [
              Icon(Icons.logout, size: 18, color: Cores.textoSecundario),
              SizedBox(width: 10),
              Text('Sair'),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iniciais,
          if (!compacto) ...[
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuario.nome,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    usuario.perfil.rotulo,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFC9D8EC), fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
          ],
        ],
      ),
    );
  }
}

class _Centralizado extends StatelessWidget {
  final Widget child;

  const _Centralizado({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}
