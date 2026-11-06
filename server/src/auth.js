import { createHash, randomBytes, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { Router } from 'express';
import { ObjectId } from 'mongodb';

import { sessoes, usuarios } from './db.js';

const scryptAsync = promisify(scrypt);

// gestor: tudo + aprova contas; operacoes: Operações e Anomalias; financeiro: Passagens e Finanças.
export const PERFIS = ['gestor', 'operacoes', 'financeiro'];

const DURACAO_SESSAO_MS = 8 * 60 * 60 * 1000;
const EMAIL_VALIDO = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const SENHA_MINIMA = 6;

// Contas de teste mostradas na tela de login. Desligue com PERFIS_DEMO=false no .env.
export const SENHA_DEMO = 'semob2026';
const CONTAS_DEMO = [
  { nome: 'Gestor Municipal', email: 'gestor@semob.scs.gov.br', perfil: 'gestor' },
  { nome: 'Equipe de Operações', email: 'operacoes@semob.scs.gov.br', perfil: 'operacoes' },
  { nome: 'Equipe Financeira', email: 'financeiro@semob.scs.gov.br', perfil: 'financeiro' },
];

export async function gerarHash(senha) {
  const sal = randomBytes(16);
  const hash = await scryptAsync(senha, sal, 64);
  return `${sal.toString('hex')}:${hash.toString('hex')}`;
}

async function conferirSenha(senha, salvo) {
  const [sal, hash] = salvo.split(':');
  const calculado = await scryptAsync(senha, Buffer.from(sal, 'hex'), 64);
  return timingSafeEqual(calculado, Buffer.from(hash, 'hex'));
}

const hashToken = (token) => createHash('sha256').update(token).digest('hex');
export const normalizarEmail = (email) => String(email ?? '').trim().toLowerCase();

function usuarioPublico(usuario) {
  return {
    id: usuario._id.toString(),
    nome: usuario.nome,
    email: usuario.email,
    perfil: usuario.perfil,
    status: usuario.status,
    criadoEm: usuario.criadoEm,
  };
}

/** Cria as contas de teste que faltarem, ou remove todas se `ativas` for false. */
export async function configurarContasDemo(ativas) {
  const emails = CONTAS_DEMO.map((conta) => conta.email);

  if (!ativas) {
    const removidas = await usuarios().find({ email: { $in: emails } }).toArray();
    await sessoes().deleteMany({ usuarioId: { $in: removidas.map((u) => u._id) } });
    await usuarios().deleteMany({ email: { $in: emails } });
    return;
  }

  for (const conta of CONTAS_DEMO) {
    await usuarios().updateOne(
      { email: conta.email },
      {
        $setOnInsert: {
          ...conta,
          senha: await gerarHash(SENHA_DEMO),
          status: 'aprovado',
          criadoEm: new Date(),
        },
      },
      { upsert: true },
    );
  }
}

/** Exige o cabeçalho "Authorization: Bearer <token>" de uma sessão válida. */
export async function exigirLogin(req, res, next) {
  const [tipo, token] = (req.get('authorization') ?? '').split(' ');
  if (tipo !== 'Bearer' || !token) {
    return res.status(401).json({ erro: 'Faça login para continuar.' });
  }

  const sessao = await sessoes().findOne({ token: hashToken(token), expiraEm: { $gt: new Date() } });
  const usuario = sessao && (await usuarios().findOne({ _id: sessao.usuarioId, status: 'aprovado' }));
  if (!usuario) {
    return res.status(401).json({ erro: 'Sua sessão expirou. Entre novamente.' });
  }

  req.usuario = usuario;
  req.sessao = sessao;
  next();
}

export function exigirPerfil(...perfis) {
  return (req, res, next) => {
    if (!perfis.includes(req.usuario.perfil)) {
      return res.status(403).json({ erro: 'Seu perfil não tem acesso a esta área.' });
    }
    next();
  };
}

export const rotasAuth = Router();

rotasAuth.post('/login', async (req, res) => {
  const email = normalizarEmail(req.body?.email);
  const senha = String(req.body?.senha ?? '');
  const usuario = await usuarios().findOne({ email });

  if (!usuario || !(await conferirSenha(senha, usuario.senha))) {
    return res.status(401).json({ erro: 'E-mail ou senha incorretos.' });
  }
  if (usuario.status === 'pendente') {
    return res.status(403).json({ erro: 'Sua solicitação de acesso ainda aguarda a aprovação do gestor.' });
  }
  if (usuario.status !== 'aprovado') {
    return res.status(403).json({ erro: 'Seu acesso não foi liberado. Procure o gestor municipal da SEMOB-SCS.' });
  }

  const token = randomBytes(32).toString('base64url');
  await sessoes().insertOne({
    token: hashToken(token),
    usuarioId: usuario._id,
    expiraEm: new Date(Date.now() + DURACAO_SESSAO_MS),
  });

  res.json({ token, usuario: usuarioPublico(usuario) });
});

rotasAuth.post('/solicitar', async (req, res) => {
  const nome = String(req.body?.nome ?? '').trim();
  const email = normalizarEmail(req.body?.email);
  const perfil = req.body?.perfil;
  const senha = String(req.body?.senha ?? '');

  const erro = !nome
    ? 'Informe seu nome completo.'
    : !EMAIL_VALIDO.test(email)
      ? 'Informe um e-mail válido.'
      : !PERFIS.includes(perfil)
        ? 'Selecione seu setor.'
        : senha.length < SENHA_MINIMA
          ? `A senha deve ter pelo menos ${SENHA_MINIMA} caracteres.`
          : null;
  if (erro) return res.status(400).json({ erro });

  try {
    await usuarios().insertOne({
      nome,
      email,
      perfil,
      senha: await gerarHash(senha),
      status: 'pendente',
      criadoEm: new Date(),
    });
  } catch (falha) {
    if (falha.code === 11000) {
      return res.status(409).json({ erro: 'Já existe uma conta ou solicitação com este e-mail.' });
    }
    throw falha;
  }

  res.status(201).json({ mensagem: 'Solicitação enviada. Aguarde a aprovação do gestor.' });
});

rotasAuth.get('/eu', exigirLogin, (req, res) => {
  res.json(usuarioPublico(req.usuario));
});

rotasAuth.post('/sair', exigirLogin, async (req, res) => {
  await sessoes().deleteOne({ _id: req.sessao._id });
  res.status(204).end();
});

// Gestão de contas: só o gestor.
export const rotasUsuarios = Router();
rotasUsuarios.use(exigirLogin, exigirPerfil('gestor'));

rotasUsuarios.get('/', async (req, res) => {
  const lista = await usuarios().find().sort({ criadoEm: -1 }).toArray();
  res.json(lista.map(usuarioPublico));
});

// Aprova, recusa ou revoga uma conta e, opcionalmente, ajusta o perfil.
rotasUsuarios.patch('/:id', async (req, res) => {
  if (!ObjectId.isValid(req.params.id)) {
    return res.status(404).json({ erro: 'Usuário não encontrado.' });
  }
  const id = new ObjectId(req.params.id);
  if (id.equals(req.usuario._id)) {
    return res.status(400).json({ erro: 'Você não pode alterar a sua própria conta.' });
  }

  const alteracoes = {};
  const { status, perfil } = req.body ?? {};
  if (status !== undefined) {
    if (!['aprovado', 'recusado'].includes(status)) {
      return res.status(400).json({ erro: 'Situação inválida. Use aprovado ou recusado.' });
    }
    alteracoes.status = status;
  }
  if (perfil !== undefined) {
    if (!PERFIS.includes(perfil)) {
      return res.status(400).json({ erro: `Perfil inválido. Use: ${PERFIS.join(', ')}.` });
    }
    alteracoes.perfil = perfil;
  }
  if (!Object.keys(alteracoes).length) {
    return res.status(400).json({ erro: 'Nada para alterar.' });
  }

  const usuario = await usuarios().findOneAndUpdate(
    { _id: id },
    { $set: { ...alteracoes, atualizadoEm: new Date(), atualizadoPor: req.usuario._id } },
    { returnDocument: 'after' },
  );
  if (!usuario) return res.status(404).json({ erro: 'Usuário não encontrado.' });

  // Quem perde o acesso sai na hora.
  if (usuario.status !== 'aprovado') await sessoes().deleteMany({ usuarioId: id });

  res.json(usuarioPublico(usuario));
});
