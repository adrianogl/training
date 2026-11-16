# Semana leve por sinais — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** No fechamento de cada semana, o treinador conta seis sinais de cansaço, comparados com a média pessoal de 60 dias, e alivia a semana seguinte ou antecipa a semana leve. O recálculo roda também na sincronização de madrugada, com notificação quando a semana muda por causa dos sinais.

**Regra aprovada** (mock https://claude.ai/artifact/WcTwquFSGedcZjguNrKQEC, aprovada em 15/11/2026 na outra conta):

| Sinal | Dispara quando |
| --- | --- |
| HRV | média de 7 noites < média dos 60 dias anteriores − 0,5 desvio padrão |
| FC de repouso | média de 7 dias ≥ média dos 60 dias + 3 bpm |
| Sono | média de 7 noites ≥ 45 min abaixo da média dos 60 dias |
| Carga | carga dos 7 dias > 1,3 × média semanal dos 28 dias (`acuteChronicRatio`) |
| Desempenho | os 2 últimos treinos de qualidade até o fim da semana fora do alvo, ou rodagens da semana com FC ≥ 5 bpm acima das rodagens da base no mesmo pace |
| Prontidão Garmin | média da semana < 55 |

- 0 ou 1 sinal: segue o plano.
- 2 sinais: semana seguinte com 10% a menos de volume e sem acelerações nem fartlek. A qualidade fica.
- 3+ sinais, ou HRV e FC de repouso juntos: antecipa a semana leve, se a última leve foi há 2 semanas ou mais e faltam mais de 3 semanas para a prova. A contagem 3:1 recomeça dali.
  - Sinais do corpo (HRV, FC, sono são maioria entre os disparados): volume × 0,75 e um só treino de qualidade, curto (o limiar da semana leve; o VO2 vira rodagem).
  - Sinais do treino (carga, desempenho, prontidão são maioria; empate = corpo): volume × 0,85 e as qualidades viram rodagem com acelerações.
- A semana leve do 3:1 nunca é adiada. Polimento não muda.
- Hoje a prontidão < 55 sozinha tira 10% da semana seguinte. Pela regra nova ela é um sinal entre seis; sozinha não muda nada.

## Global Constraints

- Sem comentários no código. Types em `*Types.swift`, constantes em `*Constants.swift`, texto de interface em `*Text.swift`.
- Plano e histórico antigos continuam decodificando (`decodeIfPresent`).
- Cada sinal exige dado mínimo: 4 dias na semana e 14 dias na base de 60. Sem isso o sinal não conta (nem a favor nem contra).
- Base = os 60 dias antes do início da semana fechada (a semana não entra na base).
- Texto do motivo, exato: 2 sinais → "Semana mais leve: <sinais> fora do seu normal."; antecipação → "Semana leve antecipada: <sinais> fora do seu normal.". Nomes dos sinais: "HRV", "FC de repouso", "sono", "carga", "desempenho", "prontidão", juntos com vírgula e "e" no último.
- Notificação: título "Plano atualizado", texto igual ao motivo, link `training://treinador`.

## Review Focus

- Atleta sem relógio de HRV/sono: sinais sem dado não disparam; o resto segue.
- Semana fechada logo antes de uma leve do 3:1: não antecipa (a leve já vem), mas 2 sinais não somam −10% em cima dela (fica a leve).
- A ≤ 3 semanas da prova: nunca antecipa; 2 sinais ainda podem tirar 10% fora do polimento.
- Recálculo duplicado (app aberto e madrugada no mesmo dia): uma versão só, uma notificação só.
- Plano encerrado (`endedOn`): nada roda.

---

### Task 1: Séries no histórico e cálculo dos sinais

**Files:** Modify `Packages/TrainingKit/Sources/Insights/TrainerTypes.swift` (`TrainerHistory`); Create `TrainerEngineSignals.swift`, `TrainerEngineSignalsConstants.swift`, `TrainerSignalTypes.swift` em `Sources/Insights`; Test `Tests/InsightsTests/TrainerSignalsTests.swift`.

**Interfaces — Produces:**
- `TrainerHistory` ganha `hrv: [Day: Double]`, `restingHeartRate: [Day: Int]`, `sleepSeconds: [Day: Int]`, `dailyLoad: [Day: Double]`, todos com default `[:]` no init.
- `public enum TrainerSignal: String, Codable, Sendable, CaseIterable { case hrv, restingHeartRate, sleep, load, performance, readiness }` com `var isBody: Bool` (hrv, restingHeartRate, sleep).
- `public static func signals(plan: TrainerPlan, history: TrainerHistory, week: TrainerWeek) -> [TrainerSignal]` (ordem de `allCases`).

- [ ] Testes, um por sinal disparando e não disparando no limite, mais: sem dado mínimo não dispara; base exclui a semana; desempenho por 2 qualidades seguidas `.offTarget` e por FC +5 bpm em rodagem no mesmo pace (faixa de ±10 s/km em volta do pace médio das rodagens da semana).
- [ ] Rodar e ver falhar; implementar; `swift test` verde.

### Task 2: Decisão no fechamento da semana

**Files:** Modify `TrainerEngineStatus.swift` (`findings`), `TrainerEngineTypes.swift` (`TrainerFindings`, `TrainerSkeletonAdjustment`), `TrainerEngineAdjust.swift`, `TrainerEngineSkeleton.swift`, detalhe dos treinos (onde acelerações e fartlek entram, `TrainerEngineRotation.swift`), `TrainerTypes.swift` (`TrainerPlan.earlyLightWeeks: [Day: TrainerLightKind]` com `decodeIfPresent`, `TrainerWeek.calm: Bool` com `decodeIfPresent`), `TrainerEngineText.swift`; Test `TrainerSignalWeekTests.swift`.

**Interfaces — Produces:** `public enum TrainerLightKind: String, Codable, Sendable { case body, training }`; `TrainerFindings.signals: [TrainerSignal]`; a versão gerada em `.weekEnded` leva o motivo exato das Global Constraints em `summary` e nas mudanças.

- [ ] Testes: 0–1 sinal não muda nada (inclusive prontidão < 55 sozinha); 2 sinais → semana seguinte com 90% do volume, sem acelerações nem fartlek, qualidade mantida; HRV+FC → semana leve antecipada tipo corpo (75%, um limiar curto, VO2 vira rodagem) e a próxima leve do 3:1 vem 4 semanas depois dela; carga+desempenho+prontidão → leve tipo treino (85%, qualidades viram rodagem com acelerações); última leve há 1 semana → não antecipa (cai para −10%); ≤ 3 semanas da prova → não antecipa; próxima semana já é leve do 3:1 → fica como está; texto do motivo exato.
- [ ] Implementar; `swift test` verde.

### Task 3: Histórico no app, madrugada e notificação

**Files:** Modify `App/Trainer/TrainerHistoryLoader.swift` (preencher as quatro séries a partir de `DailyRecord` e da soma diária de `ActivityRecord.activityTrainingLoad` de todas as atividades, janela atual de 120 dias), `App/Background/BackgroundSync.swift` (esperar o ajuste do treinador antes de `setTaskCompleted`), `App/Trainer/TrainerModel.swift` (expor o resultado do ajuste: versões novas criadas por `.weekEnded` com sinais), novo notifier em `App/Background/` (`TrainerSignalNotifier.swift` + constantes + texto), roteamento do link `training://treinador` em `NotificationRouter` se ainda não existir; `App/Trainer/TrainerText.swift` (`triggerText` mostra o motivo dos sinais). Tests em `AppTests/`.

- [ ] Testes: loader preenche as séries; ajuste com sinais agenda uma notificação com o texto exato e o link; segundo ajuste no mesmo dia não agenda de novo; plano encerrado não notifica.
- [ ] Suite completa do app verde.

### Task 4: Landing

- [ ] `server/landing/index.html`: o card "Ajuste pela prontidão" passa a descrever a regra (seis sinais comparados com o seu normal, semana mais leve ou leve antecipada, aviso de manhã); o card "Volume em ondas" em "Os métodos por trás" cita a antecipação. Sem cards novos (o grid fecha em 12).
