# trAIning — Zonas pelo limiar, provas reconhecidas e ajustes internos — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O app inteiro passa a usar zonas de FC calculadas pela FC de limiar do Garmin (com a régua relógio × limiar no detalhe do treino), reconhece provas no histórico com confirmação do Adriano e as usa na previsão, guarda a nota do treino, tira o backfill de narrativa da main thread, valida a direção das frases geradas e fecha os dois casos do retry do aviso.

**Architecture:** `Metrics` ganha o modelo de zonas pelo limiar e o tempo por zona a partir dos samples. `SchemaV4` acrescenta o histórico do limiar, as decisões de "foi prova" e campos em `ActivityRecord` (tempo por zona pelo limiar, nota guardada). `Sync` grava o histórico do limiar e o tempo por zona ao processar o FIT. `Insights` troca as zonas do relógio pelas do limiar em todos os consumidores, detecta provas prováveis e liga provas cadastradas. O app mostra a régua, a seção "Parece prova?" e lê a nota guardada.

**Tech Stack:** Swift 6.4, SwiftUI, Swift Charts, SwiftData (`VersionedSchema`), FoundationModels, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-11-zonas-limiar-e-provas-design.md` (complementa `2026-11-07-training-design.md` e `2026-11-09-hoje-evolucao-provas-design.md`). Mockups em `.superpowers/brainstorm/71658-1794396631/content/` do repositório principal (`zonas-barras-v2.html`, opção A1), fora do git.

## Global Constraints

- Deployment target iOS/iPadOS 26; simulador de dev iPhone 18 Pro, iOS 27.1. Pacote `.iOS(.v26), .macOS(.v26)`.
- Identidade: fundo `#07080A`, destaque `#C8F05A`, laranja `#FF8A4C` só para prova, azul `#7FB2FF` fitness/sono; números SF Pro `.compressed`/`.condensed`; só tema escuro; Liquid Glass nos cards.
- Repositório público: nenhum dado real (JSON da API, `.FIT`, store, chave, números da conta) no git. Fixtures sintéticas.
- SwiftData compatível com CloudKit (sem `.unique`, tudo opcional ou com padrão, relacionamentos opcionais), `cloudKitDatabase: .none`.
- Sem comentários no código, salvo workaround não óbvio. Types em `*Types.swift`, constantes em `*Constants.swift`, ao lado do código.
- Telas computam em `Task.detached` com `ModelContext` próprio e publicam só valores Sendable.
- Testes do pacote: Swift Testing, `swift test --package-path Packages/TrainingKit`. Testes do app: `scripts/dev-run.sh --test`.
- Nunca ler, imprimir ou commitar `~/.config/garmin/connect-personal-api-key`; só `scripts/dev-run.sh` a lê.
- Git: branch `feat/zonas-limiar-e-provas`. Commit ao fim de cada tarefa, Conventional Commits PT-BR minúsculo, sem trailer de coautoria nem menção a IA. Sem push, merge ou rebase sem aprovação do Adriano.
- Depois de cada tarefa que muda a UI, o controlador roda `scripts/dev-run.sh` e o simulador fica aberto no app.
- Modelo de zonas pelo limiar (Friel, corrida): Z1 abaixo de 85% da FC de limiar, Z2 85–89%, Z3 90–94%, Z4 95–99%, Z5 a partir de 100%. Pisos arredondados para bpm inteiro.
- Decisão do plano (não está na spec): bloco prescrito com alvo por número de zona é avaliado pelas zonas do limiar; alvo com faixa explícita em bpm continua igual.

## Review Focus

- Garmin sem `lactateThresholdHeartRate` → o app inteiro usa as zonas do relógio, a régua mostra só a barra do relógio com "sem FC de limiar no Garmin", nada quebra. Teste em Task 4 e Task 5.
- Treino sem samples de FC → sem tempo por zona pelo limiar, fora das somas de minutos por zona e do foco da carga, régua só com o relógio. Teste em Task 3 e Task 5.
- Corrida com FIT ainda não processado ou tiros feitos sem treino do Garmin → não aparece em "Parece prova?". Teste em Task 6.
- Atividade re-sincronizada ou reprocessada depois de "Não foi" → continua escondida; prova criada por "Foi prova" e apagada → a pergunta não volta. Teste em Task 6.
- Prova cadastrada que o Adriano desligou à mão → a ligação automática não religa. Teste em Task 6.

---

### Task 1: `SchemaV4` com histórico do limiar, decisões de prova e campos da atividade

**Files:**
- Create: `Packages/TrainingKit/Sources/Storage/SchemaV3Models.swift` (cópia congelada dos modelos atuais como tipos aninhados em `SchemaV3`, como `SchemaV2Models.swift`), `SchemaV4.swift`, `ThresholdHistoryRecord.swift`, `RaceDecisionRecord.swift`, `RaceDecision.swift`
- Modify: `SchemaV3.swift` (passa a listar os tipos aninhados), `ActivityRecord.swift`, `TrainingMigrationPlan.swift`, `TrainingSchema.swift`
- Test: `Packages/TrainingKit/Tests/StorageTests/SchemaV4MigrationTests.swift`

**Interfaces:**
- Produces:
  - `@Model public final class ThresholdHistoryRecord { sport: String = ""; day: String = ""; heartRate: Int = 0 }`
  - `public enum RaceDecision: String, Sendable { case race, notRace }`; `@Model public final class RaceDecisionRecord { activityId: Int64 = 0; decision: String = ""; decidedAt: Date = .now }` com `var raceDecision: RaceDecision?`
  - `ActivityRecord` novos campos: `thresholdZoneSeconds: [Double] = []`, `thresholdUsed: Int? = nil`, `scoreValue: Int? = nil`, `scoreKey: String? = nil`, `scoreData: Data? = nil`
  - `RaceRecord` novo campo: `manuallyUnlinked: Bool = false` (exportação/importação de provas inclui o campo)
  - `TrainingSchema` aponta para `SchemaV4`; estágio `.lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self)`.

- [ ] **Step 1: Testes que falham:** `v3StoreMigratesToV4` (store V3 sintético em arquivo temporário com uma atividade, uma prova e zonas → abre como V4, dados preservados, campos novos com padrão); `schemaV4ListsSevenModels`.
- [ ] **Step 2: Rodar** `swift test --package-path Packages/TrainingKit --filter SchemaV4MigrationTests` → FAIL.
- [ ] **Step 3: Implementar.** Congelar V3 antes de mexer nos modelos vivos.
- [ ] **Step 4: Rodar** → PASS; suíte completa do pacote → PASS.
- [ ] **Step 5: Commit** — `feat(storage): schema v4 com histórico do limiar e decisões de prova`

---

### Task 2: Zonas pelo limiar e tempo por zona em `Metrics`

**Files:**
- Create: `Packages/TrainingKit/Sources/Metrics/ThresholdZones.swift`, `ThresholdZonesConstants.swift`
- Test: `Packages/TrainingKit/Tests/MetricsTests/ThresholdZonesTests.swift`

**Interfaces:**
- Consumes: `HeartRateZones` (`WorkoutAnalysis`/`BlockTypes.swift`) — se `Metrics` não enxerga esse tipo, mover `HeartRateZones` para `TrainingCore` e reexportar, sem mudar o nome.
- Produces:
  - `public func thresholdZones(thresholdHeartRate: Int) -> HeartRateZones` — `floors = [0, round(0.85·L), round(0.90·L), round(0.95·L), L]`, `maxHeartRate: nil`.
  - `public func zoneSeconds(_ samples: [FITSample], zones: HeartRateZones) -> [Double]?` — 5 posições; tempo de cada amostra é o intervalo até a próxima, limitado por `ThresholdZonesConstants.maxSampleGap` (10 s); `nil` sem nenhuma amostra com FC.
  - `public func zoneDivergence(watchZone5Floor: Int?, thresholdHeartRate: Int?) -> Int?` — `watch − limiar`, `nil` se faltar um dos dois ou se `|diferença| < 3`.

- [ ] **Step 1: Testes que falham:** `thresholdZonesFollowFriel` (L = 160 → `[0, 136, 144, 152, 160]`); `zoneSecondsSplitsByFloor` (samples sintéticos 1 Hz: 60 s a 130, 60 s a 150, 30 s a 165 com L = 160 → `[60, 0, 0, 60, 30]`); `zoneSecondsCapsGaps` (buraco de 120 s conta 10 s); `zoneSecondsNilWithoutHeartRate`; `divergenceBothDirections` (154 vs 160 → −6; 175 vs 165 → 10; 158 vs 160 → nil).
- [ ] **Step 2: Rodar** `--filter ThresholdZonesTests` → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** → PASS.
- [ ] **Step 5: Commit** — `feat(metrics): zonas de fc pela fc de limiar`

---

### Task 3: Histórico do limiar e tempo por zona pelo limiar no sync

**Files:**
- Modify: `Packages/TrainingKit/Sources/Sync/HeartRateZonesSync.swift`, `FITSync.swift` (ou onde o FIT da atividade é processado), `SyncEngine.swift`
- Create: `Packages/TrainingKit/Sources/Sync/ThresholdHistory.swift`
- Test: `Packages/TrainingKit/Tests/SyncTests/ThresholdHistoryTests.swift`

**Interfaces:**
- Consumes: `ThresholdHistoryRecord`, `ActivityRecord.thresholdZoneSeconds/thresholdUsed` (Task 1), `thresholdZones`, `zoneSeconds` (Task 2).
- Produces:
  - `public func thresholdHeartRate(on day: Day, sport: String, in context: ModelContext) throws -> Int?` — último registro com `day <= dia`; sem nenhum anterior, o mais antigo; sem histórico, `HeartRateZonesRecord.lactateThresholdHeartRate`.
  - `upsertHeartRateZones` grava um `ThresholdHistoryRecord(day: hoje)` só quando o valor difere do último registro.
  - Ao processar o FIT de uma corrida, grava `thresholdZoneSeconds` e `thresholdUsed`. No fim do sync, `refreshThresholdZoneSeconds(in:)` recalcula as atividades com samples cujo `thresholdUsed` difere do limiar da data (cobre o histórico já baixado na primeira execução).

- [ ] **Step 1: Testes que falham:** `historyRecordsOnlyChanges` (três syncs com 160, 160, 162 → dois registros); `thresholdOnDayUsesLatestBefore`; `thresholdBeforeHistoryUsesOldest`; `processedRunGetsThresholdZoneSeconds`; `runWithoutHeartRateKeepsEmpty` (Review Focus); `refreshRecomputesWhenThresholdOfDayChanges`.
- [ ] **Step 2: Rodar** `--filter ThresholdHistoryTests` → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** → PASS; suíte do pacote → PASS.
- [ ] **Step 5: Commit** — `feat(sync): histórico do limiar e tempo por zona pelo limiar`

---

### Task 4: `Insights` usa as zonas do limiar

**Files:**
- Modify: `Packages/TrainingKit/Sources/Insights/InsightsStore.swift` (`zone2Range`), `MetricSeries.swift` (`.loadFocus`, minutos por zona), `OverallState.swift`, `TodayBuilder.swift` (se cita Z2)
- Test: `Packages/TrainingKit/Tests/InsightsTests/ThresholdZonesInsightsTests.swift`

**Interfaces:**
- Consumes: `thresholdHeartRate(on:sport:in:)` (Task 3), `thresholdZones` (Task 2), `ActivityRecord.thresholdZoneSeconds`.
- Produces: `func runningZones(on day: Day, _ context: ModelContext) throws -> HeartRateZones?` em `InsightsStore` — zonas do limiar da data; sem limiar, zonas do relógio. Todos os consumidores de zona em `Insights` passam por ela; somas de tempo por zona leem `thresholdZoneSeconds` e ignoram atividades com o array vazio.

- [ ] **Step 1: Testes que falham:** `zone2RangeComesFromThreshold` (L = 160 → 136...143); `loadFocusUsesThresholdZoneSeconds`; `weeklyZoneMinutesSkipRunsWithoutThresholdSeconds`; `withoutThresholdFallsBackToWatchZones` (Review Focus).
- [ ] **Step 2: Rodar** `--filter ThresholdZonesInsightsTests` → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** → PASS; suíte do pacote → PASS (ajustar testes que fixavam zonas do relógio, com valores sintéticos).
- [ ] **Step 5: Commit** — `feat(insights): zonas do limiar em hoje e evolução`

---

### Task 5: Análise do treino pelo limiar e régua relógio × limiar

**Files:**
- Modify: `App/Workouts/Detail/WorkoutAnalysisContext.swift` (`zones(_:)` passa a receber a data do treino), `WorkoutDetailModel.swift`, `WorkoutDetailView.swift`, `WorkoutDetailTypes.swift`, `WorkoutDetailConstants.swift`
- Create: `App/Workouts/Detail/ZoneRuler.swift`, `ZoneRulerData.swift`
- Test: `AppTests/ZoneRulerTests.swift`, `AppTests/WorkoutDetailModelTests.swift`

**Interfaces:**
- Consumes: `runningZones(on:_:)` (Task 4) ou `thresholdHeartRate(on:sport:in:)` + `thresholdZones`; `zoneDivergence` (Task 2); `ActivityRecord.zoneSeconds` (relógio) e `thresholdZoneSeconds`.
- Produces: `struct ZoneRulerData: Sendable { watch: ZoneBar; threshold: ZoneBar?; divergence: Int?; thresholdHeartRate: Int? }`, `struct ZoneBar: Sendable { floors: [Int]; seconds: [Double] }`; `WorkoutDetailModel.ruler: ZoneRulerData?`.

Layout A1: duas barras na mesma escala de bpm (`WorkoutDetailConstants.rulerRange = 100...180`, ampliada para caber o menor piso e o limiar + 10), rótulos "Relógio (Garmin)" e "Pelo limiar (N bpm)", marcas com o piso em bpm embaixo de cada barra, linha "Z1 m:ss · Z2 m:ss · …" com o tempo, mesmas cores por zona. Divergência: "Zonas do relógio N bpm abaixo do limiar" / "acima". Sem limiar: só a barra do relógio e "sem FC de limiar no Garmin".

- [ ] **Step 1: Testes que falham:** `rulerShowsBothBarsWithThreshold`; `rulerWatchOnlyWithoutSamples` (Review Focus); `rulerWatchOnlyWithoutThreshold` (Review Focus); `divergenceTextBelowAndAbove`; `scoreUsesThresholdZones` (corrida fácil sintética com FC média dentro da Z2 do limiar e acima da Z2 do relógio → sem perda de intenção); `zoneTargetBlockJudgedByThreshold`.
- [ ] **Step 2: Rodar** `scripts/dev-run.sh --test` → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** → PASS; `scripts/dev-run.sh` e conferir a régua numa corrida fácil.
- [ ] **Step 5: Commit** — `feat(app): régua de zonas do relógio e do limiar no treino`

---

### Task 6: Provas prováveis, decisões e ligação automática em `Insights`

**Files:**
- Create: `Packages/TrainingKit/Sources/Insights/RaceDetection.swift`, `RaceDetectionTypes.swift`, `RaceDetectionConstants.swift`
- Test: `Packages/TrainingKit/Tests/InsightsTests/RaceDetectionTests.swift`

**Interfaces:**
- Consumes: `RaceDecisionRecord`, `RaceDecision` (Task 1), `thresholdHeartRate(on:sport:in:)` (Task 3), `ReportBuilder.isContinuous`.
- Produces:
  - `public struct RaceCandidate: Sendable, Identifiable { activityId: Int64; day: Day; name: String; distance: Double; seconds: Double; averageHeartRate: Int?; isPR: Bool }`
  - `public func raceCandidates(in context: ModelContext, today: Day) throws -> [RaceCandidate]` — últimos 365 dias, mais recentes primeiro.
  - `public func confirmRace(activityId: Int64, in context: ModelContext) throws` — grava `.race` e cria `RaceRecord(name: nome do Garmin, day, distance: distância nominal mais próxima, priority: "C", goalSeconds: nil, resultActivityId)`.
  - `public func declineRace(activityId: Int64, in context: ModelContext) throws` — grava `.notRace`.
  - `public func autoLinkRaces(in context: ModelContext, today: Day) throws` — prova com `day < hoje`, `resultActivityId == nil` e sem marca de desligamento manual → corrida do dia com distância a até 4% (a mais próxima).
  - Marca de desligamento manual: `RaceRecord.manuallyUnlinked` (Task 1). `RaceListModel.unlinkResult` grava `true`; `linkResult` grava `false`.

Regra do candidato (constantes em `RaceDetectionConstants`): `fitProcessed == true`; corrida sem `workoutName` e sem estrutura; `ReportBuilder.isContinuous`; distância a até 4% de 5000, 10000, 21097,5 ou 42195 m; ritmo em movimento ≥ 6% mais rápido que a mediana das corridas não estruturadas de distância ±20% nos 180 dias anteriores, ou, sem base, FC média ≥ 95% do limiar da data; sem `RaceDecisionRecord` e sem `RaceRecord` ligada à atividade.

- [ ] **Step 1: Testes que falham:** `detectsFastUnstructuredRunAtRaceDistance`; `ignoresStructuredWorkouts`; `ignoresUnprocessedRuns` (Review Focus); `ignoresIntervalsWithoutGarminWorkout` (Review Focus); `usesThresholdWhenNoBaseline`; `declinedStaysHiddenAfterResync` (recria o `ActivityRecord` com o mesmo id → continua fora; Review Focus); `confirmCreatesCompletedRace`; `deletingConfirmedRaceDoesNotAskAgain` (Review Focus); `autoLinkPicksClosestDistance`; `autoLinkRespectsManualUnlink` (Review Focus).
- [ ] **Step 2: Rodar** `--filter RaceDetectionTests` → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** → PASS.
- [ ] **Step 5: Commit** — `feat(insights): reconhece provas no histórico`

---

### Task 7: Previsão com provas confirmadas

**Files:**
- Modify: `Packages/TrainingKit/Sources/Reports/ReportBuilder.swift` (`efforts(from:)`), `Sources/Metrics/RacePrediction.swift` (`predictionWeight`), `RaceConstants.swift`, `Sources/Insights/InsightsConstants.swift`
- Test: `Packages/TrainingKit/Tests/MetricsTests/RaceMetricsTests.swift`, `Tests/InsightsTests/EffortWindowConsistencyTests.swift`

**Interfaces:**
- Produces: `RaceConstants.raceEffortWindowDays = 365.0` e `InsightsConstants.raceEffortWindowDays = 365`; `predictionWeight` usa essa janela quando `effort.kind == .race`. Esforço `.race` usa `activity.distance` e `activity.duration` (não mais `race.distance`).

- [ ] **Step 1: Testes que falham:** `raceEffortUsesActivityDistance` (prova de 10 km nominal com atividade de 9,7 km → `Effort.distance == 9700`); `raceEffortKeepsWeightUntil365Days` (prova de 300 dias tem peso > 0; split de 300 dias não entra); `raceWindowsMatchAcrossModules`.
- [ ] **Step 2: Rodar** `--filter RaceMetricsTests` e `--filter EffortWindowConsistencyTests` → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** → PASS; suíte do pacote → PASS.
- [ ] **Step 5: Commit** — `feat(metrics): provas confirmadas pesam por um ano na previsão`

---

### Task 8: Seção "Parece prova?" em Provas

**Files:**
- Modify: `App/Races/RaceListView.swift`, `RaceListModel.swift`, `RacesTypes.swift`, `RacesConstants.swift`, `App/AppModel.swift` (chama `autoLinkRaces` depois de cada sync, no mesmo `Task.detached` do `freezeEveTargets`)
- Create: `App/Races/RaceCandidateRow.swift`
- Test: `AppTests/RaceCandidatesTests.swift`

**Interfaces:**
- Consumes: `raceCandidates`, `confirmRace`, `declineRace`, `autoLinkRaces` (Task 6).
- Produces: `RaceListLoad.candidates: [RaceCandidate]`; `RaceListModel.confirm(_ activityId: Int64)`, `decline(_ activityId: Int64)`.

Seção "Parece prova?" acima das concluídas, uma linha por corrida (data, nome do Garmin, distância, tempo, FC média), botões "Foi prova" e "Não foi". Some sem candidatos. "Foi prova" move a corrida para as concluídas na mesma tela.

- [ ] **Step 1: Testes que falham:** `candidatesAppearAboveCompleted`; `confirmMovesToCompleted`; `declineRemovesRow`; `sectionHiddenWithoutCandidates`; `syncAutoLinksRegisteredRace`.
- [ ] **Step 2: Rodar** `scripts/dev-run.sh --test` → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** → PASS; `scripts/dev-run.sh` e conferir a seção com dados sintéticos.
- [ ] **Step 5: Commit** — `feat(app): pergunta se uma corrida foi prova`

---

### Task 9: Nota do treino guardada

**Files:**
- Modify: `App/Workouts/Detail/WorkoutAnalysisContext.swift`, `App/Workouts/WorkoutListModel.swift`, `App/Today/TodayModel.swift` (último treino)
- Create: `App/Workouts/ScoreStore.swift`
- Test: `AppTests/ScoreStoreTests.swift`

**Interfaces:**
- Consumes: `ActivityRecord.scoreValue/scoreKey/scoreData` (Task 1), `thresholdUsed` (Task 3), `scoreWorkout`.
- Produces: `enum ScoreStore { static func key(record: ActivityRecord, previous: [ActivityRecord]) -> String; static func refresh(container: ModelContainer, ids: [Int64]?) async }`. A chave junta `AnalysisConstants.scoreVersion` (constante nova, `1`), `thresholdUsed`, `processingVersion` e os `activityId` dos treinos anteriores usados na comparação. `refresh` roda em `Task.detached`, recalcula só onde a chave mudou e salva `scoreValue`, `scoreKey` e a decomposição em `scoreData`. A lista e Hoje leem o valor guardado; a lista chama `refresh` depois do sync, não a cada mudança de `records.count`.

- [ ] **Step 1: Testes que falham:** `storedScoreReadWithoutRecompute`; `recomputesWhenScoreVersionChanges`; `recomputesWhenThresholdOfDayChanges`; `recomputesWhenReprocessed`; `recomputesWhenPreviousRunsChange`; `readinessChangeDoesNotRecompute`.
- [ ] **Step 2: Rodar** `scripts/dev-run.sh --test` → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** → PASS; medir a abertura da lista com o histórico do simulador antes e depois (tempo até a primeira nota aparecer) e registrar no relatório.
- [ ] **Step 5: Commit** — `perf(app): guarda a nota do treino`

---

### Task 10: Backfill de narrativa fora da main thread

**Files:**
- Modify: `App/Narrative/NarrativeBackfill.swift`, `App/AppModel.swift` (chamada)
- Test: `AppTests/NarrativeBackfillTests.swift`

**Interfaces:**
- Produces: `enum NarrativeBackfill` sem `@MainActor`; `static func run(container: ModelContainer, narrator: any Narrator, processed: Set<Int64>, limit: Int, skipping: Set<String>) async throws -> Set<String>` com `ModelContext` próprio dentro de `Task.detached`. Assinatura antiga removida.

- [ ] **Step 1: Teste que falha:** `backfillRunsOffMainActor` (narrator fake registra `Thread.isMainThread == false` durante `narrate`); testes existentes de backfill continuam passando com a assinatura nova.
- [ ] **Step 2: Rodar** → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** → PASS.
- [ ] **Step 5: Commit** — `perf(app): backfill de narrativa fora da main thread`

---

### Task 11: Validador de frases com direção

**Files:**
- Modify: `Packages/TrainingKit/Sources/Narrative/FoundationModelsInsightNarrator.swift`, `NarrativeCheck.swift`, `InsightNarrativeConstants.swift`
- Test: `Packages/TrainingKit/Tests/NarrativeTests/InsightDirectionTests.swift`

**Interfaces:**
- Produces: `NarrativeCheck.words(_ verdict: ReadinessVerdict) -> [String]`, `NarrativeCheck.words(_ facts: OverallFacts) -> [String]` e `NarrativeCheck.forbidden(_ facts: OverallFacts) -> [String]`. `validated(instructions:template:words:forbidden:)` rejeita frase sem as palavras exigidas ou com uma palavra da direção oposta ("melhor" quando o veredito é `.worse`, "acima" quando a meta está abaixo, e o inverso). Palavras em `InsightNarrativeConstants`.

- [ ] **Step 1: Testes que falham:** `overallWorseRejectsMelhor`; `overallBetterAcceptsMelhor`; `readinessRestRejectsForte`; `goalGapDirectionChecked`; `rejectedFallsBackToTemplate`.
- [ ] **Step 2: Rodar** `--filter InsightDirectionTests` → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** → PASS.
- [ ] **Step 5: Commit** — `fix(narrative): valida a direção das frases geradas`

---

### Task 12: Retry do aviso de manhã

**Files:**
- Modify: `App/AppModel.swift`
- Test: `AppTests/BackgroundSyncTests.swift`

**Interfaces:**
- Produces: `todayReadinessComplete` guarda também o dia (`todayReadinessDay: Day?`); vale só quando o dia é hoje. Init de teste `AppModel(..., readinessComplete: Bool, readinessDay: Day)` para montar o estado anterior.

- [ ] **Step 1: Testes que falham:** `failedLaunchSyncDoesNotKeepYesterdaysReadiness` (estado "completo ontem", sync `.launch` falha, background às 5h30 → agenda 6h30); `failedBackgroundRunWithPreviousCompleteRetriesInOneHour`.
- [ ] **Step 2: Rodar** `scripts/dev-run.sh --test` → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** → PASS.
- [ ] **Step 5: Commit** — `fix(app): retry do aviso não usa a prontidão de ontem`

---

### Task 13: Recalibração com as provas confirmadas (manual, com o Adriano)

**Files:**
- Modify (se preciso): `Sources/Metrics/RaceConstants.swift`, `Sources/Insights/InsightsConstants.swift`

- [ ] **Step 1:** O controlador roda `scripts/dev-run.sh`; o Adriano confirma ou recusa as provas da seção "Parece prova?" no simulador.
- [ ] **Step 2:** O controlador roda `trainingctl report` numa cópia do store do simulador e lê previsões e VO2max do Garmin pelo MCP do Garmin (só leitura). Números reais ficam fora do repositório.
- [ ] **Step 3:** Fora do alvo (previsões ±3%, VO2max ±1,5): achar a causa antes de mexer em constante; uma constante por vez.
- [ ] **Step 4:** Suíte inteira → PASS.
- [ ] **Step 5: Commit** (só se mudou constante) — `fix(metrics): recalibra a previsão com provas confirmadas`

---

### Task 14: Fechamento

- [ ] **Step 1:** `swift test --package-path Packages/TrainingKit` e `scripts/dev-run.sh --test` → PASS.
- [ ] **Step 2:** Atualizar `docs/superpowers/plans/2026-11-11-pendencias-plano-3.md` marcando o que este plano resolveu; registrar pendências novas em `docs/superpowers/plans/2026-11-xx-pendencias-plano-4.md` se o review final apontar algo não bloqueante. Incluir README e landing page como pendência do próximo plano.
- [ ] **Step 3: Commit** — `docs: registra o estado das pendências ao fim do plano 4`
