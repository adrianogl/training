# Servidor de sincronização

API da sincronização entre aparelhos do trAIning: Vercel Functions (Node 22) com Postgres no Neon. Guarda só `id`, `updatedAt`, a marca de apagado e o payload cifrado no aparelho. Spec: `tasks/sync-servidor-spec.md`.

## Variáveis de ambiente

| Nome | Uso |
| --- | --- |
| `DATABASE_URL` | Connection string do Neon. Usada pelas funções e pelo `npm run migrate`. |
| `ADMIN_TOKEN` | Token do painel `/admin`, com 32 caracteres ou mais. Ausente ou mais curto, o painel responde 503. |
| `ADMIN_EMAILS` | E-mails das contas de administrador, separados por vírgula. Eles podem criar conta sem convite e acessam `/app/admin`. |
| `MAX_ACCOUNTS` | Limite total de contas (padrão 3; em produção, 20). Acima dele, `POST /api/v1/account` responde 429 `rate_limited`. |
| `RESEND_API_KEY` | Chave do Resend para os e-mails de confirmação e recuperação de senha. Sem ela, confirmar e recuperar respondem 503 `mail_unavailable`. |
| `MAIL_FROM` | Remetente dos e-mails, de um domínio verificado no Resend. |
| `APP_URL` | Base dos links dos e-mails (`/confirmar`, `/redefinir-senha`). |
| `DATA_KEY` | Chave de 32 bytes em base64url que cifra a sessão da Garmin (e os dados de saúde, nos próximos módulos). Gerar com `node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))"`. Sem ela, as rotas da Garmin respondem 503. Trocar a chave invalida o que já foi cifrado. |
| `MAX_ACCOUNT_BYTES` | Cota de payload por conta em bytes (padrão 52428800, 50 MB). Push que passa da cota responde 413 `quota_exceeded` e não grava nada. |

## Comandos

```
npm --prefix server ci
npm --prefix server test          # Vitest contra PGlite, sem rede
npm --prefix server run typecheck
npm --prefix server run test:concurrency   # push concorrente em Postgres 17 real (Docker, imagem postgres:17-alpine já baixada)
DATABASE_URL=... npm --prefix server run migrate
```

## Rotas

Todas exigem `Authorization: Bearer <32 bytes em base64url sem padding>`. A conta é o `sha256` desses bytes. As rotas de conta usam a chave de conta; só o `GET /api/v1/watch/readiness` usa o token do relógio.

| Rota | Resposta |
| --- | --- |
| `POST /api/v1/account` | 201 `{"created":true}`, 200 `{"created":false}`, 429 depois de 10 contas novas por IP em uma hora ou com `MAX_ACCOUNTS` atingido |
| `DELETE /api/v1/account` | 204; 401 se a conta não existe |
| `GET /api/v1/changes?since=<seq>` | `{"records":[...],"cursor":n,"hasMore":bool}`, em ordem de `seq`, até 500 registros e 3 MB de payload por página (sempre pelo menos 1) |
| `POST /api/v1/changes` | `{"cursor":n,"ignored":[{"kind","id"}]}`; até 100 registros, payload até 1 MB, corpo até 4 MB; 413 `quota_exceeded` acima de `MAX_ACCOUNT_BYTES` (push que não aumenta o uso, como tombstone, sempre passa) |
| `PUT /api/v1/watch/token` | Corpo `{"tokenHash":"<sha256 hex minúsculo dos 32 bytes do token do relógio>"}`. 204; troca o token anterior da conta (um por conta). 400 `invalid_token_hash`, 409 `token_conflict` se o hash já é de outra conta |
| `DELETE /api/v1/watch/token` | 204, com ou sem token cadastrado |
| `PUT /api/v1/watch/readiness` | Corpo `{"day":"YYYY-MM-DD","score":63,"verdict":"Moderado"}`. 204; upsert da nota da conta. 400 `invalid_day`, `invalid_score` (inteiro 0–100) ou `invalid_verdict` (1 a 24 caracteres) |
| `GET /api/v1/watch/readiness` | `Authorization: Bearer <token do relógio>`. 200 `{"day","score","verdict"}`, 404 `no_readiness` sem nota, 401 token desconhecido ou chave de conta. Sempre `Cache-Control: no-store` |

Erros voltam como `{"error":"<código>"}`.

A criação de conta roda numa transação com advisory lock global: o limite por IP e o `MAX_ACCOUNTS` são checados e gravados sem corrida.

O token do relógio tem o mesmo formato da chave de conta e o servidor guarda só o `sha256` dele em `watch_tokens`. A troca roda numa transação com `pg_advisory_xact_lock(hashtext('watch_token:' || account_id))`, então duas trocas simultâneas deixam um token só. O `GET` do relógio, chamado a cada 15 minutos, resolve token, nota e `request_log` numa única query. Apagar a conta apaga token e nota em cascata.

O push roda numa transação que começa com `pg_advisory_xact_lock(hashtext(account_id))`. Pushes da mesma conta ficam em série, então os `seq` de uma conta aparecem na ordem do commit e o pull nunca passa o cursor por cima de um `seq` menor ainda não commitado.

## Painel

`/admin` (rewrite para `/api/admin` no `vercel.json`) mostra status e latência do banco, contas, registros por tipo e apagados, última escrita e `seq`, erros e requisições por hora nas últimas 24 h e as 20 requisições mais recentes. Aceita `Authorization: Bearer <ADMIN_TOKEN>` ou o formulário da própria página, que grava um cookie de sessão `HttpOnly` com o horário de emissão e um HMAC do token. O servidor recusa cookie com mais de 7 dias, e trocar o token derruba as sessões.

Cada request autenticado das rotas v1 grava uma linha em `request_log` (401 e 429 não gravam): método, rota, status, contagem de registros e os 8 primeiros caracteres da conta. Payload, Bearer e IP não entram. Linhas com mais de 7 dias são apagadas na gravação seguinte.

## Deploy

`.vercelignore` envia só `api/`, `src/`, `public/`, `package.json`, `package-lock.json`, `tsconfig.json` e `vercel.json`. O `vercel.json` fixa `framework: null` e `outputDirectory: "public"`, que tem só um `robots.txt` (`Disallow: /`). Sem isso, o preset "Other" serve a raiz do projeto como arquivo estático.

Depois de cada deploy de preview:

```
curl -i https://<preview>/package.json    # esperado: 404
curl -i https://<preview>/src/db.ts       # esperado: 404
```

## Conta (e-mail e senha)

Spec: `tasks/conta-spec.md`. O token de sessão tem o formato da chave de conta (32 bytes base64url) e vale em todas as rotas de conta, sync e relógio. A chave antiga continua aceita até o app migrar. Sessão expira após 90 dias sem uso.

| Rota | Resposta |
| --- | --- |
| `POST /api/v1/auth/signup` | Corpo `{"name","email","password","device","legacyKey"?}`. 201 `{"token","user"}`; 409 `email_taken` ou `legacy_unavailable`; 400 `invalid_*`; 429 com `MAX_ACCOUNTS` atingido |
| `POST /api/v1/auth/login` | Corpo `{"email","password","device"}`. 200 `{"token","user"}`; 401 `invalid_credentials`; 429 depois de 10 tentativas erradas por IP em 15 min |
| `POST /api/v1/auth/logout` | 204 |
| `GET`/`PATCH /api/v1/auth/me` | 200 `{"user"}`; o `PATCH` troca o `name` |
| `POST /api/v1/auth/password` | Corpo `{"current","next","endOtherSessions"?}`. 204; 401 `invalid_credentials` |
| `POST /api/v1/auth/forgot` | Corpo `{"email"}`. Sempre 204; só envia para conta confirmada |
| `POST /api/v1/auth/reset` | Corpo `{"token","password"}`. 204 e encerra as sessões; 400 `invalid_token` |
| `POST /api/v1/auth/verify` | Corpo `{"token"}`. 204; 400 `invalid_token` |
| `POST /api/v1/auth/resend-verification` | 204; 503 `mail_unavailable` |
| `GET`/`DELETE /api/v1/auth/sessions` | Lista as sessões; `DELETE ?id=` encerra uma |

## FIT

O FIT de cada corrida é baixado de `/download-service/files/activity/{id}` e lido com o `@garmin/fitsdk`. O servidor guarda cifrado só o resultado da leitura (amostras de 5 s, voltas, treino prescrito, zonas) e as métricas da corrida (pace em Z2, pace de limiar, desacoplamento, força em subida) em `activity_fit`, com a versão do processamento. O sync baixa os FITs dos últimos 182 dias, 5 por rodada.

## Provas

As provas e as decisões de resultado continuam na tabela `records`, no mesmo protocolo de sync. Registros com `"format":"plain"` chegam em JSON e o servidor cifra com `DATA_KEY` antes de gravar; no pull eles voltam decifrados com `format`. Registros sem `format` são os antigos, cifrados no aparelho, e passam intactos. Com o mesmo `updatedAt`, `plain` substitui o antigo, para o reenvio do app atualizado valer.

| Rota | Resposta |
| --- | --- |
| `GET /api/v1/races` | `{"today","races":[...]}`: próximas (com previsão, projeção, estratégia km a km ajustada pelo calor, bloco de 12 semanas e checklist), feitas e as ainda no formato antigo (`locked`) |
| `POST /api/v1/races` | Corpo `{"name","day","distance","goalSeconds","priority","startTime","city"}`. 201 `{"id"}` |
| `PUT /api/v1/races?id=` | Mesmo corpo; mantém GPX, resultado e alvo congelado. 409 `race_locked` para prova no formato antigo |
| `DELETE /api/v1/races?id=` | 204; grava tombstone que o app recebe no pull |
| `GET /api/v1/goals` | `{"today","goals":[...]}`: metas ativas primeiro (por criação), depois as arquivadas |
| `POST /api/v1/goals` | Tempo: `{"kind":"time","distanceKm","targetSeconds","deadline"}` (prazo opcional). Longão sem pausas: `{"kind":"continuousLong","distanceKm","paceSecondsPerKm"}`. `archived` opcional. 201 `{"id"}`; 409 `too_many_goals` acima de 20 ativas |
| `PUT /api/v1/goals?id=` | Mesmo corpo. Mudar o alvo limpa `achievedAt`. 409 `goal_locked` para meta cifrada no formato antigo |
| `DELETE /api/v1/goals?id=` | 204; grava tombstone que o app recebe no pull |

As voltas das corridas do bloco vêm de `/activity-service/activity/{id}/splits`, 15 por chamada, e ficam cifradas em `activity_laps`. A previsão do tempo vem do Open-Meteo, só a 16 dias da prova, pelo primeiro ponto do GPX ou pela cidade.

## Pedido de convite

| Rota | Resposta |
| --- | --- |
| `POST /api/v1/invite-requests` | Pública. Corpo `{"name","email","watch":"garmin"|"other"|"none","message"}`. 202; cifra e guarda o pedido e avisa os `ADMIN_EMAILS` por e-mail. 400 `invalid_name`, `invalid_email`, `invalid_watch`, `invalid_message`; 429 com mais de 3 pedidos por hora do mesmo IP ou 100 pendentes. O campo `website` é isca para robô: preenchido, responde 202 sem guardar |
| `POST /api/v1/admin/invite-requests/action` | Administrador. `{"id","action":"invite"|"decline"}`. Convidar cria o convite com nome e e-mail do pedido e envia como os outros convites |

Os pedidos pendentes aparecem em `GET /api/v1/admin/overview`, no campo `requests`.

## Garmin

O login é o mesmo do app (SSO mobile da Garmin, com código por e-mail quando a conta pede). Entre o login e o código, os cookies do SSO ficam cifrados em `garmin_pending_logins` por 10 minutos. A sessão fica cifrada (AES-256-GCM com `DATA_KEY`) em `garmin_connections` e é renovada quando faltam menos de 15 minutos para vencer. A senha da Garmin não é guardada.

| Rota | Resposta |
| --- | --- |
| `POST /api/v1/garmin/connect` | Corpo `{"email","password"}`. 200 `{"status":"connected"}` ou `{"status":"needs_code","method"}`; 400 `garmin_invalid_credentials`; 429 `garmin_rate_limited`; 502 `garmin_unavailable` |
| `POST /api/v1/garmin/verify` | Corpo `{"code"}`. 200 `{"status":"connected"}`; 400 `garmin_invalid_code`; 409 `garmin_login_expired` |
| `GET`/`DELETE /api/v1/garmin/status` | `{"connected","connectedAt"}`; `DELETE` desconecta |
| `GET /api/v1/garmin/evolution?days=` | Séries, previsões e recordes do período (42, 91, 182 ou 365 dias; padrão 91) |
| `GET /api/v1/garmin/activity?id=` | Análise do treino a partir do FIT: blocos com status, km a km, zonas, avaliação em texto, nota e comparação com até 4 treinos parecidos. Baixa o FIT na primeira vez |
| `GET /api/v1/garmin/activity/detailed?id=` | Análise detalhada de uma corrida, sem o texto do treinador: `kind` (`intervals`, `tempo`, `race`, `long`, `easy`), `kpis` (% da distância planejada, km da queda de pace, deriva da FC, cada um com a média dos parecidos), `splits` (pace e FC por km), `similar` (até 8 treinos do mesmo tipo nos últimos 90 dias), `findings` (3 a 5, só com dados), `recommendations` (até 3) e `sources`. O tipo vem do plano com repetição, do nome, da zona 4 ou mais e da distância, nessa ordem. Sem plano, a distância é comparada com a mediana dos parecidos. 400 `not_a_run`; 404 `activity_not_found` ou `fit_unavailable` |
| `PUT /api/v1/garmin/activity?id=` | Corpo `{"name"}`. Renomeia o treino na Garmin e no cache |
| `GET /api/v1/garmin/planned` | Treinos de corrida planejados no calendário da Garmin nos próximos 14 dias |
| `GET /api/v1/garmin/session` | A sessão da Garmin para o app (`accessToken`, `refreshToken`, `clientId`, `expiresAt`); 404 `garmin_not_connected` |

## Convites e administração

O cadastro é só por convite. Criam conta sem convite apenas os e-mails de `ADMIN_EMAILS` e quem envia a chave antiga de sync (`legacyKey`). Quem entra por convite vira `guest` e só usa o site: login ou cadastro com o header `X-Training-Client: app` responde 403 `web_only`.

| Rota | Resposta |
| --- | --- |
| `GET /api/v1/admin/overview` | Métricas, contas e convites. Só administrador (403 `forbidden` para os outros) |
| `POST /api/v1/admin/invites` | Corpo `{"name","channel":"email"|"whatsapp"|"link","email"?}`. 200 `{"invite","link","message","mailed"}`; o canal e-mail envia pelo Resend |
| `POST /api/v1/admin/invites/action` | Corpo `{"id","action":"cancel"|"renew"}` |
| `DELETE /api/v1/admin/users?id=` | Remove a conta de um convidado e os dados dela; 409 para administrador |
| `GET /api/v1/invites/preview?c=` | Nome, e-mail e quem convidou, para a página `/app/convite`; 404 `invalid_invite` |

O convite vale 7 dias e uma conta. `POST /api/v1/auth/signup` aceita `inviteToken`; sem ele, responde 403 `invite_required`.
