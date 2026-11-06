import express from 'express';
import cors from 'cors';

import { detectarAnomalias } from './anomalias.js';
import { configurarContasDemo, exigirLogin, rotasAuth, rotasUsuarios } from './auth.js';
import { conectar, diasLinha, diasSistema, falhasViagem } from './db.js';
import {
  DIAS_POR_PERIODO,
  formatarData,
  janela,
  janelaAnterior,
  parseData,
} from './periodos.js';

// Os relatórios não trazem receita: ela é estimada como pagantes x tarifa.
const TARIFA = Number(process.env.TARIFA ?? 5);

const app = express();
app.use(cors());
app.use(express.json());

const TURNOS = ['manha', 'tarde', 'noite'];

const somaSistema = {
  quilometragem: { $sum: '$quilometragem.total' },
  quilometragemProdutiva: { $sum: '$quilometragem.produtiva' },
  quilometragemImprodutiva: { $sum: '$quilometragem.improdutiva' },
  viagensProgramadas: { $sum: '$viagens.programadas' },
  viagensRealizadas: { $sum: '$viagens.realizadas' },
  passageirosCatraca: { $sum: '$passageiros.catraca' },
  passageirosAntecipados: { $sum: '$passageiros.antecipados' },
  passageirosNaoPagantes: { $sum: '$passageiros.naoPagantes' },
  creditosVendidos: { $sum: '$creditos.vendas' },
  creditosUtilizados: { $sum: '$creditos.utilizacao' },
  frotaMedia: { $avg: '$frota.veiculos' },
  dias: { $sum: 1 },
  diasComPassageiros: { $sum: { $cond: [{ $gt: ['$passageiros', null] }, 1, 0] } },
  ...Object.fromEntries(
    TURNOS.flatMap((turno) => [
      [`${turno}Programadas`, { $sum: `$turnos.${turno}.programadas` }],
      [`${turno}Realizadas`, { $sum: `$turnos.${turno}.realizadas` }],
    ]),
  ),
};

const arredondar = (valor, casas = 1) => Math.round(valor * 10 ** casas) / 10 ** casas;

/** Converte o resultado do $group no formato de indicadores usado pelo app. */
function indicadores(soma) {
  if (!soma) soma = Object.fromEntries(Object.keys(somaSistema).map((chave) => [chave, 0]));
  const pagantes = soma.passageirosCatraca + soma.passageirosAntecipados;

  return {
    quilometragem: arredondar(soma.quilometragem),
    quilometragemProdutiva: arredondar(soma.quilometragemProdutiva),
    quilometragemImprodutiva: arredondar(soma.quilometragemImprodutiva),
    viagensProgramadas: soma.viagensProgramadas,
    viagensRealizadas: soma.viagensRealizadas,
    passageirosCatraca: soma.passageirosCatraca,
    passageirosAntecipados: soma.passageirosAntecipados,
    passageirosPagantes: pagantes,
    passageirosNaoPagantes: soma.passageirosNaoPagantes,
    receita: arredondar(pagantes * TARIFA, 2),
    creditosVendidos: arredondar(soma.creditosVendidos, 2),
    creditosUtilizados: arredondar(soma.creditosUtilizados, 2),
    frotaMedia: arredondar(soma.frotaMedia ?? 0),
    dias: soma.dias,
    diasComPassageiros: soma.diasComPassageiros,
    turnos: Object.fromEntries(
      TURNOS.map((turno) => [
        turno,
        { programadas: soma[`${turno}Programadas`], realizadas: soma[`${turno}Realizadas`] },
      ]),
    ),
  };
}

function filtroJanela({ inicio, fim }) {
  return { data: { $gte: inicio, $lte: fim } };
}

async function totais(intervalo) {
  const [resultado] = await diasSistema()
    .aggregate([{ $match: filtroJanela(intervalo) }, { $group: { _id: null, ...somaSistema } }])
    .toArray();
  return indicadores(resultado);
}

// Lê ?periodo= e ?data= da query. Sem data, usa o último dia com registros.
async function lerParametros(req, res) {
  const periodo = req.query.periodo ?? 'diario';
  if (!(periodo in DIAS_POR_PERIODO)) {
    res.status(400).json({ erro: `Período inválido. Use: ${Object.keys(DIAS_POR_PERIODO).join(', ')}` });
    return null;
  }

  let fim;
  if (req.query.data) {
    fim = parseData(req.query.data);
    if (!fim) {
      res.status(400).json({ erro: 'Data inválida. Use o formato AAAA-MM-DD.' });
      return null;
    }
  } else {
    const ultimo = await diasSistema().find().sort({ data: -1 }).limit(1).next();
    if (!ultimo) {
      res.status(404).json({ erro: 'Nenhum registro no banco. Rode "npm run importar" na pasta server.' });
      return null;
    }
    fim = ultimo.data;
  }

  return { periodo, fim };
}

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.use('/api/auth', rotasAuth);
app.use('/api/usuarios', rotasUsuarios);

// Números da tela de login (públicos): linhas que rodaram e cumprimento nos últimos 30 dias.
app.get('/api/destaques', async (req, res) => {
  const ultimo = await diasSistema().find().sort({ data: -1 }).limit(1).next();
  if (!ultimo) return res.json({ linhasAtivas: null, cumprimento: null, dadosAte: null });

  const mes = janela('mensal', ultimo.data);
  const linhasAtivas = await diasLinha().distinct('linha.codigo', {
    ...filtroJanela(mes),
    'viagens.realizadas': { $gt: 0 },
  });
  const { viagensProgramadas, viagensRealizadas } = await totais(mes);

  res.json({
    linhasAtivas: linhasAtivas.length,
    cumprimento: viagensProgramadas ? arredondar(viagensRealizadas / viagensProgramadas, 4) : null,
    dadosAte: formatarData(ultimo.data),
  });
});

// Daqui em diante, todas as rotas /api exigem login.
app.use('/api', exigirLogin);

app.get('/api/resumo', async (req, res) => {
  const parametros = await lerParametros(req, res);
  if (!parametros) return;

  const atual = janela(parametros.periodo, parametros.fim);
  const anterior = janelaAnterior(parametros.periodo, parametros.fim);

  res.json({
    periodo: parametros.periodo,
    inicio: formatarData(atual.inicio),
    fim: formatarData(atual.fim),
    tarifa: TARIFA,
    atual: await totais(atual),
    anterior: await totais(anterior),
  });
});

app.get('/api/serie', async (req, res) => {
  const parametros = await lerParametros(req, res);
  if (!parametros) return;

  const pontos = await diasSistema()
    .aggregate([
      { $match: filtroJanela(janela(parametros.periodo, parametros.fim)) },
      { $group: { _id: '$data', ...somaSistema } },
      { $sort: { _id: 1 } },
    ])
    .toArray();

  res.json(pontos.map((ponto) => ({ data: formatarData(ponto._id), ...indicadores(ponto) })));
});

app.get('/api/linhas', async (req, res) => {
  const parametros = await lerParametros(req, res);
  if (!parametros) return;

  const linhas = await diasLinha()
    .aggregate([
      { $match: filtroJanela(janela(parametros.periodo, parametros.fim)) },
      {
        $group: {
          _id: '$linha.codigo',
          nome: { $first: '$linha.nome' },
          quilometragem: { $sum: '$quilometragem' },
          viagensRealizadas: { $sum: '$viagens.realizadas' },
          viagensNaoRealizadas: { $sum: '$viagens.naoRealizadas' },
        },
      },
      { $sort: { _id: 1 } },
    ])
    .toArray();

  res.json(
    linhas.map((linha) => ({
      codigo: linha._id,
      nome: linha.nome,
      quilometragem: arredondar(linha.quilometragem),
      viagensRealizadas: linha.viagensRealizadas,
      viagensProgramadas: linha.viagensRealizadas + linha.viagensNaoRealizadas,
    })),
  );
});

app.get('/api/falhas', async (req, res) => {
  const parametros = await lerParametros(req, res);
  if (!parametros) return;

  const falhas = await falhasViagem()
    .find(filtroJanela(janela(parametros.periodo, parametros.fim)), { projection: { _id: 0 } })
    .sort({ data: -1, inicioProgramado: 1 })
    .toArray();

  res.json(falhas.map((falha) => ({ ...falha, data: formatarData(falha.data) })));
});

app.get('/api/anomalias', async (req, res) => {
  const parametros = await lerParametros(req, res);
  if (!parametros) return;

  const { inicio, fim } = janela(parametros.periodo, parametros.fim);
  const ate = { data: { $lte: fim } };
  const anomalias = detectarAnomalias({
    dias: await diasSistema().find(ate).toArray(),
    linhas: await diasLinha().find(ate).toArray(),
    inicio,
    fim,
  });

  res.json(
    anomalias.map((anomalia) => ({
      ...anomalia,
      data: formatarData(anomalia.data),
      valor: arredondar(anomalia.valor),
      esperado: arredondar(anomalia.esperado),
      desvio: arredondar(anomalia.desvio, 3),
    })),
  );
});

app.use((erro, req, res, next) => {
  console.error(erro);
  res.status(500).json({ erro: 'Erro interno no servidor.' });
});

const porta = Number(process.env.PORT ?? 3000);

await conectar();
await configurarContasDemo(process.env.PERFIS_DEMO !== 'false');
app.listen(porta, () => {
  console.log(`API SEMOB rodando em http://localhost:${porta}`);
});
