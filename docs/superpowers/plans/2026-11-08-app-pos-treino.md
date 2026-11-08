# trAIning — App pós-treino — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App iOS que abre no simulador com os dados reais do Adriano e mostra cada corrida pelos blocos da prescrição do Treinus, com positivos/negativos/atenção, comparação com o mesmo treino, compartilhamento como imagem e textos gerados no aparelho.

**Architecture:** Lógica nova no pacote `Packages/TrainingKit` (leitura da prescrição no `FITReader`, novo target `WorkoutAnalysis` com blocos, regras, comparação e conteúdo do compartilhamento, novo target `Narrative`, schema versionado no `Storage`, fila de reprocessamento no `Sync`). App SwiftUI em `App/`, projeto gerado por XcodeGen, consumindo o pacote. As telas só consomem.

**Tech Stack:** Swift 6.4, SwiftUI, Swift Charts, MapKit, SwiftData (`VersionedSchema`), FoundationModels, Swift Testing, XcodeGen, `garmin/fit-swift-sdk`.

**Spec:** `docs/superpowers/specs/2026-11-08-app-pos-treino-design.md` (complementa `docs/superpowers/specs/2026-11-07-training-design.md`; pendências em `docs/superpowers/plans/2026-11-08-pendencias-plano-2.md`).

## Global Constraints

- Deployment target iOS/iPadOS 26; simulador de dev iPhone 18 Pro, iOS 27.1. Pacote continua `.iOS(.v26), .macOS(.v26)`.
- Identidade: fundo `#07080A`, destaque `#C8F05A`, laranja `#FF8A4C` só para prova, azul `#7FB2FF` fitness/sono; números em SF Pro `.compressed`/`.condensed`; só tema escuro; Liquid Glass nos cards.
- Logo: TRAINING em caixa alta com "AI" em `#C8F05A`; frase "Inteligência do pulso à linha de chegada."; ícone "AI" verde com brilho. A logo aparece sempre na imagem compartilhada.
- Repositório público: nenhum dado real (JSON da API, `.FIT`, store, chave) no git. Fixtures sintéticas, nunca copiadas de treino real.
- SwiftData compatível com CloudKit (sem `.unique`, tudo opcional ou com padrão, relacionamentos opcionais), `cloudKitDatabase: .none`.
- Sem comentários no código, salvo workaround não óbvio. Types em `*Types.swift`, constantes em `*Constants.swift`, ao lado do código.
- Testes do pacote: Swift Testing, `swift test --package-path Packages/TrainingKit`. Testes do app: `xcodebuild test` no simulador de dev.
- Nunca ler, imprimir ou commitar `~/.config/garmin/connect-personal-api-key`; só o script de dev a lê, direto para o ambiente do processo do app.
- Git: branch `feat/app-pos-treino`. Commit ao fim de cada tarefa, Conventional Commits PT-BR minúsculo, sem trailer de coautoria nem menção a IA. Sem push, merge ou rebase.
- Depois de cada tarefa que muda a UI (6 em diante), o controlador roda `scripts/dev-run.sh` e o simulador fica aberto no app.

## Review Focus

- Corrida livre, sem `workout`/`workout_step` no `.FIT` → seção "Parciais" a partir das voltas, sem status de alvo, sem crash. Teste em Task 3.
- Prescrição com repetição (ex.: 6 × 800 m com 2 min de recuperação): voltas de repetições diferentes têm o mesmo `wkt_step_index` → desdobrar em Tiro 1…6 / Recuperação 1…6 pela ordem. Teste em Task 3.
- Treino encerrado antes do fim da prescrição → passos não executados aparecem como "não executado" e o último executado como incompleto se < 95%. Teste em Task 3.
- Volta final de poucos segundos (`lap_trigger = session_end`, sem `wkt_step_index`) → descartada, não vira bloco. Teste em Task 3.
- Atividade ainda processada pela versão antiga (sem estrutura) → tela mostra resumo e parciais por km das amostras, com aviso "estrutura do treino ainda não baixada", nunca tela vazia. Teste em Task 7 (view model) e Task 5 (fila).

---

### Task 1: Schema versionado, zonas de FC e campos novos

**Files:**
- Create: `Sources/Storage/SchemaV1.swift` (cópia congelada dos 4 modelos atuais como tipos aninhados), `Sources/Storage/SchemaV2.swift`, `Sources/Storage/TrainingMigrationPlan.swift`, `Sources/Storage/HeartRateZonesRecord.swift`
- Modify: `Sources/Storage/ActivityRecord.swift`, `Sources/Storage/TrainingSchema.swift`
- Test: `Tests/StorageTests/MigrationTests.swift`

**Interfaces:**
- Produces:
  - `ActivityRecord` ganha `localDay: String? = nil` (ISO, dia local do início), `processingVersion: Int = 0`, `workoutName: String? = nil`, `structureData: Data? = nil` (JSON de `WorkoutStructure`, Task 2), `narrativeData: Data? = nil` (JSON de `WorkoutNarrative`, Task 10); `samplesData` e `routeData` passam a `@Attribute(.externalStorage)`.
  - `@Model HeartRateZonesRecord { sport: String = "running"; zone1Floor…zone5Floor: Int? ; maxHeartRate: Int?; lactateThresholdHeartRate: Int?; restingHeartRate: Int?; updatedAt: Date = .now }`.
  - `enum SchemaV1: VersionedSchema` (versão 1.0.0, modelos atuais), `enum SchemaV2: VersionedSchema` (versão 2.0.0, modelos de topo atuais + `HeartRateZonesRecord`), `enum TrainingMigrationPlan: SchemaMigrationPlan` com estágio leve V1 → V2.
  - `TrainingSchema.models` = modelos do V2; `container(inMemory:)` e `container(url:)` passam `migrationPlan: TrainingMigrationPlan.self`.

- [ ] **Step 1: Teste que falha** — `v1StoreMigratesToV2`: cria store em URL temporária com `Schema(versionedSchema: SchemaV1.self)`, insere 2 `ActivityRecord` V1 e 3 `DailyRecord` V1, fecha; abre com `TrainingSchema.container(url:)`; espera 2 atividades com `processingVersion == 0`, `structureData == nil`, mesmo `activityId`, e 3 dias. `zonesRecordRoundTrips`: insere e busca `HeartRateZonesRecord`. O teste de CloudKit existente continua passando com o modelo novo.
- [ ] **Step 2: Rodar** `swift test --package-path Packages/TrainingKit --filter StorageTests` → FAIL (`SchemaV1` não existe).
- [ ] **Step 3: Implementar.** `SchemaV1` precisa espelhar exatamente o schema do commit `3fae0c5` (mesmos nomes, tipos e padrões), senão o store do `trainingctl` não casa com a versão 1.
- [ ] **Step 4: Rodar a suíte inteira** → PASS.
- [ ] **Step 5: Verificar com o store real, sem rede:** copiar `garmin-data/store.sqlite` para um temporário e rodar `swift run --package-path Packages/TrainingKit trainingctl report --store <temporário>`; espera os mesmos totais (1043 dias, 645 atividades). Não commitar nada de `garmin-data/`.
- [ ] **Step 6: Commit** — `feat(storage): schema versionado com zonas e campos da estrutura do treino`

---

### Task 2: `FITReader` lê prescrição e voltas

**Files:**
- Create: `Sources/FITReader/WorkoutStructure.swift` (tipos), `Sources/FITReader/WorkoutStructureReader.swift`
- Modify: `Sources/FITReader/FITReader.swift`, `Sources/FITReader/FITSummary.swift`, `Sources/FITReader/FITReaderConstants.swift`, `MessageCollector` (onde estiver)
- Test: `Tests/FITReaderTests/WorkoutStructureTests.swift`, `Tests/FITReaderTests/Support/FITFixtureBuilder.swift`

**Interfaces:**
- Produces (todos `Codable, Sendable, Equatable`):
  - `enum StepIntensity: String { case warmup, active, recovery, cooldown, rest, other }`
  - `enum StepDuration { case distance(meters: Double), time(seconds: Double), open, repeatSteps(fromIndex: Int, count: Int) }`
  - `enum StepTarget { case open, speed(low: Double, high: Double), heartRateBpm(low: Int, high: Int), heartRatePercentMax(low: Int, high: Int), heartRateZone(Int) }` — velocidades em m/s.
  - `struct PrescribedStep { index: Int; intensity: StepIntensity; duration: StepDuration; target: StepTarget }`
  - `struct WorkoutPrescription { name: String?; description: String?; steps: [PrescribedStep] }`
  - `struct LapSummary { stepIndex: Int?; intensity: StepIntensity?; trigger: String?; startOffset: Double; timerSeconds: Double; distance: Double; avgSpeed: Double?; avgHeartRate: Int?; maxHeartRate: Int? }` — `startOffset` em segundos desde o primeiro record.
  - `struct WorkoutStructure { prescription: WorkoutPrescription?; laps: [LapSummary] }`
  - `FITSummary` ganha `structure: WorkoutStructure` (init com padrão vazio para não quebrar chamadas).
  - `FITReaderConstants.processingVersion = 2`.

- [ ] **Step 1: Estender `FITFixtureBuilder`** com `workout(name:description:)`, `step(...)` e `lap(...)` usando o `Encoder` do FIT SDK. Valores sintéticos.
- [ ] **Step 2: Testes que falham:**
  - `readsPaceStepsAndLaps`: 4 passos (aquecimento 3000 m speed 3.0–3.2; ativo 7000 m 3.9–4.15; recuperação 240 s open; ativo 3000 m) + 13 voltas com `wkt_step_index` → `prescription.steps.count == 4`, `steps[1].target == .speed(low: 3.9, high: 4.15)` (tolerância 0,001), `steps[2].duration == .time(seconds: 240)`, `laps.count == 13`, `laps[3].stepIndex == 1`.
  - `readsRepeatStep`: passo `repeat_until_steps_cmplt` com `duration_value = 1`, `target_value = 6` → `.repeatSteps(fromIndex: 1, count: 6)`.
  - `readsHeartRateTargets`: custom HR 245/260 → `.heartRateBpm(low: 145, high: 160)` (no FIT, valor > 100 = bpm + 100); custom 70/80 → `.heartRatePercentMax(70, 80)`; `target_hr_zone = 2` com custom 0 → `.heartRateZone(2)`.
  - `freeRunHasNoPrescription`: sem `workout` → `prescription == nil`, voltas lidas.
  - Os testes de VO2max/rota/reamostragem existentes continuam passando.
- [ ] **Step 3: Rodar** `--filter FITReaderTests` → FAIL.
- [ ] **Step 4: Implementar** com `WorkoutMesg`, `WorkoutStepMesg` e `LapMesg` do SDK. `wkt_description` pode vir em `WorkoutMesg` ou campo de desenvolvedor; se o SDK não expuser, guardar `nil` e anotar no report.
- [ ] **Step 5: Rodar a suíte inteira** → PASS.
- [ ] **Step 6: Commit** — `feat(fit): lê prescrição do treino e voltas por passo`

---

### Task 3: `WorkoutAnalysis` — blocos

**Files:**
- Create: target `WorkoutAnalysis` (depende de `TrainingCore`, `FITReader`) em `Sources/WorkoutAnalysis/Blocks.swift`, `BlockTypes.swift`, `AnalysisConstants.swift`; test target `WorkoutAnalysisTests`
- Modify: `Package.swift`
- Test: `Tests/WorkoutAnalysisTests/BlocksTests.swift`

**Interfaces:**
- Consumes: `WorkoutStructure`, `PrescribedStep`, `LapSummary` (Task 2).
- Produces:
  - `struct HeartRateZones: Sendable, Equatable { floors: [Int]; maxHeartRate: Int? }` (5 pisos, bpm).
  - `enum BlockKind: String, Codable, Sendable { case warmup, active, recovery, cooldown }`
  - `enum BlockStatus: String, Codable, Sendable { case inTarget, faster, slower, aboveTarget, belowTarget, noTarget, incomplete, notExecuted }` (`faster/slower` para pace, `above/below` para FC).
  - `struct WorkoutBlock: Codable, Sendable, Equatable { kind: BlockKind; ordinal: Int; label: String; prescribed: PrescribedStep?; laps: [LapSummary]; seconds: Double; distance: Double; avgSpeed: Double?; avgHeartRate: Int?; maxHeartRate: Int?; dominantZone: Int?; status: BlockStatus }`
  - `func buildBlocks(_ structure: WorkoutStructure, zones: HeartRateZones?) -> [WorkoutBlock]`
  - `func hasPrescription(_ structure: WorkoutStructure) -> Bool`

- [ ] **Step 1: Testes que falham** (estruturas sintéticas montadas direto nos tipos da Task 2):
  - `groupsLapsByStep`: estrutura como `readsPaceStepsAndLaps` → 4 blocos `[warmup, active, recovery, active]`, rótulos `["Aquecimento", "Bloco 1", "Recuperação 1", "Bloco 2"]`, distância do bloco 1 = soma das 7 voltas.
  - `unrollsRepeats`: aquecimento + repeat(6) de [tiro 800 m, recuperação 120 s] + desaquecimento, voltas com o mesmo `stepIndex` a cada repetição → 14 blocos, rótulos `Tiro 1…Tiro 6` e `Recuperação 1…Recuperação 6`.
  - `statusAgainstPaceTarget`: alvo 3.9–4.15 m/s; média 4.0 → `.inTarget`; 4.3 → `.faster`; 3.7 → `.slower`; limites inclusivos.
  - `statusAgainstHeartRateZone`: alvo `.heartRateZone(2)` com pisos `[100,120,140,160,175]`; FC média 130 → `.inTarget`; 150 → `.aboveTarget`.
  - `incompleteAndNotExecuted`: prescrição de 4 passos, voltas só até 60% do passo 2 → bloco 2 `.incomplete`, blocos 3 e 4 `.notExecuted` com `laps == []`.
  - `dropsSessionEndLap`: volta final de 2 s sem `stepIndex` não gera bloco.
  - `freeRunUsesLaps`: `prescription == nil`, 5 voltas → 5 blocos `.active`, `status == .noTarget`, rótulos `Volta 1…5`, `hasPrescription == false`.
- [ ] **Step 2: Rodar** `--filter WorkoutAnalysisTests` → FAIL.
- [ ] **Step 3: Implementar.** Agrupar voltas consecutivas com o mesmo `stepIndex`; percorrer a prescrição expandindo `repeatSteps` na ordem, casando cada grupo de voltas com o próximo passo esperado de mesmo índice. Incompleto = < `AnalysisConstants.completionRatio` (0,95) da distância/tempo prescritos. Zona dominante pela FC média contra os pisos.
- [ ] **Step 4: Rodar a suíte** → PASS.
- [ ] **Step 5: Commit** — `feat(analysis): monta blocos do treino a partir da prescrição`

---

### Task 4: `WorkoutAnalysis` — positivos, negativos, atenção e comparação

**Files:**
- Create: `Sources/WorkoutAnalysis/Assessment.swift`, `AssessmentTypes.swift`, `Comparison.swift`, `ComparisonTypes.swift`
- Modify: `Sources/WorkoutAnalysis/AnalysisConstants.swift`
- Test: `Tests/WorkoutAnalysisTests/AssessmentTests.swift`, `ComparisonTests.swift`

**Interfaces:**
- Consumes: `WorkoutBlock`, `BlockStatus` (Task 3).
- Produces:
  - `enum FindingGroup: String, Codable, Sendable { case positive, negative, attention }`
  - `enum FindingKind: String, Codable, Sendable { case blockInTarget, steadyPace, lowerHeartRateThanBefore, goodRecovery, blockOffTarget, stepIncomplete, paceFade, cardiacDrift, zoneAboveTarget, hardOnLowReadiness, highAcuteChronic }`
  - `struct Finding: Codable, Sendable, Equatable { group: FindingGroup; kind: FindingKind; blockOrdinal: Int?; facts: [String: Double] }`
  - `struct WorkoutAssessment: Codable, Sendable, Equatable { positives: [Finding]; negatives: [Finding]; attention: [Finding] }`
  - `struct AssessmentContext: Sendable { readinessScore: Int?; acuteChronic: Double?; previous: [[WorkoutBlock]] }`
  - `func assess(_ blocks: [WorkoutBlock], context: AssessmentContext) -> WorkoutAssessment`
  - `struct WorkoutOccurrence: Sendable { activityId: Int64; day: Day; blocks: [WorkoutBlock] }`
  - `struct BlockValue: Codable, Sendable, Equatable { speed: Double?; heartRate: Int?; status: BlockStatus }`
  - `struct BlockComparison: Codable, Sendable, Equatable { label: String; values: [Int64: BlockValue] }`
  - `struct WorkoutComparison: Codable, Sendable, Equatable { occurrences: [Int64]; blocks: [BlockComparison]; sameStructure: Bool; activeSpeedDelta: Double?; activeHeartRateDelta: Double? }`
  - `func compare(current: WorkoutOccurrence, previous: [WorkoutOccurrence]) -> WorkoutComparison?` — até `AnalysisConstants.maxComparisons` (4) mais recentes.

- [ ] **Step 1: Testes que falham** (constantes iniciais em `AnalysisConstants`: `steadyPaceSpread = 6` s/km entre voltas cheias do bloco, ignorando volta < 500 m; `driftThreshold = 0.05` de subida da FC média do terço final contra o terço inicial com pace variando ≤ 2%; `goodRecoveryDrop = 25` bpm entre a FC do fim do bloco ativo anterior e o fim da recuperação; `fadeThreshold = 8` s/km da última volta contra a mediana do bloco; `lowReadiness = 50`; `highAcuteChronic = 1.5`):
  - `allBlocksInTargetIsPositive`, `fasterThanTargetIsNegative`, `incompleteIsNegative`.
  - `steadyPaceDetected`: voltas 250, 248, 251, 247, 252 s/km → `steadyPace`; com uma de 262 → não.
  - `cardiacDriftIsAttention`: bloco ativo de 6 voltas com pace constante e FC 150,152,155,158,161,163 → `cardiacDrift` em `attention` com `facts["rise"] ≈ 0.07`.
  - `hardWorkoutOnLowReadiness`: blocos ativos e `readinessScore = 40` → `hardOnLowReadiness`.
  - `emptyGroupsWhenNothingApplies`: corrida livre leve, contexto nil → os três grupos podem ficar vazios, sem crash.
  - `compareSameStructure`: 3 ocorrências anteriores com os mesmos rótulos → `sameStructure == true`, `activeSpeedDelta` = velocidade média dos blocos ativos atual − média da ocorrência mais antiga mostrada.
  - `compareDifferentStructureFlags`: estrutura diferente com mesmo nome → `sameStructure == false`, só blocos com rótulo comum.
  - `compareLimitsToFour`: 6 anteriores → `occurrences.count == 5` (atual + 4).
- [ ] **Step 2: Rodar** `--filter WorkoutAnalysisTests` → FAIL.
- [ ] **Step 3: Implementar.** Cada regra é uma função pequena; `assess` só junta. Nenhum texto aqui: textos vêm de `Narrative` (Task 10) e do template.
- [ ] **Step 4: Rodar a suíte** → PASS.
- [ ] **Step 5: Commit** — `feat(analysis): positivos, negativos, atenção e comparação com o mesmo treino`

---

### Task 5: Sync grava estrutura, zonas e dia local; fila de reprocessamento; cancelamento

**Files:**
- Create: `Sources/Sync/ReprocessQueue.swift`, `Sources/trainingctl/ReprocessCommand.swift`
- Modify: `Sources/Sync/FITSync.swift`, `Sources/Sync/SyncEngine.swift`, `Sources/Sync/Upsert.swift`, `Sources/Sync/SyncReport.swift`, `Sources/GarminAPI/GarminClient.swift` (sleep cancelável), `Sources/trainingctl/main.swift`
- Test: `Tests/SyncTests/StructureSyncTests.swift`, `Tests/SyncTests/CancellationTests.swift`, `Tests/GarminAPITests/` (sleep)

**Interfaces:**
- Consumes: `FITSummary.structure`, `FITReaderConstants.processingVersion` (Task 2), `HeartRateZonesRecord`, campos novos do `ActivityRecord` (Task 1).
- Produces:
  - Processar um `.FIT` grava `structureData` (JSON de `WorkoutStructure`), `workoutName`, `processingVersion = FITReaderConstants.processingVersion`.
  - Upsert de atividade grava `localDay` a partir de `startTimeLocal` (string local do Garmin, sem conversão de fuso).
  - Zonas de FC persistidas em `HeartRateZonesRecord` (um registro por `sport`, upsert).
  - Corridas com `fitProcessed == true && processingVersion < FITReaderConstants.processingVersion` entram na fila depois das novas, do `start` mais recente para o mais antigo, uma por vez; 429 para a fila sem abortar o run (mesma política das novas).
  - `SyncReport` ganha `reprocessed: Int` e `fitStoppedByRateLimit: Bool`.
  - `SyncEngine.run` respeita cancelamento da task que chamou: `Task.checkCancellation()` entre janelas, páginas e cada `.FIT`; o `sleep` padrão do `GarminClient` relança `CancellationError`; cancelado lança `CancellationError` sem gravar `SyncState` de sucesso.
  - `SyncEngine.init` ganha `fitLimit: Int? = nil` (máximo de `.FIT` baixados por run, novos + reprocessados).
  - CLI: `trainingctl reprocess --store <caminho> [--limit N]` roda só a fila de reprocessamento e imprime quantos foram reprocessados e se parou por 429.

- [ ] **Step 1: Testes que falham:**
  - `storesStructureAndVersion`: fake devolve zip com prescrição (helper da Task 2 nos testes de Sync) → registro com `processingVersion == 2`, `workoutName` igual ao do fixture, `structureData` decodifica para a mesma `WorkoutStructure`.
  - `reprocessesOldVersionNewestFirst`: 3 corridas com `fitProcessed == true, processingVersion == 0` em dias diferentes → `fitCalls` em ordem do mais recente; com 429 no segundo → `reprocessed == 1`, `fitStoppedByRateLimit == true`, run termina com sucesso.
  - `respectsFitLimit`: `fitLimit: 2` com 5 pendentes → 2 chamadas.
  - `persistsZones` e `storesLocalDay` (`startTimeLocal = "2026-03-10 23:40:00"` → `localDay == "2026-03-10"` independente do fuso do teste).
  - `cancellationStopsRun`: fake que dorme 0,5 s por janela; cancelar a task após a 1ª → `CancellationError`, `SyncState.lastSync == nil`, nenhuma janela posterior pedida.
  - `clientSleepRethrowsCancellation` em `GarminAPITests`.
- [ ] **Step 2: Rodar** `--filter SyncTests` e `--filter GarminAPITests` → FAIL.
- [ ] **Step 3: Implementar.** A fila usa o mesmo caminho de processamento das novas (sem duplicar código).
- [ ] **Step 4: Rodar a suíte inteira** → PASS.
- [ ] **Step 5: Commit** — `feat(sync): grava estrutura do treino, zonas e reprocessa fit antigos`

O controlador roda, depois do review, `trainingctl reprocess --store garmin-data/store.sqlite --limit 60` (com autorização já dada pelo usuário para a conta real) para enriquecer os treinos recentes antes da Task 6.

---

### Task 6: App no simulador — projeto, script de dev, Keychain, Ajustes, lista de treinos, logo

**Files:**
- Create: `project.yml`, `App/TrainingApp.swift`, `App/AppModel.swift`, `App/AppConstants.swift`, `App/Credentials/KeychainKeyStore.swift`, `App/Brand/Logo.swift`, `App/Brand/BrandColors.swift`, `App/Brand/AIIcon.swift`, `App/Workouts/WorkoutListView.swift`, `App/Workouts/WorkoutRow.swift`, `App/Workouts/WorkoutListModel.swift`, `App/Settings/SettingsView.swift`, `App/Info.plist` (se o XcodeGen não gerar), `scripts/dev-run.sh`, `AppTests/WorkoutListModelTests.swift`
- Modify: `.gitignore` (`*.xcodeproj/`, `App/**/xcuserdata`)

**Interfaces:**
- Consumes: `TrainingSchema.container(url:)`, `SyncEngine`, `GarminClient`, `TokenProvider`, `ActivityTypeKey.isRun`.
- Produces:
  - Target de app `trAIning` (bundle id `dev.aglv.training`), iOS 26, depende dos produtos `Storage`, `Sync`, `GarminAPI`, `TrainingCore`, `WorkoutAnalysis`, `Reports`; test target `AppTests`.
  - `@MainActor @Observable final class AppModel { container: ModelContainer; syncStatus: SyncStatus; func syncNow() async; func cancelSync() }` — store em `Application Support/store.sqlite`; sync ao abrir o app (cancelado quando o app vai para background).
  - `protocol APIKeyStore: Sendable { func read() throws -> String?; func save(_ key: String) throws; func delete() throws }` com `KeychainKeyStore` (sem `kSecAttrSynchronizable`). Em DEBUG, se a variável de ambiente `TRAINING_API_KEY` existir e o Keychain estiver vazio, salva no Keychain.
  - `struct Logo: View { var showsTagline: Bool }`, `struct AIIcon: View { var size: CGFloat }`.
  - `WorkoutListModel.rows(filter: WorkoutFilter, records: [ActivityRecord]) -> [WorkoutRowData]` com `enum WorkoutFilter { case all, run, strength, swim }` e `WorkoutRowData { activityId; title; dateText; distanceText; durationText; paceText; hasPrescription }`.
  - `scripts/dev-run.sh`: `xcodegen generate`; cria o simulador "trAIning iPhone 18 Pro" (iPhone 18 Pro, iOS 27.1) se não existir; boot; `open -a Simulator`; `xcodebuild build` para esse simulador; `simctl install`; na primeira instalação (ou com `--reset-data`) copia `garmin-data/store.sqlite` (e `-wal`/`-shm` se existirem) para `Library/Application Support/` do container do app; `simctl launch` com `SIMCTL_CHILD_TRAINING_API_KEY` lido do arquivo da chave, sem eco. `set -euo pipefail`; nunca `set -x`.

- [ ] **Step 1: Teste que falha** (`AppTests`): `filtersAndFormatsRows` — 3 `ActivityRecord` em container em memória (corrida com `workoutName`, corrida livre, força) → filtro `.run` dá 2 linhas, ordem do mais recente, `paceText == "5:00 /km"` para 10 000 m em 3000 s, `hasPrescription` só na primeira.
- [ ] **Step 2: Rodar** `scripts/dev-run.sh --test` (gera projeto e roda `xcodebuild test` no simulador) → FAIL.
- [ ] **Step 3: Implementar** TabView com Treinos e Ajustes (iPhone) e `NavigationSplitView` (iPad); Ajustes: colar chave, testar conexão (troca de token), forçar sync com progresso, último sync, apagar dados locais (com confirmação). A spec principal pede "ver validade" da chave, mas a Personal API não expõe a validade da chave; mostrar só o resultado do teste de conexão e, em erro `.invalidKey`, o atalho para criar chave nova no Garmin Connect. Lista com cabeçalho `Logo`, filtro segmentado, linhas com selo "Treinus" quando há prescrição. Visual da spec.
- [ ] **Step 4: Rodar** `scripts/dev-run.sh --test` → PASS; `scripts/dev-run.sh` abre o app no simulador com a lista dos treinos reais. Capturar screenshot (`xcrun simctl io booted screenshot`) para o report.
- [ ] **Step 5: Commit** — `feat(app): app no simulador com lista de treinos, ajustes e logo`

---

### Task 7: Tela do treino — resumo, leitura, blocos e comparação

**Files:**
- Create: `App/Workouts/Detail/WorkoutDetailView.swift`, `WorkoutDetailModel.swift`, `SummaryHeader.swift`, `FindingsSection.swift`, `BlocksSection.swift`, `ComparisonSection.swift`, `FindingTemplates.swift`
- Test: `AppTests/WorkoutDetailModelTests.swift`

**Interfaces:**
- Consumes: `buildBlocks`, `assess`, `compare` (Tasks 3–4), `HeartRateZonesRecord`, `DailyRecord.readinessScore`, `acuteChronicRatio` (Metrics).
- Produces:
  - `@MainActor @Observable final class WorkoutDetailModel { init(activityId: Int64, context: ModelContext); summary; blocks: [WorkoutBlock]; assessment: WorkoutAssessment; comparison: WorkoutComparison?; structureMissing: Bool }`.
  - `enum FindingTemplates { static func text(_ finding: Finding, blocks: [WorkoutBlock]) -> String }` — frase pt-BR com os fatos (ex.: "Bloco 1 dentro do pace prescrito, média 4:09/km."). Usado direto até a Task 10 e como fallback depois.

- [ ] **Step 1: Testes que falham:**
  - `buildsFromStoredStructure`: registro com `structureData` de prescrição sintética → `blocks.count` e rótulos esperados, `structureMissing == false`.
  - `missingStructureFallsBackToKmSplits`: `processingVersion == 0`, sem `structureData`, com `samplesData` de 5 km → `structureMissing == true`, 5 blocos "Km 1…5", sem status.
  - `comparisonUsesSameWorkoutName`: 3 registros com mesmo `workoutName` e um diferente → comparação com 3 ocorrências.
  - `freeRunComparesBySimilarDistance`: corrida livre de 10 km; anteriores de 9 km (há 30 dias), 12,5 km (há 20 dias) e 10,5 km (há 120 dias) → só a de 9 km entra (spec principal: mesmo tipo, distância ±20%, últimos 90 dias).
  - `templatesNeverEmpty`: cada `FindingKind` gera texto não vazio com os números do `facts`.
- [ ] **Step 2: Rodar** `scripts/dev-run.sh --test` → FAIL.
- [ ] **Step 3: Implementar** a tela conforme o mockup aprovado (`treino-detalhe`): resumo; três grupos Positivos / Negativos / Atenção ("nenhum" quando vazio); "Blocos × prescrito" com faixa prevista e barra do feito colorida pela zona, status, e as voltas do bloco ao expandir; "Parciais" para corrida livre; aviso de estrutura não baixada; comparação com até 4 ocorrências e frase de evolução. Tocar numa linha da lista abre a tela.
- [ ] **Step 4: Rodar** `scripts/dev-run.sh --test` → PASS; abrir no simulador o treino de 03/11 (se já reprocessado) e uma corrida livre.
- [ ] **Step 5: Commit** — `feat(app): tela do treino com blocos da prescrição e leitura`

---

### Task 8: Tela do treino — mapa, curva de FC, zonas; outros esportes

**Files:**
- Create: `App/Workouts/Detail/RouteMapView.swift`, `HeartRateChart.swift`, `ZonesBar.swift`, `SimpleWorkoutDetail.swift`
- Modify: `WorkoutDetailView.swift`
- Test: `AppTests/ChartDataTests.swift`

**Interfaces:**
- Consumes: `ActivityRecord.routeData` (`[Coordinate]`), `samplesData` (`[FITSample]`), `zoneSeconds`, `HeartRateZonesRecord`, `WorkoutBlock` (faixas dos blocos no gráfico).
- Produces: `enum ChartData { static func heartRateSeries(_ samples: [FITSample]) -> [(t: Double, bpm: Int)]; static func zoneShares(_ zoneSeconds: [Double]) -> [Double] }`.

- [ ] **Step 1: Testes que falham:** `heartRateSeriesSkipsNil`, `zoneSharesSumToOne` (zeros → todos 0, sem NaN).
- [ ] **Step 2: Rodar** `scripts/dev-run.sh --test` → FAIL.
- [ ] **Step 3: Implementar** mapa MapKit com a polilinha (sem rota → seção some), curva de FC com faixas de zona e os blocos sombreados, barra de tempo em zona. Natação e força: tela simples com tempo, FC, carga e distância quando houver.
- [ ] **Step 4: Rodar** `scripts/dev-run.sh --test` → PASS; conferir no simulador.
- [ ] **Step 5: Commit** — `feat(app): mapa, curva de fc e zonas no treino`

---

### Task 9: Compartilhar

**Files:**
- Create: `Sources/WorkoutAnalysis/ShareContent.swift`, `ShareTypes.swift`; `App/Share/ShareEditorView.swift`, `ShareCardView.swift` (4 modelos), `ShareRenderer.swift`, `App/Brand/AppIconExport.swift`; ícone em `App/Assets.xcassets/AppIcon.appiconset`
- Test: `Tests/WorkoutAnalysisTests/ShareContentTests.swift`, `AppTests/ShareRendererTests.swift`

**Interfaces:**
- Produces:
  - `enum ShareTemplate: String, CaseIterable, Codable { case storiesDark, transparent, blocks, strip }`
  - `enum ShareField: String, CaseIterable, Codable { case route, title, distance, time, avgPace, avgHeartRate, activePace, elevation, readingLine }` — padrão ligado: todos menos `elevation` e `readingLine`. Não existe campo para a logo.
  - `struct ShareValue: Sendable, Equatable { field: ShareField; value: String; label: String }`, `struct BlockBar: Sendable, Equatable { kind: BlockKind; zone: Int?; height: Double }`
  - `struct ShareContent: Sendable, Equatable { title: String?; values: [ShareValue]; route: [Coordinate]?; blockBars: [BlockBar]?; readingLine: String? }`
  - `func shareContent(record: WorkoutShareInput, enabled: Set<ShareField>, template: ShareTemplate) -> ShareContent` — `WorkoutShareInput` com os dados já calculados; `activePace` só existe com prescrição; `blockBars` só no modelo `blocks`.
  - `ShareRenderer.render(_ content: ShareContent, template: ShareTemplate, scale: CGFloat) -> UIImage` — `transparent` e `strip` com fundo transparente.

- [ ] **Step 1: Testes que falham:** `disabledFieldsAreOmitted`; `activePaceOnlyWithPrescription`; `blocksTemplateHasBars`; `noRouteWhenToggledOff`; `rendererTransparentHasAlpha` (pixel do canto com alfa 0 em `transparent`, alfa 1 em `storiesDark`). A logo é estrutural: os 4 modelos são desenhados dentro de um `ShareFrame` que sempre inclui `Logo`, e nenhum modelo monta o próprio cabeçalho.
- [ ] **Step 2: Rodar** `swift test ... --filter WorkoutAnalysisTests` e `scripts/dev-run.sh --test` → FAIL.
- [ ] **Step 3: Implementar** o editor conforme o mockup aprovado (`compartilhar-editor`): seletor dos 4 modelos, prévia ao vivo, toggles, `ShareLink` com a imagem; última escolha em `@AppStorage`. Gerar o `AppIcon` 1024 px a partir do `AIIcon` (comando DEBUG ou teste que grava o PNG) e commitar o PNG.
- [ ] **Step 4: Rodar** → PASS; no simulador, gerar as 4 imagens do treino de 03/11 e salvar screenshots no report (não commitar imagens do treino real).
- [ ] **Step 5: Commit** — `feat(app): compartilha o treino como imagem com quatro modelos`

---

### Task 10: Textos com Foundation Models

**Files:**
- Create: target `Narrative` (depende de `WorkoutAnalysis`) em `Sources/Narrative/Narrator.swift`, `NarrativeTypes.swift`, `FoundationModelsNarrator.swift`, `TemplateNarrator.swift`, `NarrativeConstants.swift`; test target `NarrativeTests`
- Modify: `Package.swift`, `Sources/Sync/` (gerar e gravar `narrativeData` depois do `.FIT`), `App/Workouts/Detail/FindingsSection.swift`, `ComparisonSection.swift`; mover `FindingTemplates` para `TemplateNarrator`
- Test: `Tests/NarrativeTests/NarratorTests.swift`, `Tests/SyncTests/NarrativeSyncTests.swift`

**Interfaces:**
- Produces:
  - `struct WorkoutNarrative: Codable, Sendable, Equatable { findings: [String]; evolution: String?; generatedBy: String }` — `findings` na mesma ordem de `positives + negatives + attention`; `generatedBy` = `"foundation-models"` ou `"template"`.
  - `protocol Narrator: Sendable { func narrate(_ assessment: WorkoutAssessment, blocks: [WorkoutBlock], comparison: WorkoutComparison?) async -> WorkoutNarrative }`
  - `FoundationModelsNarrator` usa `LanguageModelSession` com saída `@Generable` (uma frase por finding, 1 frase de evolução, pt-BR, sem número que não esteja nos fatos); `TemplateNarrator` com as frases da Task 7.
  - `func makeNarrator() -> any Narrator` — Foundation Models quando `SystemLanguageModel.default.availability == .available`, senão template; qualquer erro na geração cai para o template.
- [ ] **Step 1: Testes que falham:** `templateCoversEveryKind`; `fallsBackOnError` (narrador fake que lança → resultado do template com `generatedBy == "template"`); `syncStoresNarrative` (após processar `.FIT`, `narrativeData` decodifica com o mesmo número de findings).
- [ ] **Step 2: Rodar** → FAIL.
- [ ] **Step 3: Implementar.** Prompt e schema `@Generable` ficam a critério do implementador, com instrução de usar só os fatos dados. A tela usa `narrativeData` quando existir e o template quando não.
- [ ] **Step 4: Rodar a suíte e** `scripts/dev-run.sh --test` → PASS; no simulador, conferir os textos de 2 treinos.
- [ ] **Step 5: Commit** — `feat(narrative): leitura do treino gerada no aparelho com fallback por template`
