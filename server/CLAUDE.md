# Servidor

Vercel Functions (Node 22, ESM) com Postgres no Neon. Atende só o que o app usa: conta e sessões, sync de registros (`/api/v1/changes`), sessão da Garmin, Strava, nota do relógio, convites e administração, MCP de força (`/mcp`) e o cron do catálogo da Garmin. Rotas, variáveis de ambiente e protocolo de sync estão em `server/README.md`.

Não existe mais versão web. Não adicionar análise, cálculo de treino nem paridade de regra aqui.

## Comandos

```bash
npm --prefix server ci
npm --prefix server test -- test/watch.test.ts   # um arquivo
npm --prefix server test                         # tudo, contra PGlite, sem rede
npm --prefix server run typecheck
```

`test:concurrency` precisa de Docker com `postgres:17-alpine`. Rode só quando mexer em lock ou transação do push.

## Código

- `api/` tem só os pontos de entrada da Vercel (`router.ts`, `mcp.ts`, `cron/`). A lógica fica em `src/`.
- TypeScript estrito com `NodeNext`: import relativo termina em `.js` (`'../src/db.js'`), e `verbatimModuleSyntax` exige `import type` para tipo.
- Constantes em `src/constants.ts` (ou `<area>Constants.ts`), tipos em `src/types.ts` ou `<arquivo>.types.ts`. Não declarar dentro do handler.
- Erro volta como `{"error":"<código>"}` com o status certo. Código novo de erro entra na tabela do `README.md`.
- Payload de registro é cifrado com `DATA_KEY` antes de gravar. Nada de saúde, payload, Bearer ou IP vai para log.
- Testes usam `test/helpers.ts` (`migratedSql`, `makeRequest`, `makeToken`). Sem rede: Garmin, Strava e Resend entram como fake.

## Migrations

Arquivos numerados em `migrations/` (`024_<nome>.sql`). O `npm run build` da Vercel aplica as pendentes no deploy. Nunca edite uma migration que já foi para produção; crie a próxima.

## MCP de força

`src/mcp/` expõe `contexto_forca`, `validar_treinos` e `salvar_treinos`. O validador (`strengthValidator.ts`) confere os exercícios contra o `catalogo` do contexto que o app enviou. Os testes usam `test/fixtures/strength-catalog.json`, gerado pelo `TrainingKit` (ver `Packages/TrainingKit/CLAUDE.md`). Se o catálogo mudar no app, a fixture muda no mesmo commit. As regras ficam em `docs/regras/prescricao.md` (seção "MCP de força").

## Landing

`landing/` é HTML e CSS estáticos. O build da Vercel copia para `public/`, e o GitHub Pages publica a mesma pasta a cada push na `main` que mexe nela (`.github/workflows/pages.yml`).

- `landing/index.html` tem cerca de 145 KB. Não leia inteiro: procure a `<section>` pelo `aria-labelledby` (`treinador-title`, `forca-title`, `relogio-title`...) e leia só aquele trecho.
- Mudança no que o app faz atualiza o texto e os exemplos da landing no mesmo fluxo.
- `landing/versao.json` é escrito por `scripts/release.sh`. Não edite à mão.

## Deploy

O push não publica. O deploy é `cd server && vercel deploy --prod`, depois de commit e merge aprovados. Quando o app novo depende do servidor novo, o deploy vem antes de instalar nos aparelhos. Depois de um deploy de preview, confira que `/package.json` e `/src/db.ts` respondem 404.
