# Plano de força com validade — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** criar o plano de força com objetivo, dias e validade, montado pelo Treinador ou pelo Claude, que some no fim com uma notificação, sem nunca substituir o MFIT.

**Architecture:** `StrengthPlan` (pacote `Insights`) guarda objetivo, início, validade e as sessões do Treinador. Um store por conta, sincronizado como blob `preference` `strengthPlan`, segue o padrão dos stores da v1.28.0. As sessões do plano continuam alimentando `TrainerEngine` pelo caminho atual (`saveStrength`), mas só geram treino entre `start` e `end`; sessões do MFIT ficam fora do plano e não mudam.

**Tech Stack:** Swift 6 / SwiftUI (iOS 26), Swift Testing, TrainingKit (`Insights`, `RemoteSync`), XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-20-plano-forca-validade-design.md` · Mock aprovado: https://claude.ai/artifact/BbmYv5kuRfnLuefp1XsFcs

## Global Constraints

- Sem comentários no código; types em `*Types.swift`, constantes em `*Constants.swift`.
- Texto PT-BR igual ao mock; cantos concêntricos card 26, interno 12.
- MFIT nunca é escondido, trocado nem recebe `replacesMFIT` por causa do plano.
- Um plano de força ativo por conta.
- Plano que terminou não gera treino.
- Gravação atômica no disco antes de qualquer rede; sync no padrão de `JSONFileStore` + `SyncDocumentStamp`.
- Commits liberados nesta branch, sem push; merge/push/release/deploy pedem aprovação.
- Regra nova em `docs/regras/prescricao.md`; README e landing atualizados.
- Nunca rodar `rsync`/`rm`/`cp` com destino vindo de variável sem `${VAR:?}`.

## Review Focus

- Migração de quem já tem sessões de força (com e sem plano de corrida): nada se perde e o aviso aparece uma vez (Task 1).
- Dia com MFIT e plano: os dois aparecem; dia de MFIT fora da validade do plano continua aparecendo (Task 3).
- Plano editado no meio (dias trocados, validade encurtada): treinos do Claude de dias que saíram do plano somem; os do MFIT não (Tasks 3 e 4).
- Último treino não feito: a notificação sai às 21h do último dia, uma vez só, mesmo com o app aberto em dois aparelhos (Task 5).
- Prova-alvo removida ou movida com validade "até a prova": `end` recalcula sem plano infinito (Task 1).

---

### Task 1: Modelo, store, sincronização e migração

**Files:**
- Create: `Packages/TrainingKit/Sources/Insights/StrengthPlan.swift`, `StrengthPlanTypes.swift`, `StrengthPlanConstants.swift`
- Create: `App/Trainer/StrengthPlan/StrengthPlanStore.swift`, `StrengthPlanStoreTypes.swift`, `App/DeviceSync/StrengthPlanSyncStore.swift`, `App/Trainer/StrengthPlan/StrengthPlanMigration.swift`
- Modify: `App/AppModel.swift` (uma instância do store, compartilhada com o sync store), `App/Account/AccountScope.swift` (URL)
- Test: `Packages/TrainingKit/Tests/InsightsTests/StrengthPlanTests.swift`, `AppTests/StrengthPlanStoreTests.swift`

**Interfaces:**
- Produces:

```swift
public enum StrengthObjective: String, Codable, Sendable, CaseIterable { case mobility, strength, prevention }
public enum StrengthPlanValidity: Codable, Sendable, Equatable { case untilRace(raceId: String, raceDay: Day), weeks(Int), untilDate(Day) }
public enum StrengthPlanBuilder: String, Codable, Sendable { case trainer, claude }
public struct StrengthPlan: Codable, Sendable, Equatable, Identifiable {
  public var id: UUID; public var objective: StrengthObjective; public var sessions: [TrainerStrengthSession]
  public var start: Day; public var validity: StrengthPlanValidity; public var builder: StrengthPlanBuilder
  public var createdAt: Date; public var endedNotifiedAt: Date?; public var migrated: Bool
  public var end: Day { get }                       // weeks: start + 7n − 1; untilDate: a data; untilRace: raceDay − 1
  public func isActive(on day: Day) -> Bool          // start ≤ day ≤ end
  public func lastSessionDay() -> Day?               // último dia ≤ end com sessão do plano
  public func plannedCount() -> Int                  // dias com sessão entre start e end
}
```

App: `StrengthPlanStore` com `current() -> StrengthPlan?`, `save(_:) throws`, `clear() throws`, `merge(remote:) -> Bool`; sync id `"strengthPlan"`; `StrengthPlanMigration.migrate(sessions:runningPlanEnd:today:) -> StrengthPlan?`.

- [ ] **Step 1:** testes: `weeks_8_from_tue_24_11_ends_mon_18_01_with_16_sessions` (ter e qui, `end == 2027-01-18`, `plannedCount() == 16`, `lastSessionDay() == 2027-01-14`; o mock dizia "qui. 15/01", que não fecha com 8 semanas), `until_date_end_is_the_date`, `until_race_ends_day_before_race`, `inactive_after_end`, `store_saves_before_sync_and_merges_newer` , `migration_with_running_plan_ends_with_it`, `migration_without_running_plan_is_12_weeks`, `migration_keeps_only_trainer_sessions` (sessões `.mfit` ficam fora do plano), `migration_runs_once`.
- [ ] **Step 2:** rodar → FAIL (RED registrado).
- [ ] **Step 3:** implementar; migração chamada no `load()` do `TrainerModel` quando não há plano de força e existem sessões `.trainer`; o objetivo deduzido é `mobility` se todas as sessões forem `core`/`mobility`, senão `strength`; `migrated = true` liga o aviso único da Task 6.
- [ ] **Step 4:** `swift test --package-path Packages/TrainingKit` e `scripts/dev-run.sh --test` → PASS.
- [ ] **Step 5:** commit `feat(forca): adiciona o plano de força com validade`.

### Task 2: Foco mobilidade no gerador

**Files:**
- Modify: `Packages/TrainingKit/Sources/Insights/TrainerTypes.swift:241` (`TrainerStrengthGroup.mobility`), `StrengthGenerator.swift`, `StrengthGeneratorConstants.swift`, `App/Trainer/TrainerStrengthText.swift` (`focusName(.mobility) == "Mobilidade"`), `App/Trainer/TrainerStrengthConstants.swift` (`focusOrder` inclui `.mobility`), servidor `server/src/mcp/strengthTypes.ts`/validador se listarem os grupos
- Test: `Packages/TrainingKit/Tests/InsightsTests/StrengthGeneratorMobilityTests.swift`

**Interfaces:** `TrainerStrengthGroup.mobility`; o gerador escolhe só padrões `mobilityHip`, `mobilityAnkle`, `mobilityThoracic` (e `hipStability` se faltar), sem carga, intensidade leve.

- [ ] **Step 1:** testes: `mobility_session_uses_only_mobility_patterns`, `mobility_session_has_no_weight`, `old_documents_without_mobility_still_decode`.
- [ ] **Step 2:** RED. **Step 3:** implementar (exaustividade de `switch` em todo o app). **Step 4:** pacote, app e `npm --prefix server test` → PASS. **Step 5:** commit.

### Task 3: Treinos do plano só dentro da validade, MFIT em paralelo

**Files:**
- Modify: `App/Trainer/TrainerModel+Strength.swift` (`trainerSessions(on:)`, `claudeOverride(on:)`, `replacesMFIT(on:)`), `App/Trainer/TrainerModel.swift` (`saveStrength` grava o plano; `strengthSessions` = sessões `.mfit` atuais + sessões do plano), `App/Strength/TodayStrengthCard.swift`, `App/Trainer/Claude/ClaudeStrengthStore.swift` + `ClaudeStrengthStoreTypes.swift` (`planId: UUID?`)
- Test: `AppTests/StrengthPlanScheduleTests.swift`

**Interfaces:** `TrainerModel.strengthPlan: StrengthPlan?`; `trainerSessions(on:)` devolve `[]` quando `!(strengthPlan?.isActive(on: day) ?? false)`; treino do Claude com `planId` diferente do plano ativo ou fora da validade é ignorado; `replacesMFIT(on:)` é `false` para treino com `planId`.

- [ ] **Step 1:** testes: `no_plan_sessions_after_end`, `no_plan_sessions_before_start`, `mfit_day_shows_both_mfit_and_plan`, `mfit_outside_plan_still_shows`, `claude_workout_of_old_plan_is_ignored`, `plan_workout_never_replaces_mfit`, `edited_plan_drops_claude_days_that_left_the_plan`.
- [ ] **Step 2:** RED. **Step 3:** implementar. **Step 4:** `scripts/dev-run.sh --test` → PASS. **Step 5:** commit.

### Task 4: Pedido ao Claude usa o plano

**Files:**
- Modify: `App/Trainer/Claude/TrainerModel+Claude.swift` (`claudePeriod`), `ClaudeRequestSheet.swift`, `ClaudeContextBuilder.swift`, `ClaudeText.swift`, `ClaudeImportSheet.swift` (sem opção de substituir MFIT para plano)
- Test: `AppTests/ClaudePlanRequestTests.swift`

**Interfaces:** com plano ativo `builder == .claude`, o período do pedido é `(max(start, amanhã), end)` e os dias/focos vêm das sessões do plano; o resultado é gravado com `planId`.

- [ ] **Step 1:** testes: `request_period_is_plan_range`, `request_days_are_plan_days`, `import_tags_plan_id`, `import_never_sets_replaces_mfit_for_plan`.
- [ ] **Step 2:** RED. **Step 3:** implementar. **Step 4:** PASS. **Step 5:** commit.

### Task 5: Fim do plano e notificação

**Files:**
- Create: `App/Trainer/StrengthPlan/StrengthPlanEndNotifier.swift`, `StrengthPlanEndConstants.swift`
- Modify: `App/AppModel.swift` (chamar no refresh/abertura e após concluir treino), `App/DeepLink/*` (link para a tela de força)
- Test: `AppTests/StrengthPlanEndTests.swift`

**Interfaces:** `StrengthPlanEndNotifier.check(plan:history:now:calendar:scheduler:) async -> StrengthPlan?` devolve o plano com `endedNotifiedAt` preenchido quando notificou. Agenda a notificação para 21h do `lastSessionDay()` ao salvar o plano (id `strength-plan-end`), troca para imediata se o último treino for concluído antes, e cancela se o plano for editado/apagado. Texto: título "Plano de <objetivo> terminou", corpo "Foram X de Y treinos. Toque para montar o próximo.", link para Treinador › Força.

- [ ] **Step 1:** testes: `schedules_21h_on_last_session_day`, `fires_now_when_last_workout_done`, `only_once_per_plan` (dois `check` seguidos e `endedNotifiedAt` sincronizado), `edit_reschedules`, `delete_cancels`.
- [ ] **Step 2:** RED. **Step 3:** implementar. **Step 4:** PASS. **Step 5:** commit.

### Task 6: Telas

**Files:**
- Create: `App/Trainer/StrengthPlan/StrengthPlanFormView.swift`, `StrengthPlanCard.swift`, `StrengthPlanEndedNotice.swift`, `StrengthPlanText.swift`, `StrengthPlanUIConstants.swift`
- Modify: `App/Trainer/TrainerStrengthView.swift`, dia do Treinador e Hoje (etiquetas "MFIT" e "Plano")
- Test: `AppTests/StrengthPlanSnapshotTests.swift`

Textos do mock: "Novo plano de força", "Objetivo", "Mobilidade/Força/Prevenção", "Dias", "+ Adicionar dia", "Validade", "Até a prova/Semanas/Até a data", "Duração", "Começa em", "Termina %@ · %d treinos", "Quem monta", "Treinador/Claude", "Criar plano", "Plano de força", "Semana %d de %d · %d de %d treinos feitos", "Editar plano", "+ Novo plano de força", "Plano de %@ terminou em %@", "%d de %d treinos feitos. %@ ficam sem treino do plano.", "Montar próximo plano", "Repetir o mesmo plano", aviso de migração "Seu treino de força virou um plano até %@. Ajuste a validade se quiser."

- [ ] **Step 1:** snapshots das 4 telas do mock + aviso de migração; teste `repeat_plan_starts_next_training_day_same_duration`.
- [ ] **Step 2:** RED. **Step 3:** implementar; "Até a prova" desabilitado sem prova cadastrada. **Step 4:** PASS e comparar com o mock. **Step 5:** commit.

### Task 7: Documentação e suítes

- [ ] `docs/regras/prescricao.md` (plano de força, validade, mobilidade, MFIT em paralelo), README, `server/landing/index.html`.
- [ ] Todas as suítes: `scripts/dev-run.sh --test`, `swift test --package-path Packages/TrainingKit`, `npm --prefix server test`, `npm --prefix server run typecheck`, scripts Python.
- [ ] Commit `docs(forca): documenta o plano de força com validade`.
