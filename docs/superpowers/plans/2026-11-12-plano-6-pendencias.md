# trAIning — Plano 6: pendências com efeito para o usuário

Triagem de `2026-11-12-pendencias-plano-4.md`. Entram só os itens que mudam o que aparece na tela ou o que fica gravado. O resto continua no arquivo de pendências.

**Branch:** `fix/plano-6-pendencias`, a partir da `main`.

**Restrições:** as mesmas do plano 4 (sem comentários no código, types em `*Types.swift`, constantes em `*Constants.swift`, fixtures sintéticas, nenhum dado real, nunca ler a chave). TDD em cada tarefa. Commit só com aprovação do Adriano.

**Fora do plano:** o fallback do store para memória. Hoje ele já mostra o erro em Hoje e em Ajustes; o resto do risco depende de uma migração quebrada, que tem teste.

## Task 1: régua de zonas com pisos repetidos

`App/Workouts/Detail/ZoneRuler.swift` usa `ForEach(marks, id: \.bpm)`. Quando dois pisos têm o mesmo bpm (zonas do relógio mal configuradas ou arredondamento do limiar), o SwiftUI recebe ids repetidos e a escala desenha marcas erradas.

- Teste: `ZoneRulerData` com dois pisos iguais gera marcas com ids distintos.
- Correção: id estável por posição na lista (índice), não pelo bpm.

## Task 2: importar provas não zera o desligamento manual

`RaceTransfer.apply` grava `manuallyUnlinked ?? false`. Uma exportação feita antes do campo existir, com `updatedAt` mais novo que o registro local, zera a marca, e a ligação automática religa a prova que o Adriano desligou à mão.

- Teste: prova local com `manuallyUnlinked == true`, import sem o campo e mais novo → continua `true`. Import com o campo `false` → vira `false`. Prova nova sem o campo → `false`.
- Correção: campo ausente mantém o valor local.

## Task 3: erro ao responder "Parece prova?" aparece no log

`RaceListModel` chama `confirmRace` e `declineRace` com `try?`. O dado é idempotente (toque duplo não duplica), mas um erro de gravação some sem rastro.

- Teste: com um context que falha ao salvar, ou pelo caminho que o módulo já usa para testar erros, o model registra a falha e a candidata continua na lista.
- Correção: `do/catch` com `Logger` do app, sem `privacy: .public` em ids.

## Task 4: regra única de corrida desatualizada

Itens do review da mudança do pull-to-refresh (`dd4b349`):

- `hasOutdatedRuns` (`App/SyncEngineConfiguration.swift`) repete o predicate e o filtro `isRun` de `fitQueue` (`Packages/TrainingKit/Sources/Sync/ReprocessQueue.swift`).
- Corridas com `fitTransientFailures >= maxFitTransientFailures` saem da fila, mas continuam contando como desatualizadas.
- A consulta roda no `mainContext`.

- Teste no pacote: helper público em `Sync` (ex.: `hasOutdatedRuns(in:)`) conta corrida desatualizada, ignora corrida atual, corrida sem FIT, outro esporte e corrida com falhas no limite. `fitQueue` e o helper usam a mesma regra.
- Correção: o app usa o helper do `Sync`, num `ModelContext` próprio fora da main thread, como `runPostSyncWork`.

## Validação

- `swift test --package-path Packages/TrainingKit` sem falhas.
- `scripts/dev-run.sh --test` sem falhas.
- `scripts/dev-run.sh` e conferir a régua de uma corrida no simulador.
- Atualizar `2026-11-12-pendencias-plano-4.md`, tirando os itens resolvidos.
