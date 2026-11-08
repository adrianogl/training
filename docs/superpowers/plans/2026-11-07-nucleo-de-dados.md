# trAIning — Núcleo de dados — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pacote Swift `TrainingKit` com cliente da Personal API do Garmin, leitura de `.FIT`, métricas, projeções, persistência SwiftData e sync, todos testados com `swift test` no Mac.

**Architecture:** Um Swift Package local em `Packages/TrainingKit` com um target por módulo do design (`TrainingCore`, `GarminAPI`, `FITReader`, `Metrics`, `Projections`, `Storage`, `Sync`). Tudo puro e testável sem UI; o app (plano 2) só consome. Rede atrás de um protocolo de transporte para os testes usarem respostas gravadas sintéticas.

**Tech Stack:** Swift 6.4, Swift Testing, SwiftData, `garmin/fit-swift-sdk`, `weichsel/ZIPFoundation`.

**Spec:** `docs/superpowers/specs/2026-11-07-training-design.md`

Planos seguintes (fora deste): 2) App iOS (telas, Narrative/Foundation Models, ajustes, `BGAppRefreshTask`, exportar/importar provas na UI); 3) README e landing page no GitHub Pages.

## Global Constraints

- Plataformas do pacote: `.iOS(.v26)`, `.macOS(.v26)` (macOS só para rodar os testes no Mac).
- Base da API: `https://personal.connectapi.garmin.com`. Token: `POST /personalapitoken-service/personal-api/personal-api-key/token` com `Authorization: ApiKey <chave>`; resposta é o JWT em texto puro; renovar quando faltar < 3600 s para o `exp`.
- Download de `.FIT`: header `Accept: */*` (com `application/zip` o Garmin devolve 406).
- Limites por chamada: HRV e resumo diário 180 dias; sono e Body Battery 28 dias; stress e passos 7 dias; atividades 50 por página.
- Primeira carga a partir de `2024-01-01`; incremental rebusca os últimos 3 dias.
- Modelos SwiftData compatíveis com CloudKit: sem `@Attribute(.unique)`, todas as propriedades com valor padrão ou opcionais, relacionamentos opcionais. Dedup por chave natural no sync (`activityId`, `day`).
- O repositório é público: **nenhum dado real** (JSON da API, `.FIT`, chave) entra no git. Fixtures são sintéticas, escritas à mão ou geradas pelo encoder do FIT SDK nos testes.
- Sem comentários no código (regra do usuário), salvo workaround não óbvio. Tipos e constantes em arquivos próprios.
- Git: trabalhar na branch `feat/nucleo-de-dados`. Cada commit é mostrado ao usuário (`git status`, `git diff --staged`, mensagem) e só é feito com aprovação explícita. Conventional Commits em minúsculas, sem trailer de co-autoria nem menção a IA.
- Testes: `swift test --package-path Packages/TrainingKit`.

## Review Focus

- Resposta 204/corpo vazio da API (ex.: HRV de um período sem dados) → tratar como lista vazia, não erro. Teste em Task 3.
- Noite sem HRV e sem sono (relógio fora do pulso) → prontidão `nil`, não 0. Teste em Task 6.
- Corrida sem mensagem 140, ou com campo 7 = 0 → `PhysioMetrics.vo2max == nil`, nada quebra. Teste em Task 4.
- Mesmo dia/atividade buscado duas vezes (dois syncs seguidos, ou sync interrompido e retomado) → sem duplicata. Teste em Task 10.
- Série com poucos pontos (usuário novo, métrica rara como Força em subida) → projeção `nil` em vez de reta absurda. Teste em Task 8.

---

### Task 1: Pacote, `Day` e janelas de datas

**Files:**
- Create: `.gitignore`, `Packages/TrainingKit/Package.swift`
- Create: `Packages/TrainingKit/Sources/TrainingCore/Day.swift`, `DateWindows.swift`
- Test: `Packages/TrainingKit/Tests/TrainingCoreTests/DayTests.swift`

**Interfaces:**
- Produces: `struct Day: Hashable, Comparable, Codable, Sendable` com `init?(iso: String)`, `init(year: Int, month: Int, day: Int)`, `var iso: String`, `func adding(days: Int) -> Day`, `func days(until other: Day) -> Int`, `static func today(in: TimeZone = .current, now: Date = .now) -> Day`, `var weekStart: Day` (segunda-feira); `func windows(from: Day, to: Day, maxDays: Int) -> [ClosedRange<Day>]`.

- [ ] **Step 1: Criar branch e `.gitignore`**

`git checkout -b feat/nucleo-de-dados`. `.gitignore` cobre `.build/`, `DerivedData/`, `*.xcuserstate`, `.DS_Store`, `**/garmin-data/`, `*.fit`, `*.zip`.

- [ ] **Step 2: `Package.swift`**

Targets: `TrainingCore`; `GarminAPI` (→ Core); `FITReader` (→ Core, `FITSwiftSDK`, `ZIPFoundation`); `Metrics` (→ Core, FITReader); `Projections` (→ Core); `Storage` (→ Core); `Sync` (→ todos). Um test target por target. Dependências: `https://github.com/garmin/fit-swift-sdk.git` e `https://github.com/weichsel/ZIPFoundation.git`, ambas na última versão estável (`from:`).

- [ ] **Step 3: Testes que falham**

```swift
@Test func parsesAndFormatsIso() {
    #expect(Day(iso: "2026-11-07")?.iso == "2026-11-07")
    #expect(Day(iso: "2026-13-01") == nil)
}
@Test func arithmeticCrossesMonths() {
    #expect(Day(year: 2026, month: 10, day: 30).adding(days: 3).iso == "2026-11-02")
    #expect(Day(iso: "2026-01-01")!.days(until: Day(iso: "2026-11-07")!) == 310)
}
@Test func weekStartsOnMonday() {
    #expect(Day(iso: "2026-11-07")!.weekStart.iso == "2026-11-02")
}
@Test func windowsRespectLimit() {
    let w = windows(from: Day(iso: "2026-01-01")!, to: Day(iso: "2026-03-15")!, maxDays: 28)
    #expect(w.count == 3)
    #expect(w.first!.lowerBound.iso == "2026-01-01" && w.first!.upperBound.iso == "2026-01-28")
    #expect(w.last!.upperBound.iso == "2026-03-15")
}
```

- [ ] **Step 4: `swift test --package-path Packages/TrainingKit --filter TrainingCoreTests` → FAIL**
- [ ] **Step 5: Implementar `Day` (calendário gregoriano, sem fuso no valor) e `windows`**
- [ ] **Step 6: Rodar de novo → PASS**
- [ ] **Step 7: Commit (com aprovação)** — `chore: cria pacote TrainingKit e tipo Day`

---

### Task 2: Token e transporte

**Files:**
- Create: `Sources/GarminAPI/HTTPTransport.swift`, `TokenProvider.swift`, `GarminAPIError.swift`, `GarminEndpoints.swift`
- Test: `Tests/GarminAPITests/TokenProviderTests.swift`, `Tests/GarminAPITests/Support/StubTransport.swift`

**Interfaces:**
- Produces:
  - `protocol HTTPTransport: Sendable { func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) }` e `struct URLSessionTransport: HTTPTransport`.
  - `enum GarminAPIError: Error, Equatable { case invalidKey, unauthorized, badRequest(path: String), notAcceptable, rateLimited, server(status: Int), decoding(path: String) }`.
  - `actor TokenProvider { init(apiKey: String, baseURL: URL, transport: HTTPTransport, now: @escaping @Sendable () -> Date = { .now }); func bearer() async throws -> String; func invalidate() }`.
  - `enum GarminEndpoints` com as constantes de base, caminhos e limites da seção Global Constraints.

- [ ] **Step 1: Testes que falham** (StubTransport grava as requests e devolve respostas enfileiradas)

```swift
@Test func exchangesKeyAndCachesToken() async throws {
    let jwt = makeJWT(exp: 1_000_000 + 86_400)
    let stub = StubTransport([.ok(jwt)])
    let p = TokenProvider(apiKey: "k", baseURL: GarminEndpoints.base, transport: stub, now: { Date(timeIntervalSince1970: 1_000_000) })
    #expect(try await p.bearer() == jwt)
    #expect(try await p.bearer() == jwt)
    #expect(stub.requests.count == 1)
    #expect(stub.requests[0].httpMethod == "POST")
    #expect(stub.requests[0].value(forHTTPHeaderField: "Authorization") == "ApiKey k")
}
@Test func refreshesWhenLessThanOneHourLeft() async throws { /* exp = now + 3599 → segunda chamada faz novo POST */ }
@Test func tokenExchange401IsInvalidKey() async { /* status 401 → GarminAPIError.invalidKey */ }
```

`makeJWT(exp:)` é helper de teste que monta `header.payload.sig` com `{"exp":…}` em base64url.

- [ ] **Step 2: Rodar → FAIL**
- [ ] **Step 3: Implementar.** O `exp` sai do payload do JWT (base64url, sem verificar assinatura); JWT sem `exp` → `.invalidKey`.
- [ ] **Step 4: Rodar → PASS**
- [ ] **Step 5: Commit (com aprovação)** — `feat(garmin): troca a chave pessoal por token com cache`

---

### Task 3: `GarminClient` e DTOs

**Files:**
- Create: `Sources/GarminAPI/GarminClient.swift`, `GarminDataSource.swift`, `DTOs/*.swift` (um arquivo por DTO)
- Create: `Tests/GarminAPITests/Fixtures/*.json` (sintéticos, com a mesma forma das respostas reais descritas abaixo)
- Test: `Tests/GarminAPITests/GarminClientTests.swift`

**Interfaces:**
- Consumes: `TokenProvider`, `HTTPTransport`, `Day`, `windows(from:to:maxDays:)`.
- Produces: `protocol GarminDataSource: Sendable` com os métodos abaixo, e `struct GarminClient: GarminDataSource` (`init(tokens: TokenProvider, transport: HTTPTransport, baseURL: URL = GarminEndpoints.base, sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) })`).
  - `func heartRateZones() async throws -> HRZonesDTO` — `/biometric-service/heartRateZones/v2`, pega o item `sport == "DEFAULT"`: `zone1Floor…zone5Floor`, `maxHeartRateUsed`, `lactateThresholdHeartRateUsed`, `restingHeartRateUsed`.
  - `func dailySummaries(from: Day, to: Day) async throws -> [DailySummaryDTO]` — `/usersummary-service/v2/dailysummaries`, lê `data[]`: `calendarDate`, `heartRate.restingValue`, `stress.avgLevel`, `bodyBattery.{minValue,maxValue}`, `respiration.avgValue`, `intensityMinutes.{moderate,vigorous}`.
  - `func hrvSummaries(from:to:) -> [HRVSummaryDTO]` — `/hrv-service/hrv/daily/{ini}/{fim}`, lê `hrvSummaries[]`: `calendarDate`, `lastNightAvg`, `weeklyAvg`, `status`, `baseline.{lowUpper,balancedLow,balancedUpper}`.
  - `func sleepSummaries(from:to:) -> [SleepDTO]` — `/sleep-service/sleep/dailySleepSummariesByDate`: `calendarDate`, `sleepTimeSeconds`, `deep/light/rem/awakeSleepSeconds`, `sleepScores.overall.value`, `sleepEndTimestampLocal` (ms).
  - `func bodyBattery(from:to:) -> [BodyBatteryDayDTO]` — `/wellness-service/wellness/bodyBattery/reports/daily`: `date`, `bodyBatteryValuesArray` (`[[timestampMs, valor]]`).
  - `func activities(start: Int, limit: Int, from: Day?, to: Day?) -> [ActivityDTO]` — `/activitylist-service/activities/search/activities`: `activityId`, `activityName`, `activityType.typeKey`, `startTimeLocal`, `locationName`, `distance`, `duration`, `movingDuration`, `averageHR`, `maxHR`, `activityTrainingLoad`, `aerobicTrainingEffect`, `anaerobicTrainingEffect`, `trainingEffectLabel`, `averageRunningCadenceInStepsPerMinute`, `avgGroundContactTime`, `avgVerticalOscillation`, `avgVerticalRatio`, `avgStrideLength`, `avgPower`, `elevationGain`, `elevationLoss`, `hrTimeInZone_1…5`, `fastestSplit_1000`, `fastestSplit_5000`, `pr`.
  - `func fitArchive(activityId: Int64) async throws -> Data` — `/download-service/files/activity/{id}`, `Accept: */*`.
  - Métodos com intervalo dividem em janelas pelo limite do endpoint e concatenam.

- [ ] **Step 1: Testes que falham**

```swift
@Test func splitsHrvRangeIn180DayWindows() async throws {
    let (client, stub) = makeClient(responses: [.ok(fixture("hrv")), .ok(fixture("hrv"))])
    _ = try await client.hrvSummaries(from: Day(iso: "2026-01-01")!, to: Day(iso: "2026-08-01")!)
    #expect(stub.getPaths.filter { $0.hasPrefix("/hrv-service/hrv/daily/") }.count == 2)
}
@Test func emptyBodyMeansEmptyList() async throws {
    let (client, _) = makeClient(responses: [.status(204, "")])
    #expect(try await client.hrvSummaries(from: Day(iso: "2023-06-01")!, to: Day(iso: "2023-06-30")!).isEmpty)
}
@Test func decodesActivityFields() async throws {
    let (client, _) = makeClient(responses: [.ok(fixture("activities"))])
    let a = try await client.activities(start: 0, limit: 50, from: nil, to: nil).first!
    #expect(a.typeKey == "running" && a.activityTrainingLoad == 139.2 && a.hrTimeInZone == [70.2, 300, 900, 1000, 126])
}
@Test func fitDownloadSendsAcceptAny() async throws { /* header Accept == "*/*" */ }
@Test func retriesOn429ThenSucceeds() async throws { /* [429, 200] → sucesso, sleep chamado 1x */ }
@Test func gives400AsBadRequest() async { /* 400 → .badRequest(path:) */ }
@Test func unauthorizedInvalidatesTokenOnce() async { /* 401 no GET → invalida token, tenta 1x de novo, segundo 401 → .unauthorized */ }
```

- [ ] **Step 2: Rodar → FAIL**
- [ ] **Step 3: Implementar.** Retry em 429/5xx: até 3 tentativas, espera 1 s, 2 s, 4 s via `sleep` injetado. Datas como `Day.iso`.
- [ ] **Step 4: Rodar → PASS**
- [ ] **Step 5: Commit (com aprovação)** — `feat(garmin): cliente da personal api com janelas e retry`

---

### Task 4: `FITReader`

**Files:**
- Create: `Sources/FITReader/FITReader.swift`, `FITSummary.swift`, `PhysioMetrics.swift`, `RouteSimplifier.swift`
- Test: `Tests/FITReaderTests/FITReaderTests.swift`, `Tests/FITReaderTests/Support/FITFixtureBuilder.swift`

**Interfaces:**
- Produces:
  - `struct FITSample: Codable, Sendable, Equatable { var t: Double; var heartRate: Int?; var speed: Double?; var altitude: Double?; var distance: Double? }` (`t` em s desde o início; `speed` em m/s).
  - `struct Coordinate: Codable, Sendable, Equatable { var lat: Double; var lon: Double }`.
  - `struct PhysioMetrics: Codable, Sendable, Equatable { var vo2max: Double?; var recoveryMinutes: Int?; var performanceCondition: Int? }`.
  - `struct FITSummary: Sendable { var samples: [FITSample]; var route: [Coordinate]; var physio: PhysioMetrics? }`.
  - `enum FITReader { static func read(zip: Data) throws -> FITSummary; static func read(fit: Data) throws -> FITSummary }`.

- [ ] **Step 1: Testes que falham.** `FITFixtureBuilder` usa o `Encoder` do FIT SDK para gerar em memória um arquivo com `file_id`, 1200 `record` (1 Hz, FC/velocidade/altitude/distância/posição sintéticas) e, quando pedido, um `Mesg(name: "unknown", num: 140)` com os campos 7, 9 e 17.

```swift
@Test func readsVo2maxFromMessage140() throws {
    let s = try FITReader.read(fit: FITFixtureBuilder.run(seconds: 1200, msg140: [7: 1024809, 9: 3456, 17: -1]))
    #expect(abs(s.physio!.vo2max! - 54.73) < 0.01)
    #expect(s.physio!.recoveryMinutes == 3456 && s.physio!.performanceCondition == -1)
}
@Test func missingOrZeroVo2maxIsNil() throws {
    #expect(try FITReader.read(fit: FITFixtureBuilder.run(seconds: 600, msg140: nil)).physio?.vo2max == nil)
    #expect(try FITReader.read(fit: FITFixtureBuilder.run(seconds: 600, msg140: [7: 0])).physio?.vo2max == nil)
}
@Test func resamplesToFiveSeconds() throws {
    #expect(try FITReader.read(fit: FITFixtureBuilder.run(seconds: 1200, msg140: nil)).samples.count == 240)
}
@Test func routeIsCappedAt500Points() throws { /* 5000 records → route.count <= 500 */ }
@Test func readsFromZip() throws { /* zip em memória (ZIPFoundation) com o .fit → mesmo resultado */ }
```

- [ ] **Step 2: Rodar → FAIL**
- [ ] **Step 3: Implementar.** VO2max = `campo7 / 65536 × 3,5`; `nil` se ausente ou 0. Reamostragem: média por janela de 5 s. Rota: Douglas-Peucker com tolerância crescente até ≤ 500 pontos. Posições em semicírculos → graus (`× 180 / 2^31`).
- [ ] **Step 4: Rodar → PASS**
- [ ] **Step 5: Commit (com aprovação)** — `feat(fit): lê séries, rota e métricas da mensagem 140`

---

### Task 5: Carga — fitness, fadiga, forma, aguda:crônica e foco

**Files:**
- Create: `Sources/Metrics/Load.swift`, `LoadFocus.swift`
- Test: `Tests/MetricsTests/LoadTests.swift`

**Interfaces:**
- Produces:
  - `struct FFFPoint: Sendable, Equatable { var day: Day; var fitness: Double; var fatigue: Double; var form: Double }`
  - `func fitnessFatigueForm(dailyLoad: [Day: Double], from: Day, to: Day) -> [FFFPoint]`
  - `func acuteChronicRatio(dailyLoad: [Day: Double], on: Day) -> Double?`
  - `struct LoadFocus: Sendable, Equatable { var lowAerobic: Double; var highAerobic: Double; var anaerobic: Double }` (frações que somam 1) e `static let target = (low: 0.60...0.75, high: 0.20...0.35, anaerobic: 0.05...0.10)`
  - `func loadFocus(_ items: [(load: Double, zoneSeconds: [Double])]) -> LoadFocus?`

- [ ] **Step 1: Testes que falham**

```swift
@Test func ewmaWithConstantLoad() {
    let loads = Dictionary(uniqueKeysWithValues: (0..<100).map { (Day(iso: "2026-01-01")!.adding(days: $0), 100.0) })
    let p = fitnessFatigueForm(dailyLoad: loads, from: Day(iso: "2026-01-01")!, to: Day(iso: "2026-04-10")!)
    #expect(abs(p.first!.fitness - 100.0 / 42) < 1e-9 && abs(p.first!.fatigue - 100.0 / 7) < 1e-9)
    #expect(p.first!.form == 0)
    #expect(p.last!.fatigue > 99 && p.last!.fitness < p.last!.fatigue)
}
@Test func acuteChronic() {
    /* 7 dias com 100 e 21 dias anteriores com 50 → 700 / ((700 + 1050) / 4) = 1,6 */
}
@Test func acuteChronicNilWithoutHistory() { /* sem carga em 28 dias → nil */ }
@Test func focusSplitsLoadByZoneTime() {
    let f = loadFocus([(load: 100, zoneSeconds: [0, 600, 300, 100, 0])])!
    #expect(abs(f.lowAerobic - 0.6) < 1e-9 && abs(f.highAerobic - 0.4) < 1e-9 && f.anaerobic == 0)
}
```

- [ ] **Step 2: Rodar → FAIL**
- [ ] **Step 3: Implementar.** `fitness_t = fitness_{t-1} + (carga_t − fitness_{t-1}) / 42`; fadiga com 7; `form_t = fitness_{t-1} − fatigue_{t-1}`; dia sem carga = 0. A:C = soma 7 d ÷ (soma 28 d ÷ 4), terminando em `on`. Foco: Z1+Z2 → baixo, Z3+Z4 → alto, Z5 → anaeróbico, ponderado pela carga.
- [ ] **Step 4: Rodar → PASS**
- [ ] **Step 5: Commit (com aprovação)** — `feat(metrics): fitness, fadiga, forma e foco da carga`

---

### Task 6: Prontidão

**Files:**
- Create: `Sources/Metrics/Readiness.swift`
- Test: `Tests/MetricsTests/ReadinessTests.swift`

**Interfaces:**
- Produces:
  - `struct HRVBaseline: Codable, Sendable, Equatable { var lowUpper: Double; var balancedLow: Double; var balancedUpper: Double }`
  - `struct ReadinessInput: Sendable { var hrvLastNight: Double?; var hrvBaseline: HRVBaseline?; var sleepScore: Double?; var bodyBatteryMorningMax: Double?; var acuteChronic: Double? }`
  - `enum ReadinessVerdict: String, Sendable { case rest, moderate, hard }`
  - `struct Readiness: Sendable, Equatable { var score: Int; var partial: Bool; var verdict: ReadinessVerdict }`
  - `func readiness(_ input: ReadinessInput) -> Readiness?`
  - `func hrvComponent(_ value: Double, _ b: HRVBaseline) -> Double`, `func loadComponent(_ ratio: Double) -> Double`
  - `func bodyBatteryMorningMax(values: [(Date, Int)], sleepEnd: Date) -> Int?` (janela de 3 h após o fim do sono)

- [ ] **Step 1: Testes que falham** (faixa base no formato real do Garmin: `lowUpper` 38, `balancedLow` 41, `balancedUpper` 53)

```swift
let b = HRVBaseline(lowUpper: 38, balancedLow: 41, balancedUpper: 53)
@Test func hrvRamps() {
    #expect(hrvComponent(30, b) == 0)
    #expect(abs(hrvComponent(39.5, b) - 30) < 1e-9)
    #expect(hrvComponent(41, b) == 60)
    #expect(abs(hrvComponent(47, b) - 80) < 1e-9)
    #expect(hrvComponent(60, b) == 100)
}
@Test func loadRamps() {
    #expect(loadComponent(1.0) == 100 && loadComponent(0.5) == 0 && loadComponent(1.8) == 0)
    #expect(abs(loadComponent(1.55) - 50) < 1e-9)
}
@Test func fullScoreAndVerdict() {
    let r = readiness(.init(hrvLastNight: 47, hrvBaseline: b, sleepScore: 80, bodyBatteryMorningMax: 70, acuteChronic: 1.0))!
    #expect(r.score == 82 && r.verdict == .hard && !r.partial)
}
@Test func redistributesWhenBodyBatteryMissing() {
    let r = readiness(.init(hrvLastNight: 47, hrvBaseline: b, sleepScore: 80, bodyBatteryMorningMax: nil, acuteChronic: 1.0))!
    #expect(r.partial && r.score == 85)
}
@Test func noNightDataMeansNoScore() {
    #expect(readiness(.init(hrvLastNight: nil, hrvBaseline: b, sleepScore: nil, bodyBatteryMorningMax: 90, acuteChronic: 1.0)) == nil)
}
@Test func verdictThresholds() { /* 39 → .rest, 40 → .moderate, 69 → .moderate, 70 → .hard */ }
```

- [ ] **Step 2: Rodar → FAIL**
- [ ] **Step 3: Implementar.** Pesos 0,35 / 0,25 / 0,20 / 0,20; ausentes saem e os pesos restantes são normalizados; `score` arredondado. HRV: < `lowUpper` = 0; `lowUpper…balancedLow` = 0→60; `balancedLow…balancedUpper` = 60→100; acima = 100. Carga: 100 em 0,8…1,3, linear até 0 em 0,5 e 1,8.
- [ ] **Step 4: Rodar → PASS**
- [ ] **Step 5: Commit (com aprovação)** — `feat(metrics): score de prontidão`

---

### Task 7: Métricas de corrida e de prova

**Files:**
- Create: `Sources/Metrics/Vo2max.swift`, `Pace.swift`, `Durability.swift`, `HillStrength.swift`, `Minetti.swift`, `RacePrediction.swift`, `PaceStrategy.swift`, `RaceReadiness.swift`
- Test: `Tests/MetricsTests/RunMetricsTests.swift`, `RaceMetricsTests.swift`

**Interfaces:**
- Consumes: `FITSample`, `Day`.
- Produces:
  - `func smoothedVo2max(_ runs: [(Day, Double)]) -> [(Day, Double)]` — a cada corrida `v = v + (x − v) / 14`; primeira corrida inicia em `x`.
  - `func zone2Pace(_ s: [FITSample], zone2: ClosedRange<Int>) -> Double?` — s/km; descarta `t < 600`; exige ≥ 300 s em Z2.
  - `func thresholdPace(_ runs: [[FITSample]], lthr: Int) -> Double?` — trechos contínuos ≥ 300 s com |FC − lthr| ≤ 3; mediana do pace.
  - `func decoupling(_ s: [FITSample]) -> Double?` — exige duração ≥ 3600 s; descarta `t < 600`; metades por tempo; `(r1 − r2) / r1 × 100`, com `r = velocidade média / FC média`.
  - `func minettiCost(grade: Double) -> Double` — `155.4i⁵ − 30.4i⁴ − 43.3i³ + 46.3i² + 19.5i + 3.6`.
  - `func hillIndex(_ s: [FITSample]) -> Double?` — subidas ≥ 200 m com inclinação ≥ 4%; velocidade ajustada = `v × C(i) / C(0)`; plano = |i| ≤ 1% com FC dentro de ±5 bpm da FC média das subidas; índice = 100 × ajustada ÷ plano.
  - `enum EffortKind { case race, split5k, split1k }`, `struct Effort { var distance: Double; var seconds: Double; var day: Day; var kind: EffortKind }`
  - `func riegel(seconds: Double, from: Double, to: Double, exponent: Double = 1.06) -> Double`
  - `func predict(distance: Double, efforts: [Effort], on: Day) -> Double?` — só esforços dos últimos 90 dias; peso = `kind` (1,0 / 0,7 / 0,3) × (1 − idade/90); média ponderada das previsões de Riegel.
  - `enum GoalAssessment { case easy, challenging, aggressive }`, `func assessGoal(goalSeconds: Double, predictionSeconds: Double) -> GoalAssessment` — `p = (pred − goal) / pred`; > 0,06 agressiva; > 0,01 desafiadora.
  - `func longRunTarget(raceDistance: Double) -> Double` — ≤ 10 000 m: 100%; ≤ 21 100 m: 90%; acima: 75%.
  - `struct KmPlan: Codable, Sendable, Equatable { var index: Int; var pace: Double; var grade: Double; var label: String; var manual: Bool }`
  - `func paceStrategy(goalSeconds: Double, distance: Double, profile: [(distance: Double, altitude: Double)]?, manual: [Int: Double]) -> [KmPlan]`
  - `struct BlockWeek: Sendable, Equatable { var start: Day; var km: Double; var projected: Bool }`, `func raceBlock(raceDay: Day, today: Day, weeklyKm: [Day: Double]) -> [BlockWeek]` — 12 semanas até a da prova; futuras = média das 4 últimas semanas completas.

- [ ] **Step 1: Testes que falham** (séries sintéticas montadas nos testes)

```swift
@Test func vo2Smoothing() { #expect(smoothedVo2max([(d1, 56), (d2, 42)]).last!.1 == 55) }
@Test func riegelHalfFromTen() { #expect(abs(riegel(seconds: 2700, from: 10_000, to: 21_097.5) - 5958) < 2) }
@Test func predictionIgnoresOldEfforts() { /* esforço de 120 dias atrás → nil */ }
@Test func goalThresholds() {
    #expect(assessGoal(goalSeconds: 6300, predictionSeconds: 6510) == .challenging)
    #expect(assessGoal(goalSeconds: 6000, predictionSeconds: 6510) == .aggressive)
    #expect(assessGoal(goalSeconds: 6500, predictionSeconds: 6510) == .easy)
}
@Test func decouplingNeedsOneHour() { /* 3500 s → nil; 4000 s com FC subindo 10% e velocidade constante → ≈ 9 */ }
@Test func hillIndexNilWithoutClimbs() { /* percurso plano → nil */ }
@Test func flatStrategyHitsGoal() {
    let p = paceStrategy(goalSeconds: 6300, distance: 21_097.5, profile: nil, manual: [:])
    #expect(p.count == 22)
    #expect(abs(p.reduce(0) { $0 + $1.pace * kmLength($1.index, 21_097.5) } - 6300) < 1)
    #expect(p[0].pace - p[10].pace > 4.9 && p[0].label == "aquece" && p.last!.label == "final")
}
@Test func manualPaceIsKept() { /* manual [5: 300] → p[5].pace == 300 && p[5].manual; total continua 6300 */ }
@Test func blockProjectsFutureWeeks() { /* 6 semanas feitas, prova em 6 semanas → 6 projected == média das 4 últimas */ }
```

`kmLength(i, total)` é helper de teste: 1000 m, exceto o último km (resto).

- [ ] **Step 2: Rodar → FAIL**
- [ ] **Step 3: Implementar.** Estratégia: pace base = meta/distância; por km, inclinação média do perfil; pace = base × C(i)/C(0); +5 s nos km 1–2, −3 s nos 3 últimos; reescala os não manuais pra fechar a meta. Rótulos: km 1–2 "aquece", 3 últimos "final", senão "subida" (> +2%), "descida" (< −2%), "plano".
- [ ] **Step 4: Rodar → PASS**
- [ ] **Step 5: Commit (com aprovação)** — `feat(metrics): vo2max, pace, durabilidade, subida e métricas de prova`

---

### Task 8: Projeções

**Files:**
- Create: `Sources/Projections/Projection.swift`
- Test: `Tests/ProjectionsTests/ProjectionTests.swift`

**Interfaces:**
- Produces:
  - `struct ProjectionPoint: Sendable, Equatable { var day: Day; var mid: Double; var low: Double; var high: Double }`
  - `struct Projection: Sendable { var points: [ProjectionPoint]; var targetCrossing: Day? }`
  - `func project(_ series: [(Day, Double)], today: Day, horizonDays: Int, softCeiling: Double? = nil, target: Double? = nil) -> Projection?`

- [ ] **Step 1: Testes que falham**

```swift
@Test func linearSeriesProjectsLine() {
    let s = (0..<90).map { (today.adding(days: -89 + $0), 40.0 + Double($0) * 0.1) }
    let p = project(s, today: today, horizonDays: 30)!
    #expect(abs(p.points.last!.mid - 51.9) < 0.01)
    #expect(p.points.last!.high - p.points.last!.low < 0.01)
}
@Test func bandWidensWithHorizon() { /* série com ruído → largura em h=60 > largura em h=1 */ }
@Test func tooFewPointsReturnsNil() { /* 9 pontos → nil */ }
@Test func findsTargetCrossing() { /* tempo caindo 2 s/dia até 6510 hoje, meta 6300, horizonDays 120 → crossing = today + 105 */ }
@Test func softCeilingSlowsGrowth() { /* com softCeiling 52, mid final < sem teto, e incrementos acima de 52 pela metade */ }
```

- [ ] **Step 2: Rodar → FAIL**
- [ ] **Step 3: Implementar.** Mínimos quadrados sobre os pontos dos últimos 90 dias (exige ≥ 10); faixa = ±1,96 × σ dos resíduos × √(1 + h/n); acima de `softCeiling`, cada incremento conta pela metade; cruzamento = primeiro dia em que `mid` atinge `target` na direção da tendência.
- [ ] **Step 4: Rodar → PASS**
- [ ] **Step 5: Commit (com aprovação)** — `feat(projections): regressão com faixa de incerteza`

---

### Task 9: Modelos SwiftData

**Files:**
- Create: `Sources/Storage/DailyRecord.swift`, `ActivityRecord.swift`, `RaceRecord.swift`, `SyncState.swift`, `TrainingSchema.swift`
- Test: `Tests/StorageTests/StorageTests.swift`

**Interfaces:**
- Produces (todos `@Model`, propriedades com valor padrão):
  - `DailyRecord`: `day: String` (ISO), `restingHR: Int?`, `stressAvg: Int?`, `bodyBatteryMorningMax: Int?`, `bodyBatteryMin: Int?`, `bodyBatteryMax: Int?`, `respirationAvg: Double?`, `hrvLastNight: Double?`, `hrvWeekly: Double?`, `hrvStatus: String?`, `hrvLowUpper/balancedLow/balancedUpper: Double?`, `sleepSeconds/deep/light/rem/awake: Int?`, `sleepScore: Int?`, `readinessScore: Int?`, `readinessPartial: Bool`, `updatedAt: Date`.
  - `ActivityRecord`: `activityId: Int64`, `typeKey: String`, `name: String`, `start: Date`, `locationName: String?`, os campos do `ActivityDTO`, `zoneSeconds: [Double]`, `vo2max: Double?`, `recoveryMinutes: Int?`, `performanceCondition: Int?`, `samplesData: Data?` (JSON de `[FITSample]`), `routeData: Data?`, `fitProcessed: Bool`, `updatedAt: Date`.
  - `RaceRecord`: `id: UUID`, `name`, `day: String`, `startTime: String?`, `distance: Double`, `goalSeconds: Double?`, `priority: String` ("A"/"B"/"C"), `city: String?`, `gpxData: Data?`, `manualPacesData: Data?` (JSON `[Int: Double]`), `customLabelsData: Data?`, `resultActivityId: Int64?`, `updatedAt: Date`.
  - `SyncState`: `firstLoadCompleted: Bool`, `lastSync: Date?`, `lastActivityStart: Date?`.
  - `enum TrainingSchema { static let models: [any PersistentModel.Type]; static func container(inMemory: Bool) throws -> ModelContainer }`.

- [ ] **Step 1: Teste que falha** — cria container em memória, insere um de cada, busca de volta; e confere que nenhum modelo usa `.unique` (teste lê `Schema(TrainingSchema.models)` e verifica `attributes` sem a opção `.unique`).
- [ ] **Step 2: Rodar → FAIL**
- [ ] **Step 3: Implementar**
- [ ] **Step 4: Rodar → PASS**
- [ ] **Step 5: Commit (com aprovação)** — `feat(storage): modelos swiftdata compatíveis com cloudkit`

---

### Task 10: `SyncEngine`

**Files:**
- Create: `Sources/Sync/SyncEngine.swift`, `SyncReport.swift`, `Upsert.swift`, `DerivedMetrics.swift`
- Test: `Tests/SyncTests/SyncEngineTests.swift`, `Tests/SyncTests/Support/FakeDataSource.swift`

**Interfaces:**
- Consumes: `GarminDataSource`, `FITReader.read(zip:)`, métricas das Tasks 5–7, modelos da Task 9.
- Produces:
  - `struct SyncReport: Sendable { var dailyUpserted: Int; var activitiesUpserted: Int; var fitProcessed: Int; var duplicatesRemoved: Int }`
  - `actor SyncEngine { init(source: GarminDataSource, container: ModelContainer, today: @escaping @Sendable () -> Day, firstDay: Day = Day(iso: "2024-01-01")!); func run(progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> SyncReport }`

- [ ] **Step 1: Testes que falham** (`FakeDataSource` devolve dados sintéticos por dia/atividade e conta chamadas)

```swift
@Test func firstLoadStartsAt2024() async throws { /* primeira chamada de hrvSummaries começa em 2024-01-01 */ }
@Test func incrementalRefetchesLastThreeDays() async throws { /* 2º run: menor `from` == today − 3 */ }
@Test func runningTwiceCreatesNoDuplicates() async throws {
    let (engine, container) = makeEngine()
    _ = try await engine.run(); _ = try await engine.run()
    #expect(try count(DailyRecord.self, in: container) == fake.dayCount)
    #expect(try count(ActivityRecord.self, in: container) == fake.activityCount)
}
@Test func removesPreexistingDuplicates() async throws { /* insere 2 DailyRecord do mesmo dia antes → report.duplicatesRemoved == 1 */ }
@Test func processesFitOnlyForNewRuns() async throws { /* fitArchive chamado só para corridas com fitProcessed == false */ }
@Test func fitFailureDoesNotAbortSync() async throws { /* fitArchive lança erro → atividade salva com fitProcessed == false, run termina */ }
@Test func storesReadiness() async throws { /* dia com HRV, sono e BB → readinessScore preenchido */ }
@Test func invalidKeyPropagates() async { /* fonte lança .invalidKey → run lança .invalidKey */ }
```

- [ ] **Step 2: Rodar → FAIL**
- [ ] **Step 3: Implementar.** Ordem: limpar duplicatas (mantém o `updatedAt` mais recente) → zonas de FC → dados diários (janelas por endpoint, mescla por `day`) → atividades (página de 50 até acabar, ou até passar de `lastActivityStart − 3 dias`) → `.FIT` das corridas novas (uma por vez; erro marca e segue) → derivados (prontidão por dia). Upsert: busca por chave natural via `#Predicate`, atualiza ou insere. Salva o contexto a cada janela pra a carga ser retomável.
- [ ] **Step 4: Rodar → PASS**
- [ ] **Step 5: Commit (com aprovação)** — `feat(sync): sync incremental com upsert e processamento de fit`

---

### Task 11: Exportar e importar provas

**Files:**
- Create: `Sources/Storage/RaceTransfer.swift`
- Test: `Tests/StorageTests/RaceTransferTests.swift`

**Interfaces:**
- Produces: `enum RaceTransfer { static func export(_ races: [RaceRecord]) throws -> Data; static func importRaces(_ data: Data, into: ModelContext) throws -> (inserted: Int, updated: Int, skipped: Int) }`. Formato: JSON `{ "version": 1, "races": [...] }` com todos os campos do `RaceRecord` (`Data` em base64).

- [ ] **Step 1: Testes que falham**

```swift
@Test func roundTrip() throws { /* exporta 2 provas, importa num container vazio → inserted == 2, campos iguais */ }
@Test func newerEditWins() throws { /* mesma id: arquivo com updatedAt mais novo → updated == 1; mais velho → skipped == 1 */ }
@Test func rejectsUnknownVersion() throws { /* version 2 → lança erro */ }
```

- [ ] **Step 2: Rodar → FAIL**
- [ ] **Step 3: Implementar**
- [ ] **Step 4: Rodar → PASS**
- [ ] **Step 5: Commit (com aprovação)** — `feat(storage): exporta e importa provas entre aparelhos`

---

### Task 12: Verificação ponta a ponta com a conta real (local, sem commit de dados)

**Files:**
- Create: `Packages/TrainingKit/Sources/trainingctl/main.swift` (executável de linha de comando, só desenvolvimento)

**Interfaces:**
- Consumes: `GarminClient`, `SyncEngine`, `TrainingSchema`.
- Produces: `swift run --package-path Packages/TrainingKit trainingctl sync --store <caminho>` e `trainingctl report --store <caminho>`; lê a chave de `~/.config/garmin/connect-personal-api-key`.

- [ ] **Step 1: Implementar o executável.** `report` imprime: total de dias e atividades, prontidão de hoje, VO2max suavizado atual, fitness/fadiga/forma de hoje, A:C, previsões 5/10/21/42, durabilidade e força em subida mais recentes.
- [ ] **Step 2: Rodar a primeira carga** com `--store ~/Code/pessoal/training/garmin-data/store.sqlite` (pasta coberta pelo `.gitignore`). Esperado: termina sem 400/429 não tratado.
- [ ] **Step 3: Rodar `sync` de novo e conferir** que totais de dias e atividades não mudaram (sem duplicatas).
- [ ] **Step 4: Comparar com o Garmin Connect** (via MCP do Garmin no Claude Code): VO2max suavizado a ±1,5 do Garmin; previsões dentro de ±3% do race predictor; anotar divergências maiores pra calibrar.
- [ ] **Step 5: `git status`** confirma que nada de `garmin-data/` está rastreado.
- [ ] **Step 6: Commit (com aprovação)** — `chore: cli de desenvolvimento para sync e relatório`
