# trAIning — Pendências do plano 4 (Zonas pelo limiar e Provas)

Estado da branch `feat/zonas-limiar-e-provas` ao fim do plano 4. A Task 13 (recalibração com provas confirmadas) não rodou por um bloqueio externo. O resto são itens não bloqueantes do review final e dos reviews por tarefa, sem dado da conta.

## Recalibração (Task 13, não feita)

- A recalibração com provas confirmadas mira previsões a ±3% do Garmin Connect e VO2max a ±1,5. Não rodou: o download do FIT (`/download-service/files/activity/<id>`) responde 404 para qualquer atividade, e o mesmo endpoint funcionou no plano 2.
- O reprocessamento para `processingVersion` 3 (limiar e zonas vindos do FIT de cada corrida) está pendente nos dados do usuário. Sem ele, `ThresholdHistoryRecord` fica vazio e `thresholdZoneSeconds` não é preenchido.
- Maratona e meia só viram candidatas a prova quando houver histórico de limiar. Sem limiar, a regra cai no fallback de FC ≥ 95% do limiar e não tem como avaliar.
- O corte do coeficiente de variação do pace das voltas (0,06) tem folga curta para maratona com paradas: provas ficam em 0,015–0,044, e um longo com uma parada chegou a 0,053. Revisar com provas reais depois do reprocessamento.

## Sync e FIT

- O 404 do FIT chega como `GarminAPIError.server(status: 404)`, sem path, e é tratado como transitório (Ruling 18). Cada sync tenta de novo todas as corridas pendentes. Decidir a classificação quando o comportamento do endpoint for conhecido: se for FIT apagado, vira permanente; se for mudança de API, continua transitório.
- `SyncReport.skippedFITs` não tem limite próprio; hoje depende de `fitLimit`.
- Corrida mais tardia do dia sem `time_in_zone` não atualiza o histórico do limiar, e o dia fica com o valor da corrida anterior ou com um valor antigo.
- Durante o reprocessamento, dias antes do primeiro registro vindo do FIT usam `entries.first`.
- `multisport` e `calcType` do `time_in_zone` não são validados.
- O refresh inicial do limiar decodifica todas as corridas num passo só, sem `checkCancellation` e com um único save no fim.
- `samplesData` indecodificável é tentado de novo a cada sync.

## Antes de instalar no iPhone

- Confirmar se o aparelho recebeu alguma build do plano 4 entre `1befca4` e `60e9dc7`. Nesse intervalo o `SchemaV4` foi editado no lugar. Agora o V4 está congelado e o V5 tem estágio leve V4 → V5, com teste que abre store criado no V4 antigo. Mesmo assim, se o store abriu um V4 intermediário, o app cai em store em memória sem aviso. O fallback silencioso ainda existe; `storeError` agora aparece em Hoje e em Ajustes.
- O download completo dos FITs no aparelho leva vários syncs. Enquanto isso, a nota de corridas antigas pode mudar de cor mais de uma vez.
- Verificação do BGTask real e do aviso de manhã segue pendente (herdada do plano 3).

## Provas e detecção

- A mediana da base de `RaceDetection` descarta corrida sem `fitProcessed`, e o filtro deveria valer só para o candidato.
- Faltam testes negativos para o ritmo 0,94× e para FC abaixo de 95% do limiar.
- `confirmRace` com id inexistente grava a decisão `.race` sem `RaceRecord`.
- `runDay` (Insights) duplica `activityDay` do Sync, e o `activityDay` do `InsightsStore` ignora `localDay`.
- `RaceCandidate.seconds` usa `duration` (tempo total), não o tempo em movimento.
- `avgSpeed` 0 explícito descarta a volta sem recalcular por `distance` e `timerSeconds`.
- `structureData` corrompido conta como corrida livre (fail-open).
- Import de exportação antiga, mais nova que o registro local, zera `manuallyUnlinked` (`RaceTransfer.apply` usa `?? false`).
- `confirmRace` não tem teste com prova já ligada a outra atividade.
- Os botões "Foi prova" e "Não foi" não desabilitam no toque e `try?` engole o erro sem log.
- O teste não cobre a chamada de `runPostSyncWork` dentro de `syncNow`.

## Previsão e histórico de provas

- Falta teste de split entre 150 e 365 dias com peso zero ao lado de prova, e do limite de 150 dias dos splits.
- Prova com atividade sem `distance` é descartada sem teste.
- Nada garante `raceHistoryDays` ≥ `yearDays` + `raceEffortWindowDays`.
- `TodayBuilder` passou a buscar 730 dias de histórico. O efeito em carga e A:C é desprezível, mas não tem teste.

## Zonas e régua

- A divergência de zonas aparece sem a barra do limiar quando não há samples, e não diz qual limiar usou.
- `ForEach(marks, id: \.bpm)` colide quando dois pisos são iguais.
- `WorkoutAnalysisContext.day` usa `Day.today` como fallback, e o Sync usa `ActivityTime.day(of:)`.
- `ZoneRulerData.make(activityFloors:)` não tem caller em produção.
- `zoneSeconds` supõe amostras ordenadas.
- `runningZones` duplica a escolha de esporte do Sync, e `watchZonesRecord` duplica `runningZonesSport`.
- O foco da carga mantém as zonas do relógio para atividade que não é corrida, sem teste do caso misturado.
- Corrida com FC ainda não recalculada some das somas até o refresh.
- `overallZone2PaceUsesTodayThreshold` só confere `!= nil`.
- `thresholdPace` e `thresholdHeartRate` usam o limiar atual, não as zonas.

## Nota guardada e backfill

- O cancelamento não se propaga no `Task.detached` do refresh.
- O `.task` da lista roda a cada appear (cerca de 165 ms).
- Falta teste do pool por janela e da busca binária.
- O fallback de Hoje usa `comparisonRecords`.
- `thresholdUsed` pode atrasar no background por causa do `limit`.
- Refresh pedido entre `finish()` e o save do delete pode correr junto.
- `watchZones.maxHeartRate` não entra na chave da nota quando todos os treinos têm limiar.
- `lastRefreshLeavesKeyOfLatestData` passa sem encadeamento.
- `try? await` descarta o erro do backfill de narrativa sem log.
- `onStep` é seam de teste na assinatura de produção (padrão `nil`).
- Falta verificar que o `@Query` da UI reflete a narrativa gravada.

## Narrativa

- O estado `.stable` proíbe só `betterWords[0]` e `worseWords[0]`; "melhorou" e "piorou" passam numa frase de tendência estável.
- Falta teste parametrizado de que o template passa no validador em todos os vereditos.

## Testes e fixtures

- O teste de valor inválido do limiar não exercita `0xFF` nem `0`.
- Assert redundante `processingVersion == 3` em `StructureSyncTests`.
- `FITZipBuilder.timeInZone` duplica `FITFixtureBuilder` (targets diferentes).
- `SchemaV4MigrationTests` não insere `SyncState` nem `DailyRecord`.
- O teste de launch falha por chave ausente, não por rede.
- `readinessDay` (`AppModel`) tem o mesmo nome de `TodayModel.readinessDay`.
- Ordem de imports e `MetricsTests` usando `TrainingCore` e `FITReader` de forma transitiva.
- Falta teste do ramo "mesmo dia atualiza registro" no histórico do limiar, e `runWithoutHeartRateKeepsEmpty` não confere `thresholdUsed`.

## Documentação e site

- README do repositório.
- Landing page. As duas estavam na spec e foram empurradas para o plano 5.
