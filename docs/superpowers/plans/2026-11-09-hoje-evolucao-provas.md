# trAIning — Hoje, Evolução, Provas e sync em background — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Telas Hoje (com detalhe da prontidão), Evolução, Detalhe de métrica e Provas, nota do treino, sync em background e aviso de manhã, sobre os dados reais do Adriano no simulador.

**Architecture:** Cálculo novo no pacote `Packages/TrainingKit`: fatores da prontidão, projeção de fitness com polimento, série de previsão, nota do treino e GPX em `Metrics`/`WorkoutAnalysis`; um target novo `Insights` monta, a partir do `ModelContext`, os modelos prontos de cada tela (`TodaySummary`, `OverallState`, `MetricSeries`, `RaceOutlook`). `SchemaV3` congela o V2 e acrescenta campos. O app SwiftUI ganha as abas e só consome `Insights`.

**Tech Stack:** Swift 6.4, SwiftUI, Swift Charts, SwiftData (`VersionedSchema`), BackgroundTasks (`BGAppRefreshTask`), UserNotifications, FoundationModels, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-09-hoje-evolucao-provas-design.md` (complementa `2026-11-07-training-design.md` e `2026-11-08-app-pos-treino-design.md`). Mockups de referência em `.superpowers/brainstorm/56511-1794262242/content/` (`hoje-v3.html`, `prontidao-v2.html`, `evolucao-v2.html`, `provas-v1.html`), fora do git.

## Global Constraints

- Deployment target iOS/iPadOS 26; simulador de dev iPhone 18 Pro, iOS 27.1. Pacote `.iOS(.v26), .macOS(.v26)`.
- Identidade: fundo `#07080A`, destaque `#C8F05A`, laranja `#FF8A4C` só para prova, azul `#7FB2FF` fitness/sono; números SF Pro `.compressed`/`.condensed`; só tema escuro; Liquid Glass nos cards.
- Repositório público: nenhum dado real (JSON da API, `.FIT`, store, chave, números da conta) no git. Fixtures sintéticas.
- SwiftData compatível com CloudKit (sem `.unique`, tudo opcional ou com padrão, relacionamentos opcionais), `cloudKitDatabase: .none`.
- Sem comentários no código, salvo workaround não óbvio. Types em `*Types.swift`, constantes em `*Constants.swift`, ao lado do código.
- Testes do pacote: Swift Testing, `swift test --package-path Packages/TrainingKit`. Testes do app: `scripts/dev-run.sh --test`.
- Nunca ler, imprimir ou commitar `~/.config/garmin/connect-personal-api-key`; só `scripts/dev-run.sh` a lê.
- Git: branch `feat/hoje-evolucao-provas`. Commit ao fim de cada tarefa, Conventional Commits PT-BR minúsculo, sem trailer de coautoria nem menção a IA, com aprovação do Adriano antes de cada commit. Sem push, merge ou rebase.
- Depois de cada tarefa que muda a UI, o controlador roda `scripts/dev-run.sh` e o simulador fica aberto no app.
- Toda projeção aparece tracejada e rotulada ("projeção", "no dia da prova"). Card sem dado suficiente mostra versão reduzida com o motivo em uma linha.
- Frases geradas por Foundation Models só na frase da prontidão e no resumo do estado geral, com validador de números e fallback por template (padrão do target `Narrative`).

## Review Focus

- Primeiro uso sem prova cadastrada, sem 30 dias de histórico e sem zonas → Hoje, Evolução e Provas renderizam versões reduzidas com motivo, sem crash nem "—" em tudo. Teste em Task 8 (`InsightsEmptyStoreTests`).
- Prova no passado ou hoje como prova-alvo → prova-alvo é a próxima a partir de amanhã; prova de hoje aparece em Provas como "hoje", não some. Teste em Task 8.
- Prontidão calculada antes das 6h, recalculada depois com outro número → aviso agendado troca o texto, nunca dois avisos no dia. Teste em Task 13.
- Prova com paces manuais que deixam o resto inviável depois que o alvo muda → card diz que a estratégia ficou inviável e oferece limpar, sem tabela vazia muda. Teste em Task 11.
- Corrida com prescrição mas sem FC (sensor desligado) → nota do treino só com execução, decomposição diz "sem FC". Teste em Task 5.

---

### Task 1: `SchemaV3` com campos novos

**Files:**
- Create: `Sources/Storage/SchemaV2Models.swift` (cópia congelada dos modelos atuais como tipos aninhados em `SchemaV2`, como foi feito no `SchemaV1`), `Sources/Storage/SchemaV3.swift`
- Modify: `Sources/Storage/SchemaV2.swift`, `TrainingMigrationPlan.swift`, `TrainingSchema.swift`, `ActivityRecord.swift`, `RaceRecord.swift`, `SyncState.swift`, `RaceTransfer.swift`, `RaceTransferTypes.swift`
- Test: `Tests/StorageTests/MigrationTests.swift`, `RaceTransferTests.swift`

**Interfaces:**
- Produces:
  - `ActivityRecord.fitTransientFailures: Int = 0`
  - `RaceRecord.frozenTargetSeconds: Double? = nil`, `RaceRecord.frozenTargetDay: String? = nil`
  - `SyncState.readinessVersion: Int = 0`
  - `SchemaV3` (versão 3.0.0) referencia as classes vivas; `SchemaV2` passa a referenciar as cópias congeladas; migração leve V2 → V3.
  - `RaceTransferItem` ganha `frozenTargetSeconds` e `frozenTargetDay` opcionais; arquivo de versão 1 sem esses campos continua importando.

- [ ] **Step 1: Testes que falham:** `v2StoreMigratesToV3` (store criado com `SchemaV2` e uma atividade, uma prova e um `SyncState` → abre com `TrainingSchema.container(url:)`, dados preservados, campos novos com padrão); `raceTransferRoundTripsFrozenTarget`; `importsFileWithoutFrozenFields`.
- [ ] **Step 2: Rodar** `--filter StorageTests` → FAIL.
- [ ] **Step 3: Implementar.** `SchemaV2Models.swift` espelha exatamente os modelos do commit `ab64561`.
- [ ] **Step 4: Rodar a suíte inteira** → PASS.
- [ ] **Step 5: Commit** — `feat(storage): schema v3 com alvo congelado da prova e contador de falhas de fit`

---

### Task 2: Prontidão como estado da manhã

**Files:**
- Modify: `Sources/Sync/DerivedMetrics.swift`, `Sources/Sync/SyncEngine.swift`, `Sources/Sync/SyncConstants.swift`
- Test: `Tests/SyncTests/SyncEngineTests.swift`

**Interfaces:**
- Consumes: `SyncState.readinessVersion` (Task 1).
- Produces:
  - A razão aguda:crônica usada na prontidão do dia `D` é `acuteChronicRatio(dailyLoad:on: D.adding(days: -1))`.
  - `SyncConstants.readinessVersion = 1`. Quando `state.readinessVersion < 1`, o run recalcula a prontidão de todos os dias guardados e grava a versão.
  - `loadAffectedDays` passa a marcar de `D+1` até `D+28` (a atividade do dia `D` não muda mais a prontidão de `D`).

- [ ] **Step 1: Testes que falham:** `readinessIgnoresSameDayLoad` (sync, depois atividade nova hoje com carga 3000 → prontidão de hoje igual à de antes); `lateActivityRecomputesFollowingReadiness` passa a usar a atividade em `-12` e conferir o dia `-10` (continua mudando); `readinessVersionTriggersFullRecompute` (store com `readinessVersion == 0` e notas antigas → depois do run todas recalculadas e versão 1).
- [ ] **Step 2: Rodar** `--filter SyncTests` → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar a suíte inteira** → PASS (ajustar testes do plano 2 que dependiam da carga do mesmo dia, só nas expectativas).
- [ ] **Step 5: Commit** — `fix(sync): calcula prontidão com a carga até o dia anterior`

---

### Task 3: Modo background do sync e limite de falhas de FIT

**Files:**
- Create: `Sources/Sync/SyncMode.swift`
- Modify: `Sources/GarminAPI/GarminClient.swift`, `GarminEndpoints.swift`, `Sources/Sync/SyncEngine.swift`, `FITSync.swift`, `ReprocessQueue.swift`, `SyncConstants.swift`, `SyncReport.swift`
- Test: `Tests/GarminAPITests/GarminClientTests.swift`, `Tests/SyncTests/BackgroundSyncTests.swift`

**Interfaces:**
- Consumes: `ActivityRecord.fitTransientFailures` (Task 1).
- Produces:
  - `public enum SyncMode: Sendable { case foreground, background }`
  - `GarminClient.init(..., waitsOnRateLimit: Bool = true)`: com `false`, o primeiro 429 lança `.rateLimited(path:)` sem dormir.
  - `SyncEngine.init(..., mode: SyncMode = .foreground)`. Em `.background`: `fitLimit` efetivo `SyncConstants.backgroundFitLimit = 3`; 429 em qualquer passo encerra o run com sucesso parcial (cursores gravados, `SyncReport.stoppedByRateLimit = true`) em vez de lançar.
  - FIT com resultado `.skipped` incrementa `fitTransientFailures`; com `fitTransientFailures >= SyncConstants.maxFitTransientFailures` (5) a atividade sai de `fitQueue`. `reprocess(limit:)` zera o contador das que processa.

- [ ] **Step 1: Testes que falham:** `clientFailsFastOnRateLimitWhenAsked` (sleeps vazio); `backgroundStopsOnRateLimitWithoutThrowing` (429 nas atividades → report com `stoppedByRateLimit`, cursor gravado, run seguinte em foreground retoma da página); `backgroundRespectsFitLimit` (5 pendentes → 3 chamadas); `transientFitFailuresLeaveQueueAfterLimit` (5xx sempre → depois de 5 runs a atividade não é mais pedida; `reprocess` volta a pedir).
- [ ] **Step 2: Rodar** → FAIL.
- [ ] **Step 3: Implementar.** O cliente do modo background é criado com `waitsOnRateLimit: false` por quem monta o engine (Task 13).
- [ ] **Step 4: Rodar a suíte inteira** → PASS.
- [ ] **Step 5: Commit** — `feat(sync): modo background sem espera em 429 e limite de falhas de fit`

---

### Task 4: Métricas novas — fatores da prontidão, fitness até a prova, série de previsão, GPX

**Files:**
- Create: `Sources/Metrics/ReadinessBreakdown.swift`, `ReadinessBreakdownTypes.swift`, `FitnessOutlook.swift`, `FitnessOutlookTypes.swift`, `PredictionSeries.swift`, `GPXProfile.swift`
- Modify: `Sources/Metrics/Readiness.swift` (expor notas por componente), `ReadinessConstants.swift`, `RaceConstants.swift`
- Test: `Tests/MetricsTests/ReadinessBreakdownTests.swift`, `FitnessOutlookTests.swift`, `PredictionSeriesTests.swift`, `GPXProfileTests.swift`

**Interfaces:**
- Produces:
  - `public enum ReadinessComponent: String, CaseIterable, Sendable { case hrv, sleep, bodyBattery, load }` com pesos atuais (0,35/0,25/0,20/0,20).
  - `public func readinessComponents(_ input: ReadinessInput) -> [ReadinessComponent: Double]` (notas 0–100 dos presentes; mesma conta de `readiness`).
  - `public struct ReadinessFactor { component; todayScore: Double?; normalScore: Double?; points: Double?; weight: Double }` e `public struct ReadinessBreakdown { score: Int; normal: Double?; factors: [ReadinessFactor] }` (fatores ordenados por `|points|` desc, ausentes no fim).
  - `public func readinessBreakdown(today: ReadinessInput, history: [ReadinessInput]) -> ReadinessBreakdown?`: normal de cada componente = média das notas do componente em `history` (até 30 dias anteriores) com pelo menos `ReadinessConstants.normalMinimumDays = 14` presenças; `points = w̃ · (hoje − normal)` com `w̃` renormalizado entre os presentes hoje; `normal = Double(score) − Σ points` quando todos os presentes têm normal, senão nil.
  - `public struct FitnessOutlook { history: [FFFPoint]; projection: [FFFPoint]; peakFitness: Double?; raceDayForm: Double? }` e `public func fitnessOutlook(dailyLoad: [Day: Double], today: Day, raceDay: Day?) -> FitnessOutlook`: carga futura = média diária das últimas 28 dias; nos `RaceConstants.taperDays = 14` antes da prova, × `(1 − RaceConstants.taperReduction)` com `taperReduction = 0.4`; sem prova, 30 dias sem polimento; histórico de 120 dias.
  - `public func predictionSeries(distance: Double, efforts: [Effort], from: Day, to: Day) -> [(Day, Double)]` (um ponto por dia com `predict(distance:efforts:on:)` não nil).
  - `public func gpxProfile(_ data: Data) throws -> [(distance: Double, altitude: Double)]` (trkpt/rtept com `ele`; distância acumulada por haversine; lança `GPXError.noElevation` sem elevação).

- [ ] **Step 1: Testes que falham:**
  - `breakdownSumsToDifferenceFromNormal`: 20 dias de histórico com notas fixas por componente e hoje diferente → `abs(Σ points − (score − normal)) < 1e-9`; caso do mockup: componentes de hoje HRV 95, sono 54, BB 85, carga 50 e normais 75/64/75/52,5 → pontos +7,0 / −2,5 / +2,0 / −0,5.
  - `breakdownNeedsFourteenDays`: 13 dias → `normalScore == nil`, `points == nil`.
  - `missingComponentRenormalizesWeights`: sem Body Battery hoje → pesos dos três somam 1 e o fator BB vem por último com `todayScore == nil`.
  - `taperRaisesFormOnRaceDay`: carga constante 60/dia por 120 dias, prova em 30 dias → `raceDayForm > form de hoje` e `peakFitness` ocorre antes do dia da prova.
  - `noRaceProjectsThirtyDaysFlat`: `projection.count == 30`, `raceDayForm == nil`.
  - `predictionSeriesSkipsDaysWithoutEfforts` e `predictionSeriesMatchesPredictOnEachDay`.
  - `gpxProfileAccumulatesDistance` (3 pontos sintéticos a 0,001° de latitude → distância ≈ 111,2 m por trecho ±0,5) e `gpxWithoutElevationThrows`.
- [ ] **Step 2: Rodar** `--filter MetricsTests` → FAIL.
- [ ] **Step 3: Implementar.** `readiness(_:)` passa a usar `readinessComponents` (sem mudar o resultado; testes existentes continuam).
- [ ] **Step 4: Rodar a suíte inteira** → PASS.
- [ ] **Step 5: Commit** — `feat(metrics): fatores da prontidão, fitness até a prova, série de previsão e perfil de gpx`

---

### Task 5: Nota do treino

**Files:**
- Create: `Sources/WorkoutAnalysis/WorkoutScore.swift`, `WorkoutScoreTypes.swift`
- Modify: `Sources/WorkoutAnalysis/AnalysisConstants.swift`
- Test: `Tests/WorkoutAnalysisTests/WorkoutScoreTests.swift`

**Interfaces:**
- Consumes: `WorkoutBlock`, `BlockStatus`, `HeartRateZones`, `WorkoutOccurrence` (plano 2).
- Produces:
  - `public enum ScorePart: String, Sendable { case execution, intent, cost }`
  - `public struct ScoreItem: Sendable, Equatable { part: ScorePart; points: Double; maximum: Double; reason: ScoreReason? }` com `public enum ScoreReason: String, Sendable { case blocksOffTarget, incompleteStep, notExecuted, easyTooHard, hardTooEasy, heartRateTargetMissed, lessEfficient, moreEfficient, noHeartRate, noZones, noHistory, noPrescription }`
  - `public struct WorkoutScore: Sendable, Equatable { value: Int; items: [ScoreItem] }`
  - `public func scoreWorkout(blocks: [WorkoutBlock], zones: HeartRateZones?, previous: [WorkoutOccurrence]) -> WorkoutScore?` (nil para lista vazia de blocos).
  - Constantes: pesos `execution 50`, `intent 25`, `cost 25`; `costSaturation = 0.05`; custo vale 50% do máximo na mediana.
  - Parte ausente vira item com `points == 0`, `maximum == 0` e o motivo (`.noPrescription`, `.noHeartRate`, `.noZones`, `.noHistory`), para a tela explicar; ela não entra na normalização.
  - Regras exatamente como na seção "Nota do treino" da spec: execução por fração de tempo dos ativos com alvo `.inTarget`, incompleto = fração executada, não executado = 0; intenção só com prescrição (aquecimento/desaquecimento até o teto da Z2, treino prescrito leve com ativos até o teto da Z2, alvo de FC = próprio alvo, alvo de pace abaixo do piso da Z2 tira pontos, recuperação fora); custo pela razão velocidade/FC dos ativos contra a mediana das ocorrências; partes ausentes redistribuem os pesos e a nota final é `Σ points / Σ maximum × 100`.

- [ ] **Step 1: Testes que falham:**
  - `perfectIntervalAtParScoresAboutEightySeven`: 6 tiros no alvo, aquecimento em Z2, eficiência igual à mediana de 3 ocorrências → `value == 88` (50 + 25 + 12,5 = 87,5 arredonda para 88) e itens `execution 50/50`, `intent 25/25`, `cost 12.5/25`.
  - `fivePercentMoreEfficientMaxesCost`: custo `25/25` com `.moreEfficient`.
  - `incompleteBlockCreditsExecutedFraction`: 1 bloco ativo de 2000 m feito 1000 m → execução 25/50 com `.incompleteStep`.
  - `easyRunTooHardLosesIntent`: treino leve prescrito com ativo em Z4 → intenção < 25 com `.easyTooHard`.
  - `recoveryIsIgnoredForIntent`: recuperações em Z4 não mudam a intenção.
  - `freeRunScoresOnlyCost`: sem prescrição → `execution` e `intent` com `maximum == 0` e `.noPrescription`; nota = custo/25×100.
  - `noHeartRateScoresOnlyExecution` (Review Focus): blocos sem FC → nota = execução/50×100; itens `intent` e `cost` com `maximum == 0` e `reason == .noHeartRate`.
  - `noHistoryDropsCost`: `previous` vazio → item `cost` com `maximum == 0`, `reason == .noHistory`; nota = (execução + intenção)/75×100.
- [ ] **Step 2: Rodar** `--filter WorkoutAnalysisTests` → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar a suíte inteira** → PASS.
- [ ] **Step 5: Commit** — `feat(analysis): nota do treino com execução, intenção e custo`

---

### Task 6: Calibração com o Garmin Connect (manual, com o Adriano)

**Files:**
- Modify (se preciso): `Sources/Metrics/RaceConstants.swift`, `Sources/Metrics/RunMetricsConstants.swift`

- [ ] **Step 1:** O controlador roda `scripts/dev-run.sh` e o `trainingctl report --store <store do simulador>` e mostra ao Adriano VO2max e previsões 5/10/21,1/42,2.
- [ ] **Step 2:** O Adriano informa os valores do Garmin Connect. Alvo: VO2max ±1,5; previsões ±3%.
- [ ] **Step 3:** Fora do alvo: ajustar constantes (expoente de Riegel, pesos por `EffortKind`, janela de esforços, suavização do VO2max) uma de cada vez, rodando a suíte e o report até entrar no alvo. Números da conta real não vão para arquivo nenhum do repositório.
- [ ] **Step 4:** Rodar a suíte inteira → PASS (testes que fixam constantes ajustados junto).
- [ ] **Step 5: Commit** (só se mudou constante) — `fix(metrics): calibra previsões e vo2max com o garmin connect`

---

### Task 7: Narrativas da prontidão e do estado geral

**Files:**
- Create: `Sources/Narrative/ReadinessNarrator.swift`, `OverallNarrator.swift`, `InsightNarrativeTypes.swift`
- Modify: `Package.swift` (`Narrative` passa a depender também de `Metrics`), `Sources/Narrative/NarrativeConstants.swift`, `NarrativeCheck.swift` (reuso do validador)
- Test: `Tests/NarrativeTests/InsightNarratorTests.swift`

**Interfaces:**
- Consumes: `ReadinessBreakdown` (Task 4), `OverallFacts` (definido aqui; Task 8 preenche).
- Produces:
  - `public struct OverallFacts: Sendable { verdict: OverallVerdict; improved: Int; worsened: Int; total: Int; goalGapSeconds: Double?; raceDayGapSeconds: Double? }`, `public enum OverallVerdict: String, Sendable { case better, stable, worse }`
  - `public protocol InsightNarrator: Sendable { func readinessSentence(_ b: ReadinessBreakdown, verdict: ReadinessVerdict) async -> String; func overallSentence(_ f: OverallFacts) async -> String }`
  - `public func makeInsightNarrator() -> any InsightNarrator` (Foundation Models se disponível, senão template; erro ou número fora dos fatos → template).
  - `public func morningNotificationText(_ b: ReadinessBreakdown, verdict: ReadinessVerdict) -> String` (template puro, ex.: "Prontidão 74 · pode treinar forte. HRV acima do seu normal, sono abaixo.").

- [ ] **Step 1: Testes que falham:** `templateReadinessNamesTopFactors` (dois maiores |points| com "acima/abaixo do seu normal"); `morningTextMatchesSpecExample` (fatores do mockup → texto exato acima); `fallsBackWhenGeneratedNumberIsNotAFact` (gerador fake com número inventado → template); `overallTemplateCoversVerdicts`.
- [ ] **Step 2: Rodar** `--filter NarrativeTests` → FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar a suíte inteira** → PASS.
- [ ] **Step 5: Commit** — `feat(narrative): frases da prontidão e do estado geral`

---

### Task 8: Target `Insights` — modelos de Hoje, Evolução, Detalhe de métrica e prova-alvo

**Files:**
- Create: target `Insights` (depende de `TrainingCore`, `Metrics`, `Projections`, `Storage`, `Reports`, `WorkoutAnalysis`, `Narrative`) com `Sources/Insights/TodayBuilder.swift`, `TodayTypes.swift`, `OverallState.swift`, `OverallStateTypes.swift`, `MetricSeries.swift`, `MetricSeriesTypes.swift`, `RaceOutlook.swift`, `RaceOutlookTypes.swift`, `InsightsConstants.swift`; test target `InsightsTests`
- Modify: `Package.swift`, `Sources/Reports/ReportBuilder.swift` (expor `public func efforts() throws -> [Effort]` e `dailyLoad`)
- Test: `Tests/InsightsTests/TodayBuilderTests.swift`, `OverallStateTests.swift`, `RaceOutlookTests.swift`, `MetricSeriesTests.swift`, `InsightsEmptyStoreTests.swift`

**Interfaces:**
- Consumes: Tasks 4 e 7 (`OverallFacts`), `project` (Projections), `ReportBuilder`.
- Produces:
  - `public func targetRace(in context: ModelContext, today: Day) throws -> RaceRecord?`: próxima prova A com dia > hoje; sem A, a próxima de qualquer prioridade.
  - `public struct RaceOutlook { distance: Double; label: String; today: Double?; raceDay: ProjectionPoint?; yearAgo: Double?; series: [(Day, Double)]; projection: [ProjectionPoint]; goalSeconds: Double?; goalCrossing: GoalCrossing; assessment: GoalAssessment? }` com `public enum GoalCrossing { case on(Day), alreadyBeaten, unreachable, noGoal }`. Sem prova: meia maratona, `goalSeconds == nil`. `raceDay` = ponto do `project` no dia da prova (horizonte até a prova); `goalCrossing` com horizonte de 365 dias. `assessment` contra `raceDay.mid`, ou `today` sem projeção.
  - `public struct TodaySummary { readiness: ReadinessBreakdown?; verdict: ReadinessVerdict?; supporting: ReadinessSupport; fitness: FitnessOutlook; race: RaceOutlook; raceCountdownDays: Int?; racePriority: RacePriority?; week: WeekVolume; predictions: [Prediction]; lastRunId: Int64? }`, `WeekVolume { perDay: [Day: Double]; total: Double; lastWeek: Double; average4Weeks: Double }` (só corrida), `ReadinessSupport { hrvVsBaseline: Double?; sleepScore: Int?; acuteChronic: Double?; stress: Int? }`.
  - `public func todaySummary(context: ModelContext, today: Day) throws -> TodaySummary`.
  - `public struct Indicator { kind: IndicatorKind; today: Double?; delta: Double?; goalGap: Double?; trend: IndicatorTrend }`, `IndicatorKind { racePrediction, vo2max, fitness, zone2Pace, thresholdPace, monthlyVolume }`, `IndicatorTrend { better, same, worse, unknown }`; `public struct OverallState { indicators: [Indicator]; facts: OverallFacts }`; `public func overallState(context: ModelContext, today: Day) throws -> OverallState`. Variação contra o mesmo cálculo em `today − 90`; margens em `InsightsConstants`: previsão 0,5%, VO2max 0,5, fitness 2, paces 3 s/km, volume 10%; menor é melhor para previsão e paces. Veredito: melhoras − pioras ≥ 2 → `.better`, ≤ −2 → `.worse`, senão `.stable`.
  - `public enum MetricKind: String, CaseIterable { vo2max, zone2Pace, fitness, monthlyVolume, loadFocus, thresholdPace, thresholdHeartRate, prediction5k, prediction10k, predictionHalf, predictionFull, durability, hillStrength, cadence, groundContact, verticalOscillation, restingHeartRate, hrv, sleep, bodyBattery, zoneDistribution }` e `public struct MetricSeries { kind; points: [(Day, Double)]; movingAverage7: [(Day, Double)]; normalBand: ClosedRange<Double>?; projection: [ProjectionPoint]; raceDayValue: Double?; stats: MetricStats; monthly: [(Day, Double)]; lastYear: [(Day, Double)]; reading: String }`; `public func metricSeries(_ kind: MetricKind, context: ModelContext, today: Day, period: MetricPeriod) throws -> MetricSeries` com `MetricPeriod { sixMonths, oneYear, twoYears, all }`; `reading` por template.

- [ ] **Step 1: Testes que falham** (store em memória com dados sintéticos montados por helper em `Tests/InsightsTests/Support/InsightsFixtures.swift`):
  - `targetRacePrefersNextA`, `targetRaceSkipsTodayAndPast` (Review Focus).
  - `raceOutlookCrossingAfterRace`, `raceOutlookAlreadyBeaten`, `raceOutlookUnreachable`, `raceOutlookWithoutRaceUsesHalf`.
  - `weekVolumeCountsOnlyRuns` (pedalada no meio não soma).
  - `overallVerdictBetterWhenTwoMoreImprove`, `overallMarginIgnoresNoise` (VO2max +0,4 → `.same`), `overallSkipsMissingIndicators`.
  - `metricSeriesHasMovingAverageAndProjection` para `vo2max` e `hrv` (faixa normal presente só no HRV).
  - `InsightsEmptyStoreTests.everyBuilderWorksOnEmptyStore` (Review Focus): store vazio → nenhum builder lança; `todaySummary.readiness == nil`, `race.today == nil`, `overallState.facts.total == 0`.
- [ ] **Step 2: Rodar** `--filter InsightsTests` → FAIL.
- [ ] **Step 3: Implementar.** Prontidão do dia e histórico de 30 dias lidos de `DailyRecord` com a mesma montagem de `ReadinessInput` do sync (extrair um helper público em `Sync` ou `Insights`, sem duplicar).
- [ ] **Step 4: Rodar a suíte inteira** → PASS.
- [ ] **Step 5: Commit** — `feat(insights): modelos de hoje, estado geral, séries de métrica e previsão da prova`

---

### Task 9: App — abas, Hoje e detalhe da prontidão

**Files:**
- Create: `App/Today/TodayView.swift`, `TodayModel.swift`, `TodayTypes.swift`, `TodayConstants.swift`, `ReadinessCard.swift`, `FitnessCard.swift`, `RacePredictionCard.swift`, `WeekCard.swift`, `PredictionsCard.swift`, `LastRunCard.swift`, `App/Today/Readiness/ReadinessDetailView.swift`, `ReadinessFactorRow.swift`; `AppTests/TodayModelTests.swift`
- Modify: `App/AppSection.swift` (casos `today`, `evolution`, `workouts`, `races`, `settings`, nessa ordem, `today` inicial), `App/RootView.swift`, `project.yml` (target do app depende de `Insights`)

**Interfaces:**
- Consumes: `todaySummary`, `ReadinessBreakdown`, `makeInsightNarrator` (Tasks 4, 7, 8), `WorkoutAnalysisContext` (plano 2) para o último treino.
- Produces: `TodayModel(context:today:)` com `summary: TodaySummary`, `readinessSentence: String`, `lastRun: (title: String, dateText: String, rows: [ComparisonRow], evolution: String?)?`; deep link `training://hoje` e `training://hoje/prontidao`.

- [ ] **Step 1: Testes que falham:** `todayModelBuildsFromStore` (fixtures do plano 2 + diários sintéticos → os seis cards com dados); `todayModelWithoutRaceShowsHalfAndNoCountdown`; `lastRunUsesPlan2Comparison` (mesmas linhas de `WorkoutAnalysisContext.build`).
- [ ] **Step 2: Rodar** `scripts/dev-run.sh --test` → FAIL.
- [ ] **Step 3: Implementar** os cards na ordem e no formato de `hoje-v3.html` e `prontidao-v2.html` (iPhone: tab bar flutuante e rolagem; iPad: barra lateral com as mesmas seções, card fixo da prova-alvo embaixo, e Hoje em grade na mesma ordem de leitura): prontidão (nota, veredito, régua 40/70, quatro números de apoio), fitness até a prova (hoje, pico, forma no dia; azul e amarelo; tracejado), previsão da prova (hoje, no dia, faixa, 12 meses atrás, meta, marca da prova, frase de `GoalCrossing`), semana, previsões, último treino. Detalhe da prontidão: resumo "+N sobre o seu normal (M)", frase gerada, listas "Puxando para cima"/"Puxando para baixo", "sem dado" no fim, stress como contexto.
- [ ] **Step 4: Rodar** `scripts/dev-run.sh --test` → PASS; o controlador roda `scripts/dev-run.sh` e confere Hoje com os dados reais.
- [ ] **Step 5: Commit** — `feat(app): tela hoje e detalhe da prontidão`

---

### Task 10: App — Evolução e Detalhe de métrica

**Files:**
- Create: `App/Evolution/EvolutionView.swift`, `EvolutionModel.swift`, `EvolutionTypes.swift`, `OverallStateCard.swift`, `MetricCard.swift`, `App/Evolution/Detail/MetricDetailView.swift`, `MetricDetailModel.swift`, `MetricChart.swift`; `AppTests/EvolutionModelTests.swift`

**Interfaces:**
- Consumes: `overallState`, `metricSeries`, `MetricKind`, `MetricPeriod`, `makeInsightNarrator` (Tasks 7, 8).
- Produces: `EvolutionModel(context:today:)` com `overall: OverallState`, `overallSentence: String`, `cards: [MetricKind]` (ordem da spec principal + HRV, sono, FC de repouso, Body Battery, distribuição por zona); `MetricDetailModel(kind:period:context:today:)`.

- [ ] **Step 1: Testes que falham:** `evolutionShowsSixIndicatorsInOrder` (previsão, VO2max, fitness, Z2, limiar, volume mensal); `goalGapOnlyOnPrediction`; `metricDetailSwitchesPeriod`.
- [ ] **Step 2: Rodar** `scripts/dev-run.sh --test` → FAIL.
- [ ] **Step 3: Implementar** conforme `evolucao-v2.html` (estado geral no topo, seletor de período e de horizonte, destaque da previsão, grade de cards) e o Detalhe de métrica da spec principal.
- [ ] **Step 4: Rodar** → PASS; `scripts/dev-run.sh` e conferência visual.
- [ ] **Step 5: Commit** — `feat(app): evolução com estado geral e detalhe de métrica`

---

### Task 11: App — Provas

**Files:**
- Create: `App/Races/RaceListView.swift`, `RaceListModel.swift`, `RaceEditorSheet.swift`, `RaceEditorModel.swift`, `NextRaceView.swift`, `NextRaceModel.swift`, `PaceStrategyCard.swift`, `RaceBlockCard.swift`, `RaceChecklistCard.swift`, `CompletedRaceView.swift`, `RacesTypes.swift`, `RacesConstants.swift`; `AppTests/NextRaceModelTests.swift`, `RaceEditorModelTests.swift`
- Modify: `Packages/TrainingKit/Sources/Insights/RaceOutlook.swift` (função de alvo congelado)

**Interfaces:**
- Consumes: `RaceOutlook`, `targetRace`, `paceStrategy`, `gpxProfile`, `raceBlock`, `assessGoal`, `RacePriority`, `RaceRecord.frozenTargetSeconds/Day` (Tasks 1, 4, 8; plano 2).
- Produces:
  - `public func strategyTarget(race: RaceRecord, outlook: RaceOutlook, today: Day, context: ModelContext) throws -> StrategyTarget` em `Insights`, `public struct StrategyTarget { seconds: Double; source: StrategyTargetSource; frozenOn: Day? }`, `StrategyTargetSource { raceDayProjection, todayPrediction, goal, frozen }`. Quando `today >= raceDay − 1` e não há alvo congelado, grava `frozenTargetSeconds`/`frozenTargetDay` com o alvo do momento e salva.
  - `NextRaceModel` expõe `strategy: [KmPlan]`, `strategyState: StrategyState { ok, infeasible, noGPX }`, `clearManualPaces()`.

- [ ] **Step 1: Testes que falham:** `strategyTargetsRaceDayProjection`; `strategyFallsBackToTodayThenGoal`; `strategyFreezesOnEve` (no dia anterior grava e depois ignora projeções novas); `infeasibleManualPacesOfferClear` (Review Focus: paces manuais 10:00/km em 20 de 21 km com alvo 1:46 → `.infeasible`, `clearManualPaces()` volta a `.ok`); `noGPXGivesFlatStrategy`; `editorAssessesAgainstRaceDayProjection` (mesma classificação do card); `completedRaceShowsResultVsGoalVsEve`.
- [ ] **Step 2: Rodar** `swift test --filter InsightsTests` e `scripts/dev-run.sh --test` → FAIL.
- [ ] **Step 3: Implementar** a lista (próximas e concluídas, selo PR), o sheet de cadastro (campos da spec principal, importação de GPX pelo `fileImporter`, aviso tranquila/desafiadora/agressiva), a próxima prova conforme `provas-v1.html` (previsão × meta, estratégia por km com altimetria e toque para fixar pace, bloco semana a semana, checklist, leitura do bloco por template) e a prova concluída.
- [ ] **Step 4: Rodar** → PASS; `scripts/dev-run.sh` com uma prova sintética cadastrada no simulador.
- [ ] **Step 5: Commit** — `feat(app): provas com previsão, estratégia de pace e bloco`

---

### Task 12: App — Nota do treino nas telas

**Files:**
- Create: `App/Workouts/Detail/ScoreBadge.swift`, `ScoreBreakdownView.swift`
- Modify: `App/Workouts/Detail/WorkoutAnalysisContext.swift` (calcula `score` com `scoreWorkout`), `WorkoutDetailModel.swift`, `WorkoutDetailView.swift`, `App/Workouts/WorkoutRow.swift`, `WorkoutListModel.swift`, `App/Today/LastRunCard.swift`
- Test: `AppTests/WorkoutDetailModelTests.swift`, `WorkoutListModelTests.swift`

**Interfaces:**
- Consumes: `scoreWorkout`, `WorkoutScore` (Task 5).
- Produces: `WorkoutAnalysisContext.score: WorkoutScore?`; a lista calcula a nota com o mesmo contexto compartilhado (`WorkoutAnalysisInputs`) do plano 2.

- [ ] **Step 1: Testes que falham:** `detailShowsScoreForInterval` (fixture de tiros do plano 2 → nota presente e decomposição com 3 partes); `listShowsScoreOnlyForRuns`; `freeRunScoreHasOnlyCost`.
- [ ] **Step 2: Rodar** → FAIL.
- [ ] **Step 3: Implementar.** Decomposição em "pontos/máximo" por parte com o motivo principal, no estilo do detalhe da prontidão.
- [ ] **Step 4: Rodar** → PASS; `scripts/dev-run.sh`.
- [ ] **Step 5: Commit** — `feat(app): nota do treino na tela, na lista e em hoje`

---

### Task 13: Sync em background e aviso de manhã

**Files:**
- Create: `App/Background/BackgroundSync.swift`, `MorningNotifier.swift`, `BackgroundTypes.swift`, `BackgroundConstants.swift`; `AppTests/MorningNotifierTests.swift`
- Modify: `App/TrainingApp.swift`, `App/AppModel.swift`, `App/SyncEngineConfiguration.swift`, `App/Settings/SettingsView.swift`, `App/Info.plist` (`BGTaskSchedulerPermittedIdentifiers`, `UIBackgroundModes: fetch`), `project.yml`

**Interfaces:**
- Consumes: `SyncMode`, `GarminClient(waitsOnRateLimit:)` (Task 3), `todaySummary` / `readinessBreakdown` (Task 8), `morningNotificationText` (Task 7).
- Produces:
  - Identificador `BackgroundConstants.refreshTaskId = "dev.aglv.training.refresh"`; reagendado a cada execução e ao ir para background, `earliestBeginDate` às 4h do dia seguinte.
  - `protocol NotificationScheduling { func pending() async -> [String]; func schedule(id: String, text: String, at: Date?) async; func cancel(id: String) async }` com implementação sobre `UNUserNotificationCenter` e fake nos testes.
  - `MorningNotifier.evaluate(summary:now:lastAppOpen:settings:)`: não faz nada sem HRV e sono da noite (`readiness.factors` sem `.hrv` ou `.sleep` em `todayScore`), se já notificou hoje (`UserDefaults` com o dia), se o app foi aberto hoje depois do cálculo, ou se desligado. Antes do horário mínimo: agenda para o horário mínimo com id do dia (substitui o texto se já agendado). Depois: entrega imediato. Abrir o app cancela o agendado do dia.
  - Ajustes: chave "Aviso de prontidão" (padrão ligada; pede permissão de notificação ao ligar pela primeira vez, e no primeiro launch depois da atualização) e horário mínimo (padrão 6:00).

- [ ] **Step 1: Testes que falham:** `schedulesAtMinimumHourWhenEarly` (cálculo às 4h → agendado para 6h); `deliversImmediatelyAfterMinimumHour`; `replacesScheduledTextOnRecompute` (Review Focus: dois cálculos antes das 6h → um único agendado com o texto novo); `skipsWithoutHrvOrSleep`; `skipsWhenAlreadyNotifiedOrAppOpened`; `appOpenCancelsScheduled`; `backgroundEngineUsesBackgroundMode`.
- [ ] **Step 2: Rodar** `scripts/dev-run.sh --test` → FAIL.
- [ ] **Step 3: Implementar.** O handler da tarefa roda o sync em `.background`, avalia o aviso e chama `setTaskCompleted`; `expirationHandler` cancela a task do sync. O sync ao abrir o app também avalia o aviso.
- [ ] **Step 4: Rodar** → PASS; no simulador, disparar a tarefa com `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"dev.aglv.training.refresh"]` (ou equivalente documentado no script) e conferir a notificação.
- [ ] **Step 5: Commit** — `feat(app): sync em background e aviso de prontidão de manhã`

---

### Task 14: Fechamento

- [ ] **Step 1:** Rodar `swift test --package-path Packages/TrainingKit` e `scripts/dev-run.sh --test` → PASS.
- [ ] **Step 2:** Atualizar `docs/superpowers/plans/2026-11-08-pendencias-plano-2.md` ("Estado ao fim do plano 2") marcando o que este plano resolveu; registrar pendências novas num arquivo `docs/superpowers/plans/2026-11-xx-pendencias-plano-3.md` se o review final apontar algo não bloqueante.
- [ ] **Step 3: Commit** — `docs: registra o estado das pendências ao fim do plano 3`
