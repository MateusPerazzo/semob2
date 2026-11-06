// Cria (ou redefine) uma conta de gestor já aprovada.
// Uso: npm run criar-gestor -- "Nome Completo" email@saocaetanodosul.sp.gov.br senha
import { gerarHash, normalizarEmail } from './auth.js';
import { conectar, desconectar, usuarios } from './db.js';

const [nome, emailInformado, senha] = process.argv.slice(2);
const email = normalizarEmail(emailInformado);

if (!nome || !email || !senha || senha.length < 6) {
  console.error('Uso: npm run criar-gestor -- "Nome Completo" email senha (mínimo de 6 caracteres)');
  process.exit(1);
}

await conectar();
await usuarios().updateOne(
  { email },
  {
    $set: { nome, perfil: 'gestor', status: 'aprovado', senha: await gerarHash(senha) },
    $setOnInsert: { email, criadoEm: new Date() },
  },
  { upsert: true },
);
await desconectar();

console.log(`Gestor ${email} pronto para entrar.`);
