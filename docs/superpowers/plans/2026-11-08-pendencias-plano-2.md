# trAIning — Pendências do núcleo de dados para o plano 2

Saída do review final da branch `feat/nucleo-de-dados` (dcc23df..afbf528). Nada aqui bloqueia o núcleo; são decisões e ajustes que o app precisa antes ou durante as telas.

## Fundação (primeira tarefa do plano 2)

- **Sync cancelável e modo background.** `SyncEngine.run` cria um `Task {}` não estruturado e o `sleep` do `GarminClient` engole o cancelamento. Com 429 o cliente espera 30/60/120 s, e as zonas gastam até 210 s antes de seguir. O `BGAppRefreshTask` tem uns 30 s. Precisa de `withTaskCancellationHandler`, `Task.checkCancellation()` entre janelas e páginas, `sleep` que relança cancelamento e um modo background que não espera em 429 e retoma no próximo sync.
- **Modelo de zonas de FC.** As zonas são buscadas e descartadas (`SyncEngine.heartRateZones`). Pace na Z2 e pace de limiar dependem dos limites e de `lactateThresholdHeartRateUsed`.
- **`SchemaV1` e plano de migração.** O schema atual não tem versão. Envolver como `SchemaV1` antes do app criar stores nos aparelhos. `cloudKitDatabase` já está `.none`; ligar CloudKit vira decisão explícita.
- **`Day` local no `ActivityRecord`.** `startTimeLocal` é interpretado no fuso do aparelho no momento do sync. Corrida perto da meia-noite numa viagem muda de dia na carga e no FFF.
- **`@Attribute(.externalStorage)`** em `samplesData` e `routeData`, para a lista de treinos não carregar os blobs.

## Métricas e calibração

- Comparar com o Garmin Connect (step 4 da Task 12): VO2max suavizado a ±1,5 e previsões a ±3% do race predictor. Previsões atuais na conta real: 5 km 22:53, 10 km 47:43, 21,1 km 1:45:17, 42,2 km 3:39:30; VO2max 55,1.
- Durabilidade e força em subida: a spec pede mediana móvel (4 corridas / 4 semanas); o CLI mostra só a corrida mais recente.
- Pace de limiar: contiguidade por posição no array; pausa junta dois trechos. Corrigir antes do card de limiar.
- `zone2Pace`/`thresholdPace` calculam duração como `count × 5 s`, duplicando o bucket do `FITReader`.
- Hill index: trecho aparado nas pontas vira `.flat` mesmo com inclinação de outra classe; falta teste de subida perto de 200 m / 4% com ruído.
- `assessGoal` com previsão 0 dá inf/NaN; validar a meta na UI.
- `paceStrategy`: sem limite de inclinação fora de Minetti, shift ≤ 0 com km manuais extremos, chaves manuais fora da faixa ignoradas.
- Projeção: o cruzamento da meta só existe com a meta à frente na tendência; meta já batida aparece como nil e a UI compara valor atual × meta.
- Prontidão recalculada só para dias tocados: atividade nova não recalcula o A:C dos 28 dias seguintes no incremental.

## Sync e API

- `SyncReport` não indica quando o passo de FIT parou em 429; a UI não distingue "tudo processado" de "parou no limite".
- FIT com falha é retentado em todo sync, sem limite.
- Desempate no dedup com `updatedAt` igual é aleatório; pode apagar a cópia com `fitProcessed == true`.
- Atividade apagada no Garmin entre a falha e a retomada da primeira carga pode fazer o cursor de offset pular atividades antigas; retomar em `cursor − pageSize`.
- Com `lastActivityStart` nil (primeira carga sem atividade), o incremental pagina o histórico inteiro.
- Vários `SyncState` (merge do CloudKit) usa o primeiro e não remove os outros.
- 403/404 viram `.server(status:)` sem path; `URLError` de transporte não tem retry (tratar offline).
- Itens descartados no decoding tolerante não são logados nem contados.
- `Retry-After` negativo ou 0 vira retry imediato; tratar como inválido.
- Prontidão de todos os dias na primeira carga faz um fetch por dia.
- `ReportBuilder.currentVo2max` e `latest(in:)` não filtram atividade sem início.

## Provas e storage

- `RaceRecord.priority` é `String` com padrão "C"; trocar por enum com `rawValue`.
- Import de provas com o mesmo `id` duas vezes no arquivo depende do fetch enxergar o insert pendente; deduplicar antes.
- Testes de storage retêm o container só por `let`; usar `withExtendedLifetime`.

## Testes que faltam

- `Day`: bissexto, janelas com from > to / from == to, `today` com fusos.
- Schema: conferir "toda propriedade tem padrão" e um controle negativo de `.unique`; round-trip com campos `*Data` e opcionais de HRV/sono.
- Sync: `.invalidKey` vindo de `activities`/`heartRateZones`, desempate no dedup, single-flight com dois `run()` concorrentes, run seguinte num dia posterior com engine novo.
- Cliente: header `retry-after` em minúsculas, `Retry-After` num 503 (ignorar).
- Projeções: passo dividido no teto, `targetCrossing == today`, inclinação zero, pontos futuros, dias duplicados; trocar igualdade exata de `Double` por tolerância.
- Limites de 300 s em `zone2Pace`/`thresholdPace` e `raceBlock` com prova a mais de 12 semanas ou já passada.

## Estado ao fim do plano 2

Resolvido na branch `feat/app-pos-treino`: toda a seção Fundação, as correções de métricas, sync, API e provas acima, e os testes listados em "Testes que faltam".

Fica para o plano 3:

- **Modo background do sync.** O cancelamento já funciona; falta o modo que não espera em 429 e retoma no próximo `BGAppRefreshTask`.
- **Limite de tentativas de FIT com erro transitório.** FIT ausente (404/410) e `.FIT` inválido saem da fila; 5xx e rede continuam sendo tentados em todo sync. Limitar exige contador no schema (`SchemaV3`).
- **Calibração com o Garmin Connect.** VO2max a ±1,5 e previsões a ±3% do race predictor, conferidos com a conta real.
- **Meta já batida na projeção.** `targetCrossing` fica nil quando a tendência já passou da meta; a tela compara valor atual × meta.

Descartado: `withExtendedLifetime` nos testes de storage. O `ModelContext` guarda referência forte ao `ModelContainer`, então o container não é liberado antes do fim do teste.
