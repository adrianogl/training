# trAIning

App de corrida para iPhone e iPad (SwiftUI + SwiftData), com a lógica no pacote `Packages/TrainingKit`, um servidor na Vercel (`server/`) e um mostrador Connect IQ (`Watchface/`). O `README.md` explica o produto, o fluxo de dados e como rodar cada parte. Este arquivo guarda só o que um agente precisa para trabalhar aqui sem redescobrir o projeto.

Cada pasta tem o seu `CLAUDE.md` com as regras locais: `App/`, `Packages/TrainingKit/`, `server/`, `Watchface/` e `ForcaApp/`.

## Mapa

| Pasta | O que é | Comando de teste |
| --- | --- | --- |
| `App/`, `Widgets/`, `Shared/` | App, widgets e tipos que os dois dividem | `xcodebuild test` (ver `App/CLAUDE.md`) |
| `Packages/TrainingKit/` | Garmin, FIT, sync, SwiftData e todos os cálculos | `swift test --package-path Packages/TrainingKit --filter <Suite>` |
| `server/` | API (Node 22, Neon), MCP e landing estática | `npm --prefix server test` |
| `Watchface/` | Mostrador Monkey C do Forerunner 965 | `Watchface/build-local.sh` |
| `ForcaApp/` | App Monkey C de força ao vivo (965 e Venu 3) | `ForcaApp/test-local.sh` |
| `scripts/` | Simulador, release, reinstalação automática, catálogo de força | `python3 scripts/test_*.py` |
| `docs/regras/` | Regras de análise e de prescrição, fonte da verdade | — |
| `docs/superpowers/` | Specs e planos antigos, só referência | — |

O `.xcodeproj` é gerado pelo XcodeGen e não entra no git. Depois de criar, mover ou apagar arquivo Swift, rodar `xcodegen generate`.

## Verificação rápida

Rode só a parte que a mudança tocou, filtrada. A suíte inteira do app leva minutos e compila tudo do zero numa pasta de DerivedData nova.

- Lógica (`Packages/TrainingKit`): `swift test --package-path Packages/TrainingKit --filter TrainerEngineTests`. É o caminho mais rápido, roda no Mac, sem simulador.
- App: `-only-testing:AppTests/<Suite>` no `xcodebuild` (ver `App/CLAUDE.md`).
- Servidor: `npm --prefix server test -- test/<arquivo>.test.ts` e `npm --prefix server run typecheck`.
- Use sempre `-derivedDataPath DerivedData` no `xcodebuild`. Cada pasta nova (`DerivedData-xyz`) refaz o build inteiro e ocupa perto de 1 GB.

## Regras do projeto

- **Regras de negócio em `docs/regras/`.** Análise (prontidão, nota do treino, texto gerado, força) fica em `analise.md`; prescrição do treinador em `prescricao.md`. Mudança de regra atualiza o arquivo no mesmo commit.
- **Cantos concêntricos.** Raio interno = raio externo − padding. Tokens e regra em `docs/design/cantos.md`; leia antes de mexer em layout.
- **Mock antes de código.** Funcionalidade nova e mudança de layout (app, landing, mostrador) passam por um mock aprovado antes da implementação. Mostre atual × proposta só no trecho que mudou e espere a aprovação do layout antes de propor commit.
- **README e landing acompanham o código.** Mudança no que o `README.md` descreve (estrutura, integração, script, variável de ambiente, fluxo de dados) vai no mesmo commit. Mudança no que o app faz para quem usa ajusta `server/landing/index.html`.
- **Sem versão web.** Só app e landing. Não implementar paridade de regra no servidor.
- **Repositório público.** Nunca commitar dado pessoal, `.FIT`, resposta de API, foto, token, UDID de aparelho ou logo de terceiros. Foto do mostrador, token do relógio e logos ficam em `~/.config/training-sync/` e entram só no build.

## Git e sessões paralelas

Várias sessões trabalham neste repositório ao mesmo tempo, e o checkout principal pode trocar de branch sem aviso.

- Para mudança que vai virar commit, use um worktree próprio em `.claude/worktrees/<nome>` a partir da `main`. Antes de `git add` e `git commit`, confira `git branch --show-current` e `git status`.
- Não apague `~/Code/pessoal/training-autoinstall`: o LaunchAgent da reinstalação automática roda de lá.
- Não apague nem reaproveite uma pasta `DerivedData*` que outra sessão esteja usando (`ps -axo command | grep xcodebuild`).
- Hooks de outras ferramentas às vezes criam `App/**/.omc/`. O XcodeGen inclui essas pastas como recurso e o build para aparelho falha com "Multiple commands produce". Apague antes de compilar.
- Em script que roda `rm -rf`, `rsync --delete` ou cópia para caminho vindo de variável, use `${X:?}` e confira que o diretório existe. Em 19/11 um container de simulador vazio virou `/`.

## Release

Semver pelos commits desde a última tag `v*` (`feat` → minor, `fix`/`perf` → patch). Depois de merge na `main` com `feat`, `fix` ou `perf`:

1. `git fetch` e trazer `origin/main` para a `main` local. Outra sessão pode ter lançado uma versão.
2. `scripts/release.sh --dry-run`, mostrar a versão e, com aprovação, `scripts/release.sh`. O script atualiza `project.yml`, a linha "Versão atual" do README e `server/landing/versao.json`.
3. Commit `chore(release): vX.Y.Z`, tag `vX.Y.Z`, push com `--tags`, sempre com aprovação.
4. Só depois do push: `cd server && vercel deploy --prod`, que publica o `versao.json` e roda as migrations.
5. Compilar e instalar nos aparelhos. A reinstalação automática só age quando o perfil está perto de vencer, então a versão nova não chega sozinha.

Escopos de commit em uso: `treinador`, `treinos`, `forca`, `hoje`, `analise`, `sync`, `provas`, `ajustes`, `relogio`, `mostrador`, `landing`, `mcp`, `servidor`, `app`, `ui`, `release`.

## Aparelhos

Instalação é só por cabo ou mesma rede (conta Apple gratuita, perfil vence 7 dias depois de criado).

- Build para aparelho: `xcodebuild -project trAIning.xcodeproj -scheme trAIning -destination generic/platform=iOS -derivedDataPath DerivedData -allowProvisioningUpdates build`. Apague `DerivedData/Build/Products/Debug-iphoneos` antes e confira `BUILD SUCCEEDED`. Sem isso, o `devicectl` instala um build antigo sem avisar.
- Depois de instalar: `xcrun devicectl device process launch --no-activate --device <UDID> dev.aglv.training`, para o app disparar o aviso de versão instalada. Confira o resultado: essa abertura também agenda o sync em segundo plano, que o iOS descarta na atualização. Se falhar (aparelho bloqueado), avise que o aviso da manhã só volta quando o app for aberto.
- Não instale nos aparelhos entre 22h e 7h. Uma instalação de madrugada que não consegue abrir o app deixa a manhã sem o aviso de prontidão; deixe para depois das 7h.
- Erro 4016 no `devicectl` significa aparelho bloqueado ou fora da rede. Avise qual ficou de fora.
- Antes de apagar perfis de provisionamento, confira se a Apple ID está no Xcode (`defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists`). Sem conta, o build para com "No Accounts".
- Para ver a mensagem de um crash no aparelho, rode `devicectl device process launch --terminate-existing --console` em background e peça para reproduzir. O `.ips` não traz o texto do `fatalError`.
