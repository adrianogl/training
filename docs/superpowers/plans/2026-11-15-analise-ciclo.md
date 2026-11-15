# Análise de fim de ciclo — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** No fim do ciclo, ou quando o atleta encerra antes, o Treinador mostra uma análise do ciclo e sugere aumentar, manter ou diminuir o volume do próximo.

**Architecture:** A análise e a regra ficam em `Insights` (`TrainerEngine.cycleReview`), em cima do `scoreboard` que já existe. O app só lê o resultado: `TrainerModel` expõe a análise, guarda o encerramento (`TrainerPlan.endedOn`) e o resumo dos ciclos anteriores, e as views seguem o mockup.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, xcodegen.

**Spec:** `docs/superpowers/specs/2026-11-15-analise-ciclo-design.md`

**Mockup:** https://claude.ai/artifact/TkHret3fdnq5MaeZ5s3vo2

## Global Constraints

- Sem comentários no código.
- Types em arquivo `*Types.swift` e constantes em `*Constants.swift` ao lado da feature, nunca dentro da view ou do engine.
- Texto da interface em PT-BR, em arquivo `*Text.swift`.
- Plano antigo sem `endedOn` precisa decodificar (app e site).
- Componentes visuais: `brandCard()`, `SectionHeader`, `BrandFonts.number(18)`, `TrainerPrimaryButtonStyle`, `TrainerSecondaryButtonStyle`, banner no formato de `updatedBanner`.
- Projeto Xcode é gerado: rodar `xcodegen generate` antes de `xcodebuild` quando criar arquivo.

## Review Focus

- Prova no dia de hoje, antes de o atleta correr: o ciclo ainda não terminou. Termina no dia seguinte à data da prova ou assim que houver corrida no dia da prova.
- Encerrar na primeira semana: nenhuma semana concluída. A análise existe, com 0 semanas e veredito "Manter" pelo motivo de ciclo curto, e não quebra a tela.
- Plano sem data com mais de 24 semanas: a análise é do bloco de 12 semanas mais recente que já fechou, não do primeiro.
- Atleta sem prontidão nenhuma (sem Garmin): o critério de prontidão é ignorado e a seção mostra "sem dados".
- Encerrar e depois criar plano novo: o resumo vai para "Ciclos anteriores" uma vez só, mesmo que o atleta abra o formulário e cancele.

---

### Task 1: Tipos do ciclo e `endedOn` no plano

**Files:**
- Create: `Packages/TrainingKit/Sources/Insights/TrainerCycleTypes.swift`
- Modify: `Packages/TrainingKit/Sources/Insights/TrainerTypes.swift` (struct `TrainerPlan`, `init(from:)`, `CodingKeys`, init público)
- Modify: `server/web/src/types.ts` (campo opcional `endedOn?: string` no tipo do plano)
- Test: `Packages/TrainingKit/Tests/InsightsTests/TrainerCycleTests.swift`

**Interfaces:**
- Produces:
  - `TrainerPlan.endedOn: Day?` (default `nil` no init público)
  - `public enum TrainerCycleVerdict: String, Codable, Sendable { case increase, keep, decrease }`
  - `public struct TrainerCycleWeek: Sendable, Equatable { index: Int; start: Day; doneMeters: Double; plannedMeters: Double }`
  - `public struct TrainerCycleCount: Sendable, Equatable { done: Int; total: Int }`
  - `public struct TrainerCycleChange: Sendable, Equatable { meters: Double; first: Double; last: Double }` (previsão em segundos)
  - `public struct TrainerCycleReview: Sendable, Equatable` com: `first: Day`, `last: Day`, `endedEarly: Bool`, `weeks: [TrainerCycleWeek]`, `long: TrainerCycleCount`, `threshold: TrainerCycleCount`, `vo2: TrainerCycleCount`, `mediumLong: TrainerCycleCount`, `longestLongMeters: Double?`, `longestLongPlannedMeters: Double?`, `readinessFirst: Double?`, `readinessLast: Double?`, `lowReadinessDays: Int`, `extraLightWeeks: [Day]`, `longsMissed: Int`, `predictions: [TrainerCycleChange]`, `raceSeconds: Double?`, `goalSeconds: Double?`, `verdict: TrainerCycleVerdict`, `reasons: [TrainerCycleReason]`, `currentStartMeters: Double`, `currentPeakMeters: Double`, `suggestedStartMeters: Double`, `suggestedPeakMeters: Double`; e os derivados `doneMeters`, `plannedMeters`, `doneShare` (0 quando `plannedMeters == 0`).
  - `public enum TrainerCycleReason: Sendable, Equatable { case volume(share: Double, weeksBelow: Int), readiness(first: Double, last: Double), lightWeeks(Int), prediction(TrainerCycleChange), race(seconds: Double, goal: Double), tooShort(weeks: Int), noProgress }`

- [ ] **Step 1: Write the failing test**

```swift
@Test func oldPlanJsonDecodesWithoutEndedOn() throws {
    var plan = makePlan()
    plan.endedOn = nil
    let data = try JSONEncoder().encode(plan)
    let decoded = try JSONDecoder().decode(TrainerPlan.self, from: data)
    #expect(decoded.endedOn == nil)
}

@Test func endedOnRoundTrips() throws {
    var plan = makePlan()
    plan.endedOn = Day(year: 2026, month: 11, day: 12)
    let decoded = try JSONDecoder().decode(TrainerPlan.self, from: JSONEncoder().encode(plan))
    #expect(decoded.endedOn == Day(year: 2026, month: 11, day: 12))
}
```

`makePlan()` é um helper privado da suite que chama `TrainerEngine.create` com o mesmo histórico e meta de `TrainerRotationTests` (meia em 12 semanas e 5 dias, pico 80 km).

- [ ] **Step 2: Run** `swift test --filter TrainerCycleTests` em `Packages/TrainingKit`. Expected: FAIL, `endedOn` não existe.
- [ ] **Step 3: Implement** o campo com `decodeIfPresent`, os tipos em `TrainerCycleTypes.swift` e `endedOn?: string` em `types.ts`.
- [ ] **Step 4: Run** `swift test --filter TrainerCycleTests`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(treinador): guarda o encerramento do ciclo no plano`

### Task 2: Janela do ciclo e métricas

**Files:**
- Create: `Packages/TrainingKit/Sources/Insights/TrainerEngineCycle.swift`
- Create: `Packages/TrainingKit/Sources/Insights/TrainerEngineCycleConstants.swift`
- Test: `Packages/TrainingKit/Tests/InsightsTests/TrainerCycleTests.swift`

**Interfaces:**
- Consumes: tipos da Task 1; `TrainerEngine.scoreboard(plan:history:week:)`; `TrainerEngine.status(of:history:today:)`; `TrainerEngine.volumes(of:history:today:)`.
- Produces: `public static func cycleReview(plan: TrainerPlan, history: TrainerHistory, today: Day) -> TrainerCycleReview?`

Constantes: `cycleOpenWeeks = 12` (usar `openHorizonWeeks`), `cycleReadinessWeeks = 4`, `cycleLowReadiness = 60`, `cycleMinimumWeeks = 4`, `cyclePredictionMeters: [Double] = [10_000]` mais a distância da meta quando houver.

Regras da janela:
- `endedOn` preenchido: ciclo de `weeks.first.start` até o domingo da última semana que terminou antes de `endedOn`; `endedEarly = true`.
- Com `target.date`: termina quando `today > date` ou há corrida no dia da prova com `today == date`. Semanas: todas.
- Sem data: blocos de 12 semanas a partir de `weeks.first.start`. Analisa o bloco mais recente cujo fim (`start + 12 semanas - 1 dia`) é anterior a `today`. Nenhum bloco fechado → `nil`.
- Fora disso → `nil`.

Métricas: `weeks` vêm de `scoreboard` de cada semana da janela. Treinos-chave contam `TrainerWorkout` por `kind` (`.long`, `.threshold`, `.vo2max`) e `variant == .mediumLong`, com `done` = `status(...).status == .done`. Prontidão: média de `history.readiness` nas 4 primeiras e nas 4 últimas semanas da janela (`nil` sem pontos). `extraLightWeeks` = `plan.lightWeeks` dentro da janela. `longsMissed` = longões com `longClosed == false`. Previsões: primeiro e último ponto de `history.predictionSeries` dentro da janela, por distância. `raceSeconds`: corrida `kind == .race` no dia da prova, senão a maior corrida do dia. `currentStartMeters`/`currentPeakMeters` de `volumes(of:history:today:)`.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func datedPlanHasNoReviewBeforeRaceDay() {
    let plan = makePlan()
    #expect(TrainerEngine.cycleReview(plan: plan, history: history(), today: raceDay.adding(days: -1)) == nil)
}

@Test func datedPlanReviewsEveryWeekAfterTheRace() throws {
    let plan = makePlan()
    let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(done: 1.0), today: raceDay.adding(days: 1)))
    #expect(review.weeks.count == plan.weeks.count)
    #expect(review.endedEarly == false)
    #expect(review.first == plan.weeks.first?.start)
}

@Test func raceRunOnRaceDayClosesTheCycleThatDay() throws {
    let plan = makePlan()
    let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(done: 1.0, raceSeconds: 5_628), today: raceDay))
    #expect(review.raceSeconds == 5_628)
    #expect(review.goalSeconds == 5_700)
}

@Test func endingEarlyKeepsOnlyFinishedWeeks() throws {
    var plan = makePlan()
    plan.endedOn = monday.adding(days: 7 * 5 + 2)
    let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(done: 1.0), today: plan.endedOn!))
    #expect(review.weeks.map(\.index) == Array(plan.weeks.prefix(5).map(\.index)))
    #expect(review.endedEarly)
}

@Test func endingInTheFirstWeekGivesAnEmptyReview() throws {
    var plan = makePlan()
    plan.endedOn = monday.adding(days: 2)
    let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(), today: plan.endedOn!))
    #expect(review.weeks.isEmpty)
    #expect(review.doneShare == 0)
}

@Test func openPlanReviewsTheLatestClosedTwelveWeekBlock() throws {
    let plan = makeOpenPlan(weeks: 26)
    let today = monday.adding(days: 7 * 25)
    let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(done: 1.0), today: today))
    #expect(review.first == monday.adding(days: 7 * 12))
    #expect(review.weeks.count == 12)
}

@Test func openPlanHasNoReviewBeforeTwelveWeeks() {
    let plan = makeOpenPlan(weeks: 12)
    #expect(TrainerEngine.cycleReview(plan: plan, history: history(), today: monday.adding(days: 7 * 11 + 3)) == nil)
}

@Test func missingReadinessLeavesAveragesEmpty() throws {
    let plan = makePlan()
    let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(done: 1.0, readiness: false), today: raceDay.adding(days: 1)))
    #expect(review.readinessFirst == nil && review.readinessLast == nil && review.lowReadinessDays == 0)
}
```

Helpers da suite: `history(done: Double = 0, readiness: Bool = true, readinessDrop: Int = 0, raceSeconds: Double? = nil)` gera corridas que cumprem `done` × o volume de cada treino planejado do plano, prontidão diária de 72 caindo `readinessDrop` pontos ao longo do ciclo, e previsão de 10 km melhorando 1 s por semana. `makeOpenPlan(weeks:)` cria plano com meta `.text` sem data e estende até `weeks` semanas com `TrainerEngine.adjust` em `.weekEnded`.

- [ ] **Step 2: Run** `swift test --filter TrainerCycleTests`. Expected: FAIL, `cycleReview` não existe.
- [ ] **Step 3: Implement** `cycleReview` com veredito provisório `.keep` e volumes sugeridos iguais aos atuais (a Task 3 troca isso).
- [ ] **Step 4: Run** `swift test --filter TrainerCycleTests`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(treinador): analisa o volume, os treinos e a prontidão do ciclo`

### Task 3: Veredito e volume sugerido

**Files:**
- Modify: `Packages/TrainingKit/Sources/Insights/TrainerEngineCycle.swift`
- Modify: `Packages/TrainingKit/Sources/Insights/TrainerEngineCycleConstants.swift`
- Test: `Packages/TrainingKit/Tests/InsightsTests/TrainerCycleVerdictTests.swift`

**Interfaces:**
- Produces: `static func cycleVerdict(_ review: TrainerCycleReview) -> (verdict: TrainerCycleVerdict, reasons: [TrainerCycleReason])` e o preenchimento de `suggestedStartMeters`/`suggestedPeakMeters` em `cycleReview`.

Constantes: `cycleIncreaseShare = 0.9`, `cycleDecreaseShare = 0.75`, `cycleReadinessTolerance = 3.0`, `cycleReadinessDrop = 8.0`, `cycleIncreaseFactor = 1.08`, `cycleDecreaseFactor = 0.9`, `cycleWeekBelowShare = 0.8`.

Regra, nesta ordem:
1. Menos de 4 semanas → `.keep`, motivo `.tooShort(weeks:)`.
2. `doneShare < 0.75`, ou queda de prontidão ≥ 8, ou `extraLightWeeks.count >= 2` → `.decrease`.
3. `doneShare >= 0.9`, queda ≤ 3 (ou sem prontidão), previsão melhorou (ou sem previsão) e `extraLightWeeks.count <= 1` → `.increase`.
4. O resto → `.keep`; motivo `.noProgress` quando cumpriu ≥ 90% e a previsão não melhorou.

Motivos: sempre `.volume`; `.readiness` quando há prontidão; `.lightWeeks` quando > 0; `.race` quando há prova, senão `.prediction` quando há previsão. No máximo 3, nessa ordem.

Volumes sugeridos: `floorKilometers(current × fator)`; `.keep` repete os atuais.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func fullVolumeStableReadinessAndBetterFormIncrease() throws {
    let review = try #require(TrainerEngine.cycleReview(plan: makePlan(), history: history(done: 0.97), today: raceDay.adding(days: 1)))
    #expect(review.verdict == .increase)
    #expect(review.suggestedPeakMeters == 86_000)
    #expect(review.suggestedStartMeters == 64_000)
}

@Test func partialVolumeKeeps() throws {
    let review = try #require(TrainerEngine.cycleReview(plan: makePlan(), history: history(done: 0.85), today: raceDay.adding(days: 1)))
    #expect(review.verdict == .keep)
    #expect(review.suggestedPeakMeters == review.currentPeakMeters)
}

@Test func lowVolumeDecreases() throws {
    let review = try #require(TrainerEngine.cycleReview(plan: makePlan(), history: history(done: 0.7), today: raceDay.adding(days: 1)))
    #expect(review.verdict == .decrease)
    #expect(review.suggestedPeakMeters == 72_000)
    #expect(review.suggestedStartMeters == 54_000)
}

@Test func readinessDropDecreasesEvenWithFullVolume() throws {
    let review = try #require(TrainerEngine.cycleReview(plan: makePlan(), history: history(done: 1.0, readinessDrop: 10), today: raceDay.adding(days: 1)))
    #expect(review.verdict == .decrease)
    #expect(review.reasons.contains { if case .readiness = $0 { true } else { false } })
}

@Test func twoExtraLightWeeksDecrease() throws {
    var plan = makePlan()
    plan.lightWeeks = [plan.weeks[2].start, plan.weeks[6].start]
    let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(done: 1.0), today: raceDay.adding(days: 1)))
    #expect(review.verdict == .decrease)
}

@Test func shortCycleKeepsWithTooShortReason() throws {
    var plan = makePlan()
    plan.endedOn = monday.adding(days: 7 * 3 + 1)
    let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(done: 1.0), today: plan.endedOn!))
    #expect(review.verdict == .keep)
    #expect(review.reasons.first == .tooShort(weeks: 3))
}

@Test func noReadinessDataStillIncreases() throws {
    let review = try #require(TrainerEngine.cycleReview(plan: makePlan(), history: history(done: 0.97, readiness: false), today: raceDay.adding(days: 1)))
    #expect(review.verdict == .increase)
}
```

Os helpers ficam num arquivo compartilhado `Packages/TrainingKit/Tests/InsightsTests/TrainerCycleFixtures.swift`, usado pelas duas suites.

- [ ] **Step 2: Run** `swift test --filter TrainerCycleVerdictTests`. Expected: FAIL.
- [ ] **Step 3: Implement** `cycleVerdict` e os volumes sugeridos.
- [ ] **Step 4: Run** `swift test` (pacote inteiro). Expected: tudo PASS.
- [ ] **Step 5: Commit** `feat(treinador): sugere aumentar, manter ou diminuir o volume no fim do ciclo`

### Task 4: Model, encerramento e ciclos anteriores

**Files:**
- Create: `App/Trainer/TrainerCycleTypes.swift` (`TrainerCycleSummary: Codable, Equatable, Identifiable` com `id: String` = ISO de `last`, `title`, `first: Day`, `last: Day`, `verdict: TrainerCycleVerdict`, `beforePeakMeters`, `afterPeakMeters`, `resultSeconds: Double?`)
- Modify: `App/Trainer/TrainerStore.swift` (`cycleSummaries() -> [TrainerCycleSummary]`, `archive(_ summary: TrainerCycleSummary)` que ignora `id` repetido, `seenCycleEnd: Day?`, `markCycleSeen(_ day: Day)`; chaves em `TrainerConstants`; `delete()` não apaga o histórico de ciclos)
- Modify: `App/Trainer/TrainerModel.swift`
- Modify: `App/Trainer/TrainerConstants.swift`
- Test: `AppTests/TrainerCycleModelTests.swift`, `AppTests/TrainerStoreTests.swift`

**Interfaces:**
- Consumes: `TrainerEngine.cycleReview`, `TrainerPlan.endedOn`.
- Produces em `TrainerModel`:
  - `var cycleReview: TrainerCycleReview?`
  - `var showsCycleBanner: Bool` (há análise e `review.last > seenCycleEnd`, ou o plano tem data e já terminou)
  - `var cycleEnded: Bool` (plano com data passada ou `endedOn != nil`)
  - `func endCycle() async` (grava `endedOn = currentDay` e persiste)
  - `func markCycleSeen()`
  - `var cycleSummaries: [TrainerCycleSummary]`
  - `func suggestedVolumes() -> (start: Int, peak: Int)?` (km, da análise)
  - `createPlan(...)` passa a arquivar o resumo do ciclo atual antes de substituir o plano, quando `cycleReview != nil`

- [ ] **Step 1: Write the failing tests**

```swift
@Test func endCycleStoresTheDayAndExposesAReview() async throws {
    let model = makeModel(today: mondayPlusWeeks(6))
    await model.createPlan(target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: [], startMeters: 60_000, peakMeters: 80_000)
    await model.endCycle()
    #expect(model.plan?.endedOn == mondayPlusWeeks(6))
    #expect(model.cycleEnded)
    #expect(model.cycleReview?.endedEarly == true)
}

@Test func creatingTheNextPlanArchivesTheCycleOnce() async throws {
    let model = makeModel(today: mondayPlusWeeks(6))
    await model.createPlan(target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: [], startMeters: 60_000, peakMeters: 80_000)
    await model.endCycle()
    await model.createPlan(target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: [], startMeters: 64_000, peakMeters: 86_000)
    #expect(model.cycleSummaries.count == 1)
    #expect(model.plan?.endedOn == nil)
}

@Test func storeIgnoresARepeatedSummary() {
    let store = makeStore()
    store.archive(summary)
    store.archive(summary)
    #expect(store.cycleSummaries().count == 1)
}

@Test func seenCycleHidesTheBanner() async {
    let model = makeModel(today: mondayPlusWeeks(6))
    await model.createPlan(target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: [], startMeters: 60_000, peakMeters: 80_000)
    await model.endCycle()
    #expect(model.showsCycleBanner)
    model.markCycleSeen()
    #expect(!model.showsCycleBanner)
}
```

`makeModel` e `makeStore` seguem o padrão de `TrainerSyncTests`/`TrainerStoreTests` (container em memória, `UserDefaults(suiteName:)` próprio, URL temporária).

- [ ] **Step 2: Run** `xcodegen generate && xcodebuild test -project trAIning.xcodeproj -scheme trAIning -destination 'id=<simulador>' -only-testing:AppTests/TrainerCycleModelTests -only-testing:AppTests/TrainerStoreTests`. Expected: FAIL.
- [ ] **Step 3: Implement** as propriedades e métodos acima.
- [ ] **Step 4: Run** o mesmo comando. Expected: PASS.
- [ ] **Step 5: Commit** `feat(treinador): encerra o ciclo e guarda o resumo dos ciclos anteriores`

### Task 5: Textos da análise

**Files:**
- Create: `App/Trainer/TrainerCycleText.swift`
- Test: `AppTests/TrainerCycleTextTests.swift`

**Interfaces:**
- Consumes: `TrainerCycleReview`, `TrainerCycleReason`, `TrainerCycleSummary`.
- Produces (enum `TrainerCycleText`): `bannerTitle = "Ciclo concluído."`, `banner(_ review:, dated: Bool) -> String`, `resultTitle = "Resultado do ciclo"`, `verdictTitle(_:) -> String` ("Aumentar o volume" / "Manter o volume" / "Diminuir o volume"), `suggestionLine(_ review:, dated: Bool) -> String`, `volumes(_ review:, dated: Bool) -> String`, `reason(_ reason: TrainerCycleReason) -> String`, `endMenu = "Encerrar ciclo agora"`, `endTitle`, `endMessage(weeks: Int) -> String`, `endConfirm = "Encerrar"`, `createWithSuggestion = "Criar próximo plano com esse volume"`, `applySuggestion = "Aplicar ao plano"`, `chooseOther = "Escolher outro volume"`, `previousTitle = "Ciclos anteriores"`, `summaryLine(_:) -> String`, `ruleTitle = "Como a sugestão é decidida"`, `ruleLines: [String]`, títulos de seção.

Cópia fixa (vem do mockup):
- `suggestionLine` com prova: "Sugestão: aumentar o pico de 80 para 86 km", "Sugestão: manter o pico em 80 km", "Sugestão: diminuir o pico de 80 para 72 km". Sem data: "Sugestão: aumentar de 60 para 64 km", "Sugestão: manter 60 km", "Sugestão: diminuir de 60 para 54 km".
- `volumes` com prova: "Início 60 → 64 km · pico 80 → 86 km"; manter: "Início 60 km · pico 80 km, como neste ciclo".
- `reason(.volume(share: 0.97, weeksBelow: 1))` = "Cumpriu 97% do volume, 1 semana abaixo do previsto." (0 semanas: "nenhuma semana abaixo do previsto").
- `reason(.readiness(first: 72, last: 75))` = "Prontidão média foi de 72 para 75."
- `reason(.lightWeeks(2))` = "2 semanas leves fora do previsto."
- `reason(.race(seconds: 5_628, goal: 5_700))` = "Fez a prova 1:12 abaixo da meta." (acima: "1:12 acima da meta").
- `reason(.tooShort(weeks: 3))` = "Só 3 semanas concluídas, pouco para mudar o volume."
- `reason(.noProgress)` = "Cumpriu o volume, mas a previsão não melhorou."
- `endMessage(weeks: 5)` = "A análise vai usar as 5 semanas já concluídas. O plano atual para de gerar treinos."

- [ ] **Step 1: Write the failing tests**: um `#expect` por string acima, com os valores exatos.
- [ ] **Step 2: Run** `xcodebuild test ... -only-testing:AppTests/TrainerCycleTextTests`. Expected: FAIL.
- [ ] **Step 3: Implement** `TrainerCycleText`.
- [ ] **Step 4: Run** o mesmo comando. Expected: PASS.
- [ ] **Step 5: Commit** `feat(treinador): textos da análise de fim de ciclo`

### Task 6: Telas

**Files:**
- Create: `App/Trainer/TrainerCycleView.swift` (tela "Análise do ciclo")
- Create: `App/Trainer/TrainerCycleCards.swift` (card de sugestão, gráfico de volume por semana, linhas de treinos-chave, corpo e forma)
- Create: `App/Trainer/TrainerCycleConstants.swift` (altura do gráfico 72, espaçamento 4, raio 2, limite 0,8 da semana em âmbar)
- Modify: `App/Trainer/TrainerTypes.swift` (`TrainerRoute.cycle`)
- Modify: `App/Trainer/TrainerView.swift` (banner, menu "Encerrar ciclo agora" com `confirmationDialog`, botões e "Ciclos anteriores", destino `.cycle`)
- Modify: `App/Trainer/TrainerPlanHeaderCard.swift` (parâmetro `cycle: TrainerCycleReview?`: quando `model.cycleEnded`, troca o placar por "Resultado do ciclo")
- Modify: `App/Trainer/TrainerNewPlanView.swift` (parâmetro `suggestedVolumes: (start: Int, peak: Int)? = nil`, aplicado em `prefill()` por cima de `editVolumes()` e também na criação nova)

**Interfaces:**
- Consumes: Tasks 4 e 5.

Comportamento:
- Banner aparece quando `model.showsCycleBanner`. Toque abre `.cycle` e chama `markCycleSeen()`.
- "Encerrar ciclo agora" só aparece com plano ativo e `!model.cycleEnded`.
- Plano com data passada ou encerrado: card do plano mostra "Resultado do ciclo", e abaixo vêm "Ver análise do ciclo" (primário) e "Novo plano" (secundário).
- Plano sem data em andamento com bloco fechado: só o banner. O placar continua.
- Na análise, o botão primário é `createWithSuggestion` quando `cycleEnded`, senão `applySuggestion`, que abre `TrainerNewPlanView(isEditing: true, suggestedVolumes:)`. "Escolher outro volume" abre o mesmo formulário sem sugestão.
- Seção Prova só com `raceSeconds`. Corpo sem prontidão: linha "Sem dados de prontidão neste ciclo".
- Cores do veredito: aumentar `BrandColors.accent`, manter `BrandColors.fitness`, diminuir `BrandColors.attention`, com o fundo `opacity(0.10)` da mesma cor no ícone.

- [ ] **Step 1: Implement** as views seguindo o mockup e as Global Constraints.
- [ ] **Step 2: Run** `xcodegen generate && xcodebuild test -project trAIning.xcodeproj -scheme trAIning -destination 'id=<simulador>'`. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 3: Run** o app no simulador com `scripts/dev-run.sh`, encerrar o ciclo pelo menu e capturar a tela (`xcrun simctl io <udid> screenshot`) do Treinador e da análise para comparar com o mockup.
- [ ] **Step 4: Commit** `feat(treinador): mostra a análise do ciclo e a opção de encerrar antes`

### Task 7: Verificação final

- [ ] **Step 1: Run** `swift test` em `Packages/TrainingKit`. Expected: tudo PASS.
- [ ] **Step 2: Run** `xcodebuild test` do app. Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 3: Run** `npx vitest run` e `npx tsc --noEmit` em `server/web`. Expected: tudo passa.
- [ ] **Step 4:** Conferir nos arquivos alterados: nenhum comentário novo, nenhum `TODO`, types e constantes fora das views.
