import { MongoClient } from 'mongodb';

const uri = process.env.MONGODB_URI ?? 'mongodb://127.0.0.1:27017';
const nomeBanco = process.env.MONGODB_DB ?? 'semob';

const client = new MongoClient(uri);
let db;

export async function conectar() {
  if (!db) {
    await client.connect();
    db = client.db(nomeBanco);
    await diasSistema().createIndex({ data: 1 }, { unique: true });
    await diasLinha().createIndex({ data: 1, 'linha.codigo': 1 }, { unique: true });
    await falhasViagem().createIndex({ data: 1 });
    await usuarios().createIndex({ email: 1 }, { unique: true });
    await sessoes().createIndex({ token: 1 }, { unique: true });
    // O MongoDB apaga sozinho as sessões vencidas.
    await sessoes().createIndex({ expiraEm: 1 }, { expireAfterSeconds: 0 });
  }
  return db;
}

export async function desconectar() {
  await client.close();
  db = undefined;
}

// Um documento por dia com os totais do sistema (frota, km, viagens, passageiros, créditos).
export function diasSistema() {
  return db.collection('operacao_diaria');
}

// Um documento por linha por dia (km e viagens).
export function diasLinha() {
  return db.collection('operacao_linhas');
}

// Viagens não realizadas, não iniciadas ou não terminadas.
export function falhasViagem() {
  return db.collection('viagens_falhas');
}

// Contas da plataforma e solicitações de acesso (não são apagadas pelo importador).
export function usuarios() {
  return db.collection('usuarios');
}

// Sessões abertas no login; guarda só o hash do token.
export function sessoes() {
  return db.collection('sessoes');
}
