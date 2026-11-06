# SEMOB-SCS — Dashboard de Operação de Transporte

Projeto Integrador Interdisciplinar (TTI206 · 2026-2) — Instituto Mauá de Tecnologia,
em parceria com a Secretaria de Mobilidade Urbana de São Caetano do Sul.

## Arquitetura

```
dados/ (relatórios HTML)  →  npm run importar  →  MongoDB  →  API Node/Express (server/)  →  Flutter (lib/)
```

O app nunca acessa o MongoDB diretamente: no navegador isso não é possível e
exporia as credenciais do banco.

## Como rodar

Pré-requisitos: Flutter, Node.js 22+ e MongoDB rodando em `127.0.0.1:27017`.

1. API (primeira vez):

   ```
   cd server
   npm install
   copy .env.example .env
   npm run importar
   ```

2. Subir a API (deixe o terminal aberto):

   ```
   cd server
   npm start
   ```

3. Em outro terminal, na raiz do projeto:

   ```
   flutter run -d chrome
   ```

Para apontar o app para outra API: `flutter run --dart-define=API_URL=http://endereco:3000`
(no emulador Android use `http://10.0.2.2:3000`).

## Login e perfis

O app abre na tela de login. As contas ficam na coleção `usuarios` do MongoDB
(senhas com hash scrypt) e cada login abre uma sessão de 8 horas na coleção `sessoes`.

| Perfil | Abas |
| --- | --- |
| Gestor Municipal | todas + **Usuários** (aprova, recusa e revoga contas) |
| Equipe de Operações | Visão geral, Operações, Anomalias |
| Equipe Financeira | Visão geral, Passagens, Finanças |

- **Criar conta** envia uma solicitação pendente. A pessoa só entra depois que um
  gestor aprova na aba Usuários, onde também pode trocar o perfil pedido.
- As rotas de dados exigem login. A divisão por abas é feita no app; só a gestão
  de contas é restrita ao gestor também na API.
- **Contas de teste** (senha `semob2026`): `gestor@`, `operacoes@` e
  `financeiro@semob.scs.gov.br`. São criadas ao subir a API e aparecem na tela de login.

Na versão final, sem contas de teste:

1. `PERFIS_DEMO=false` no `server/.env`: as contas de teste são apagadas ao subir a API.
2. `flutter run --dart-define=PERFIS_DEMO=false`: esconde os perfis da tela de login.
3. Crie o primeiro gestor: `npm run criar-gestor -- "Nome Completo" email senha` (pasta `server`).

Ainda não há recuperação de senha pelo app.

## Dados

A pasta `dados/` tem os relatórios do **Smart Report** (Smart Data) enviados pela
SEMOB, salvos como HTML pelo navegador, organizados por mês (`Julho_2026/Mensal`,
`Agosto_2026/Quinzenal`, ...). Cobrem de 01/07 a 14/09/2026.

Para incluir relatórios novos, coloque-os em `dados/<Mês>_<Ano>/<Mensal|Quinzenal>/`
e rode `npm run importar` na pasta `server`. O importador relê tudo e recria as
coleções; dias repetidos entre mensal e quinzenal são mesclados.

| Relatório | Vai para | Conteúdo |
| --- | --- | --- |
| `Mensal_AAAAMM` / `Quinzenal_AAAAMM` | `operacao_diaria` | frota, viagens programadas/realizadas, km produtivo/improdutivo |
| `*_Linhas_*` | `operacao_linhas` | km produtivo e viagens por linha e dia |
| `*_FCV_*` | `operacao_diaria.turnos` | viagens programadas/realizadas por turno |
| `*_Resumo_FxHr_*` | `operacao_diaria.faixas` | veículos e viagens por hora |
| `Passageiros*` | `operacao_diaria.passageiros` | catraca, antecipados, não pagantes |
| `Saldos*` | `operacao_diaria.creditos` | venda e utilização de créditos de cartão |
| `*_Viag_NRealiz/Ninic/NTerm_*` | `viagens_falhas` | viagens que falharam (sem a coluna Motorista) |
| `*_Viagens_*`, `*_FxHr_*` | — | detalhe por viagem; ainda não importados |

Limitações dos relatórios:

- **Passageiros só existem para o sistema todo**, não por linha.
- **Não há receita apurada.** A API estima: pagantes (catraca + antecipados) × `TARIFA`
  (`server/.env`, padrão R$ 5,00, confirmado pelo relatório de saldos).
- Viagens programadas **por linha** = realizadas + não realizadas (o total do
  sistema vem pronto no relatório).
- Não há passageiros de 01 a 14/07/2026.
- Os nomes das linhas ficam em `server/src/linhas.js`.

## Endpoints

Rotas públicas e de conta:

| Rota | Retorno |
| --- | --- |
| `GET /api/health` | status da API |
| `GET /api/destaques` | linhas ativas e cumprimento dos últimos 30 dias (tela de login) |
| `POST /api/auth/login` | `{email, senha}` → `{token, usuario}` |
| `POST /api/auth/solicitar` | `{nome, email, perfil, senha}` → cria conta pendente |
| `GET /api/auth/eu` · `POST /api/auth/sair` | usuário da sessão · encerra a sessão |
| `GET /api/usuarios` | contas e solicitações (só gestor) |
| `PATCH /api/usuarios/:id` | `{status: aprovado\|recusado, perfil?}` (só gestor) |

As rotas de dados exigem `Authorization: Bearer <token>`, aceitam
`periodo=diario|semanal|mensal` (janelas móveis de 1, 7 e 30 dias) e
`data=AAAA-MM-DD` opcional (padrão: último dia com registros).

| Rota | Retorno |
| --- | --- |
| `GET /api/resumo` | totais do sistema no período e no período anterior |
| `GET /api/serie` | totais do sistema por dia |
| `GET /api/linhas` | km e viagens por linha |
| `GET /api/falhas` | viagens não realizadas, não iniciadas ou não terminadas |
| `GET /api/anomalias` | desvios detectados (ver `server/src/anomalias.js`) |

## Detecção de anomalias

A referência é a mediana dos **28 dias anteriores do mesmo tipo de dia** (útil,
sábado, domingo), para acompanhar mudanças de patamar como férias escolares:

- **Passageiros (sistema):** total do dia mais de 30% acima ou abaixo da referência.
- **Viagens (linha):** cumprimento abaixo de 95% (crítico abaixo de 85%), ou
  número de viagens mais de 30% fora da referência.
- **Quilometragem (linha):** km por viagem mais de 15% fora da referência.

Desvios de 50% ou mais são **críticos**; os demais são **alertas**. Feriados
aparecem como anomalias (ex.: 07/09).

## Testes

```
flutter test
```

`test/home_page_test.dart` abre todas as abas nos três períodos, em tela de
desktop e de celular, usando respostas salvas da API (`test/fixtures/`), e
falha se algum layout estourar. Também confere as abas de cada perfil e a
aprovação de uma solicitação. `test/login_page_test.dart` cobre a tela de login
e o cadastro. Depois de mudar a API, atualize os fixtures
salvando de novo as respostas de `/api/*`.
