# Ajuste do dia com números — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** o treino da assessoria no Hoje mostra a faixa de pace ajustada por prontidão, calor (temperatura + orvalho) e perna pesada; o aviso da manhã cita a faixa; o treinador usa a mesma conta de calor da análise.

**Architecture:** uma função pura `DayAdjust.adjust` em `Insights` recebe o treino do Garmin, a nota, a previsão da hora, a aclimatação e a perna pesada, e devolve os passos ajustados com os motivos. O card do Hoje e o aviso da manhã só formatam o resultado. `TrainerHeat` troca os limites de 24/28 °C por `WeatherAdjustment.heatFactor`.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-21-ajuste-do-dia-design.md`

## Global Constraints

- Sem comentários no código. Tipos em `<Nome>Types.swift`, constantes em `<Nome>Constants.swift`, nunca dentro da view.
- Prescrição por distância; pace em segundos por km (`PlannedTarget.pace(fastest:slowest:)`).
- Ajuste só em passos `kind == .active` com alvo `.pace`. Aquecimento, recuperação e alvos por FC ou zona não mudam.
- Degraus: nota ≥ 70 → 0; 60–69 → +3 s/km; 50–59 → +6 s/km, intervalado com uma repetição a menos, contínuo 20% mais curto, longão com o final 20% mais curto; < 50 → sem faixa (frase atual de descanso).
- Calor: `WeatherAdjustment.heatFactor(temperature:dewPoint:) × (1 − WeatherAdjustment.adaptation(hotSessions:))` × pace do bloco, arredondado ao segundo. Sem orvalho ou sem previsão: sem calor, motivo "sem previsão do tempo".
- Perna pesada na véspera: +3 s/km, inclusive no longão.
- Soma arredondada ao segundo, teto 15 s/km; acima do teto, sem faixa e com a frase de troca por rodagem.
- Hora do clima: mediana da hora de início das corridas dos últimos 30 dias; sem corridas, 7h.
- Treinador: corte de 1 km de bloco no longão com fator de calor ≥ 0,045.
- Textos em pt-BR seguindo `~/.claude/text-pt-br.md`. Mudança de regra atualiza `docs/regras/analise.md` e `docs/regras/prescricao.md` no mesmo commit.
- Layout só depois do mock aprovado (Task 1).
- Commit só com aprovação do Adriano. Os passos "commit" marcam onde cada commit será proposto; sem aprovação, as mudanças ficam no worktree.

## Review Focus

- Treino com repetição aninhada (`children` com `repeats`): a repetição a menos sai do grupo, não de um passo solto.
- Intervalado com `repeats == 1` em todos os grupos e vários `active`: "um bloco a menos" tira o último `active` e a recuperação que vem antes dele.
- Previsão sem a hora habitual (a busca só traz algumas horas da manhã): usa a hora mais próxima disponível.
- Nota ausente (`readinessFromYesterday` ou sem dado): só calor e perna contam, sem degrau de prontidão.
- Faixa com `fastest == slowest`: as duas pontas sobem igual e o texto não quebra.

---

### Task 1: Mock do card e do aviso

**Files:** artifact no scratchpad (fora do repo).

- [ ] **Step 1:** montar artifact atual × proposta só do card "Treino de hoje" (treino 5 × 1 km da assessoria, nota 64, 27 °C e orvalho 22 °C às 7h, sem perna pesada) e da notificação da manhã, no tema escuro do app.
- [ ] **Step 2:** esperar aprovação explícita. Ajustes do mock voltam para este plano antes da Task 4.

### Task 2: `DayAdjust` no Insights

**Files:**
- Create: `Packages/TrainingKit/Sources/Insights/DayAdjust.swift`, `DayAdjustTypes.swift`, `DayAdjustConstants.swift`
- Test: `Packages/TrainingKit/Tests/InsightsTests/DayAdjustTests.swift`

**Interfaces:**
- Produces:
  - `public enum DayAdjustShape { case continuous, intervals, long }`
  - `public struct DayAdjustInput { plan: PlannedWorkout; shape: DayAdjustShape; score: Int?; temperature: Double?; dewPoint: Double?; hotSessions: Int; heavyLegs: Bool }`
  - `public enum DayAdjustReason: Equatable { case readiness(score: Int, seconds: Int), heat(temperature: Double, dewPoint: Double, seconds: Int), heavyLegs(seconds: Int), noForecast }`
  - `public enum DayAdjustResult: Equatable { case none, adjusted(steps: [PlannedStep], original: [PlannedStep], seconds: Int, reasons: [DayAdjustReason], shortened: Bool), swap(reasons: [DayAdjustReason]), rest }`
  - `public static func DayAdjust.adjust(_ input: DayAdjustInput) -> DayAdjustResult`
  - `public static func DayAdjust.usualHour(_ starts: [Date], calendar: Calendar) -> Int`
  - `public static func DayAdjust.weather(at hour: Int, in hours: [(hour: Int, temperature: Double, dewPoint: Double?)]) -> (temperature: Double, dewPoint: Double?)?`
- Constants (`DayAdjustConstants`): `readinessSteps = [(70, 0), (60, 3), (50, 6)]`, `restBelow = 50`, `heavyLegsSeconds = 3`, `maximumSeconds = 15`, `shortenShare = 0.8`, `defaultHour = 7`, `usualWindowDays = 30`.

- [ ] **Step 1: testes que falham**

```swift
@Test func strongReadinessWithoutHeatChangesNothing()      // score 75, 18 °C/10 °C → .none
@Test func moderateStepAddsThreeSecondsToActiveOnly()      // score 64, sem calor: active 240–248 → 243–251; warmup igual
@Test func heatUsesAnalysisTable()                         // score 80, 27 °C/22 °C, hotSessions 0: segundos == Int((heatFactor(27,22) * 244).rounded()) em pace médio do bloco
@Test func acclimatizationReducesHeat()                    // hotSessions 4 → fator × 0,8
@Test func lowStepDropsOneRepeatInIntervals()              // score 55, 5 × (1 km + 2:30) → repeats 4, +6 s, shortened == true
@Test func lowStepShortensContinuousBy20Percent()          // score 55, contínuo 10 km → 8 km
@Test func heavyLegsAddsThreeSecondsOnLongRun()            // shape .long, score 80, heavyLegs → +3 s
@Test func reasonsSumAndCapAt15()                          // score 55 (+6) + calor 9 s + perna 3 → .swap
@Test func belowFiftyIsRest()                              // score 45 → .rest
@Test func missingForecastAddsNoForecastReason()           // score 64, temperature nil → reasons contém .noForecast, seconds 3
@Test func missingScoreSkipsReadinessStep()                // score nil, 27/22 → só calor
@Test func usualHourIsMedianOrSeven()                      // [6h, 7h, 18h] → 7; [] → 7; [6h, 6h, 19h] → 6
@Test func weatherPicksClosestHour()                       // horas [5, 6, 9], pede 7 → 6
```

- [ ] **Step 2:** `swift test --package-path Packages/TrainingKit --filter DayAdjustTests` falha por símbolo ausente.
- [ ] **Step 3:** implementar. "Uma repetição a menos" reduz `repeats` do primeiro grupo com `repeats > 1` que contém `active`; sem grupo, remove o último `active` e o passo de recuperação ou descanso imediatamente antes. "20% mais curto" multiplica `meters` dos `active` por 0,8, arredondado a 100 m (no longão, só o último `active`).
- [ ] **Step 4:** a suíte passa.
- [ ] **Step 5:** commit `feat(hoje): calcula o ajuste do treino por prontidão, calor e perna pesada`.

### Task 3: calor do treinador pela tabela da análise

**Files:**
- Modify: `Packages/TrainingKit/Sources/Insights/TrainerHeat.swift`, `TrainerEngineConstants.swift` (sai `heatThreshold`, `heatStrong`, `heatPaceOffset`, `heatStrongPaceOffset`; entra `heatBlockFactor = 0.045`)
- Modify: `App/Trainer/TrainerBestTimeBuilder.swift`, `App/Trainer/TrainerText.swift` (`heatWarning`, `heatLater`), `App/Workouts/Planned/PlannedBriefingTypes.swift` se precisar passar orvalho
- Test: `Packages/TrainingKit/Tests/InsightsTests/TrainerLongBlocksTests.swift` (testes de 24/28 °C trocados)

**Interfaces:**
- Produces: `TrainerHeat.assess(temperature: Double, dewPoint: Double?, pace: Double, hotSessions: Int = 0) -> TrainerHeat`, com `factor: Double`, `paceOffset` (segundos, arredondado) e `blockReduction` (1 000 m quando `factor >= 0.045`, senão 0). `isHot == paceOffset > 0`.

- [ ] **Step 1:** trocar os testes: `assess(temperature: 24, dewPoint: 10, pace: 300).isHot == false`; `assess(temperature: 27, dewPoint: 22, pace: 300).paceOffset == Int((heatFactor(27,22) * 300).rounded())`; `blockReduction == 1000` só com fator ≥ 0,045; orvalho nil → `isHot == false`.
- [ ] **Step 2:** rodar `--filter TrainerLongBlocksTests` e ver falhar.
- [ ] **Step 3:** implementar; `TrainerBestTimeBuilder` passa `dewPoint` e o pace do longão (`trainer.paces.long` ou 360 s sem plano). Textos: "Mesmo no horário mais fresco, calor de 27 °C com orvalho de 22 °C: o pace sobe N s/km" (+ " e os blocos ficam 1 km menores" quando houver corte); `heatLater` vira "A partir das Hh o calor passa a pesar no pace." (+ blocos).
- [ ] **Step 4:** `--filter TrainerLongBlocksTests` e `--filter TrainerEngineTests` passam; app compila.
- [ ] **Step 5:** commit `fix(treinador): calcula o calor do longão pela temperatura e pelo orvalho`.

### Task 4: card "Treino de hoje"

**Files:**
- Modify: `App/Today/TodayWorkoutCard.swift`, `App/Today/PlannedWorkoutViews.swift` (`PlannedStepsList` ganha `original: [PlannedStep]?` e mostra "era …" no passo que mudou), `App/Today/TodayConstants.swift`, `App/Today/TodayView.swift` (passa as horas de início das corridas)
- Create: `App/Today/DayAdjustText.swift`
- Test: `AppTests/DayAdjustTextTests.swift`, `AppTests/DayAdjustCardSnapshotTests.swift` (`day-adjust-card.png`)

**Interfaces:**
- Consumes: Task 2 inteira.
- Produces: `DayAdjustText.reasons(_ reasons: [DayAdjustReason], hour: Int) -> String`, `DayAdjustText.morning(_ result: DayAdjustResult, plan: PlannedWorkout) -> String?`.

- [ ] **Step 1:** testes de texto: `reasons([.heat(27, 22, 5), .readiness(64, 3)], hour: 7) == "Ajuste +8 s/km: calor 27° e orvalho 22° às 7h (+5 s), prontidão 64 (+3 s)"`; `.noForecast` vira "sem previsão do tempo"; `morning(.adjusted…)` para 5 × 1 km == "Tiros em 4:08–4:16 por calor e prontidão."; `.none` → nil. Ajustar o texto exato ao mock aprovado.
- [ ] **Step 2:** rodar `-only-testing:AppTests/DayAdjustTextTests` e ver falhar.
- [ ] **Step 3:** implementar. O card busca a previsão de hoje (`trainer.forecast(for: model.today)`), escolhe a hora com `DayAdjust.usualHour` sobre as corridas dos últimos 30 dias e `DayAdjust.weather(at:in:)`, conta `hotSessions` como a análise (corridas quentes nos últimos 14 dias), e `heavyLegs = legDay != nil`. `.adjusted` mostra os passos novos com "era …" e a linha de motivos no `DSNotice`; `.swap` e `.rest` mantêm a frase atual de `PlanText.adjust`; `.none` não mostra aviso. A sugestão do treinador continua tendo prioridade (`showsAdvice`).
- [ ] **Step 4:** testes passam; snapshot gerado e comparado com o mock no iPhone (escuro) e no iPad (claro).
- [ ] **Step 5:** commit `feat(hoje): mostra o pace ajustado do treino da assessoria`.

### Task 5: linha no aviso da manhã

**Files:**
- Modify: `App/AppModel.swift` (`morningRunLine() async -> String?` ao lado de `morningStrengthLine()`), `App/Background/MorningNotifier*.swift` (aceita `runLine` e coloca antes da força)
- Test: `AppTests/MorningNotifierTests.swift` (ou a suíte que já testa `strengthLine`)

- [ ] **Step 1:** teste: com `runLine: "Tiros em 4:08–4:16 por calor e prontidão."` e `strengthLine: "Força: MMII."`, o corpo termina com as duas, nessa ordem; `runLine` nil não muda o corpo atual.
- [ ] **Step 2:** ver falhar.
- [ ] **Step 3:** implementar. `morningRunLine` busca o treino do Garmin de hoje e a previsão; qualquer falha devolve nil, sem atrasar o aviso além de 5 s (`TodayConstants.morningRunTimeout`).
- [ ] **Step 4:** testes passam.
- [ ] **Step 5:** commit `feat(hoje): cita o pace ajustado no aviso da manhã`.

### Task 6: regras, README e landing

**Files:** `docs/regras/analise.md` (seção "Ajuste para hoje" com a tabela de degraus, calor, perna e teto), `docs/regras/prescricao.md` (linha de calor de "Ajustes do plano"), `README.md` (se citar o ajuste), `server/landing/index.html` ("Treino de hoje": "Se a prontidão está baixa, o app diz o que mudar" vira "o app recalcula o pace pela prontidão, pelo calor e pela perna do dia anterior").

- [ ] **Step 1:** atualizar os quatro arquivos.
- [ ] **Step 2:** suíte inteira: `scripts/dev-run.sh --test` e `swift test --package-path Packages/TrainingKit`.
- [ ] **Step 3:** commit `docs(regras): documenta o ajuste do dia e o calor pelo orvalho`.
