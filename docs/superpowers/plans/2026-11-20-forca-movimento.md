# Força: movimento, observações e carga sugerida — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** mostrar o movimento de cada exercício de força com imagem em cascata, guardar avaliações e observações sem perda, sugerir a primeira carga e liberar o iPhone na horizontal.

**Architecture:** um arquivo de correspondência revisado (`exercise-media.json`) liga o `id` do catálogo às imagens embutidas no app; o desenho por `MovementPattern` fecha toda lista. Avaliações e observações são dois documentos JSON por conta, gravados em arquivo local no toque e sincronizados como blobs `preference` (`exerciseFeedback`, `exerciseNotes`), que o servidor já lê em formato `plain`. A carga sugerida é uma função pura no pacote `Insights`, usada pelo gerador do Treinador e pelos treinos do Claude.

**Tech Stack:** Swift 6 / SwiftUI (iOS 26), Swift Testing, pacote `TrainingKit` (`Insights`, `RemoteSync`), servidor Node/TypeScript (Vercel, Postgres, vitest), Python 3 para os scripts.

**Spec:** `docs/superpowers/specs/2026-11-20-forca-movimento-design.md` · Mock aprovado: https://claude.ai/artifact/HSTSgs9X4biNo3CUxhKEHh

## Global Constraints

- Sem comentários no código. Types em `<Nome>Types.swift`, constantes em `<Nome>Constants.swift`, ao lado da feature.
- Texto de tela em PT-BR, como no mock.
- Cantos concêntricos: card 26, interno 12 (`DSRadius`).
- Animação respeita `accessibilityReduceMotion`: desenho parado na posição de maior amplitude; fotos não alternam.
- Ordem das imagens: foto própria free-exercise-db → equivalente free-exercise-db → wger → desenho. O desenho está sempre no fim.
- Nada de casamento automático no app: só entradas revisadas do `exercise-media.json`.
- Avaliação e observação gravam no disco antes de qualquer rede e nunca são apagadas pela sincronização.
- Carga sugerida: só `StrengthGeneratorConstants.loadedEquipment`, só sem registro para o `id`, desconto 20%, arredondada para baixo; MFIT mantém a carga do professor.
- Imagens embutidas: total ≤ 40 MB sem nova aprovação do usuário.
- Commits: mostrar `git status`, `git diff --staged` e a mensagem; commitar só com aprovação explícita do usuário. Conventional Commits em PT-BR, sem rodapé de atribuição.
- Cada tela pronta é comparada com o mock antes do commit.

## Review Focus

- Academia sem sinal: avaliar e anotar offline; nada se perde e tudo sobe na próxima sincronização (teste na Task 4 e 5).
- iPhone e iPad da mesma conta editando notas do mesmo exercício: merge por entrada, a mais nova vence, nenhuma nota some (Task 5).
- Nome do MFIT com acento, caixa ou espaço diferente do catálogo ("Agachamento  Goblet") ainda casa (Task 2).
- Exercício com peso do corpo ou sem nenhum exercício do mesmo padrão no histórico: sem número, só o texto "comece leve" (Task 7).
- Tela do exercício na horizontal com o teclado aberto na observação: campo visível e salvar alcançável (Task 9, captura).

---

### Task 1: Arquivo de correspondência e imagens

**Files:**
- Create: `scripts/exercise-media.py`, `scripts/test_exercise_media.py`
- Create: `App/Strength/Media/exercise-media.json`, `App/Strength/Media/Images/` (jpg/gif), `App/Strength/Media/CREDITS.md`
- Modify: `project.yml` (recursos de `App/Strength/Media`), `README.md` (seção de scripts)

**Interfaces:**
- Produces: `exercise-media.json` no formato

```json
{"versao":1,"midias":{"SQUAT/GOBLET_SQUAT":[{"origem":"freeExerciseDb","quadros":["Goblet_Squat_0.jpg","Goblet_Squat_1.jpg"],"equivalente":false,"passos":["…"]},{"origem":"wger","quadros":["wger_203_gif.gif"],"autor":"philip","licenca":"CC-BY-SA 4.0","link":"https://wger.de/…"}]},"mfit":{"agachamento goblet":"SQUAT/GOBLET_SQUAT"},"padroes":{"squat":{"passos":["…"]}}}
```

- [ ] **Step 1:** testes em `scripts/test_exercise_media.py`: `test_norm_ignores_case_accents_spaces` (`norm("Agachamento  Goblet") == norm("agachamento goblet")`), `test_candidates_same_pattern_only` (equivalente nunca cruza `padrao`), `test_emit_keeps_only_reviewed` (entrada com `"revisado": false` não vai para o JSON final).
- [ ] **Step 2:** `python3 scripts/test_exercise_media.py` → FAIL.
- [ ] **Step 3:** `scripts/exercise-media.py candidatos` baixa as duas bases para `~/.cache/training/exercise-media/`, gera `tasks/exercise-media-candidatos.json` (por `id`: próprios, equivalentes por padrão+equipamento, wger), com `"revisado": false`. `scripts/exercise-media.py emitir` lê o arquivo revisado, copia/redimensiona imagens (lado maior 640 px, jpg qualidade 70; gif mantido) e grava `exercise-media.json` + `CREDITS.md`, imprimindo o total em MB.
- [ ] **Step 4:** `python3 scripts/test_exercise_media.py` → PASS.
- [ ] **Step 5:** gerar candidatos, revisar (marcar `revisado: true` só no que confere; tradução dos passos para PT-BR), emitir. Se o total passar de 40 MB, parar e trazer o número ao usuário.
- [ ] **Step 6:** commit `feat(forca): adiciona correspondência de imagens dos exercícios` (com aprovação).

### Task 2: Catálogo de mídia no app

**Files:**
- Create: `App/Strength/Media/ExerciseMediaCatalog.swift`, `ExerciseMediaTypes.swift`, `ExerciseMediaConstants.swift`
- Test: `AppTests/ExerciseMediaCatalogTests.swift`

**Interfaces:**
- Consumes: `exercise-media.json` (Task 1), `StrengthCatalog.exercise(_:)`, `CatalogExercise.pattern/equipment`.
- Produces:

```swift
enum ExerciseMediaSource: String, Codable, Sendable { case freeExerciseDb, wger, drawing }
struct ExerciseMedia: Codable, Sendable, Equatable, Identifiable { let id: String; let source: ExerciseMediaSource; let frames: [String]; let equivalent: Bool; let steps: [String]; let author: String?; let license: String?; let link: String?; let pattern: MovementPattern? }
enum ExerciseKey: Hashable, Codable, Sendable { case catalog(String), mfit(String) }
struct ExerciseMediaCatalog { static let shared: ExerciseMediaCatalog; init(data: Data); func media(for key: ExerciseKey, fallback: MovementPattern?) -> [ExerciseMedia]; func alternatives(for key: ExerciseKey, source: ExerciseMediaSource, excluding: Set<String>, limit: Int) -> [ExerciseMedia]; func key(forMFITName name: String, category: String?) -> ExerciseKey }
```

`ExerciseMedia.id` é `"\(source):\(frames[0])"` (desenho: `"drawing:\(pattern)"`).

- [ ] **Step 1:** testes: `goblet_lists_photos_then_wger_then_drawing`, `unknown_id_returns_only_drawing`, `mfit_name_with_accent_and_spaces_maps_to_catalog`, `mfit_unknown_name_uses_category_pattern_drawing` (categoria do MFIT → `MovementPattern` pela tabela em `ExerciseMediaConstants`), `alternatives_respect_pattern_and_limit_3`.
- [ ] **Step 2:** rodar `scripts/dev-run.sh --test` → FAIL.
- [ ] **Step 3:** implementar; JSON lido uma vez do bundle.
- [ ] **Step 4:** `scripts/dev-run.sh --test` → PASS.
- [ ] **Step 5:** commit (com aprovação).

### Task 3: Desenhos por padrão de movimento

**Files:**
- Create: `App/Strength/Media/ExercisePatternFigure.swift`, `ExercisePatternPoses.swift`, `ExercisePatternFigureConstants.swift`
- Test: `AppTests/ExercisePatternFigureSnapshotTests.swift`

**Interfaces:**
- Produces: `struct ExercisePatternFigure: View { init(pattern: MovementPattern) }`; `enum ExercisePatternPoses { static func poses(_ pattern: MovementPattern) -> (start: FigurePose, end: FigurePose) }` com `struct FigurePose: Equatable { var head, neck, hip, knee, ankle, toe, shoulder, elbow, hand: CGPoint; var weight: CGPoint? }`.

- [ ] **Step 1:** testes: `every_pattern_has_distinct_start_and_end` (16 `MovementPattern.allCases`), snapshot do `squat` e do `hinge` na posição final; `reduce_motion_shows_end_pose`.
- [ ] **Step 2:** rodar → FAIL.
- [ ] **Step 3:** `TimelineView(.animation)` interpolando as duas poses, ciclo 2,6 s, curva ease-in-out sem bounce, traço 5 pt em `BrandColors.text`, braço em `BrandColors.dim`, peso em `BrandColors.strength`; poses de `squat` e `hinge` copiadas do mock.
- [ ] **Step 4:** rodar → PASS; comparar snapshots com o mock.
- [ ] **Step 5:** commit (com aprovação).

### Task 4: Avaliações guardadas e sincronizadas

**Files:**
- Create: `App/Strength/Feedback/ExerciseFeedbackStore.swift`, `ExerciseFeedbackTypes.swift`, `ExerciseFeedbackConstants.swift`, `App/DeviceSync/ExerciseFeedbackSyncStore.swift`
- Modify: `App/AppModel.swift:120-128` (registrar o store), `App/Account/AccountScopeTypes.swift` (URL do arquivo)
- Test: `AppTests/ExerciseFeedbackTests.swift`

**Interfaces:**
- Consumes: `ExerciseKey`, `ExerciseMedia.id` (Task 2), `RemoteBlobStore`.
- Produces:

```swift
enum ExerciseFeedbackVerdict: String, Codable, Sendable { case matches, doesNotMatch }
enum ExerciseFeedbackStatus: String, Codable, Sendable { case pending, resolved }
struct ExerciseFeedback: Codable, Sendable, Equatable, Identifiable { let id: UUID; let exercise: ExerciseKey; let exerciseName: String; let mediaId: String; var verdict: ExerciseFeedbackVerdict; var chosenMediaId: String?; var noneMatched: Bool; var note: String?; let createdAt: Date; var updatedAt: Date; let workoutDay: String?; var status: ExerciseFeedbackStatus; var resolution: String?; var resolvedIn: String? }
struct ExerciseFeedbackStore { init(url: URL); func all() -> [ExerciseFeedback]; func save(_ entry: ExerciseFeedback); func latest(for key: ExerciseKey, mediaId: String) -> ExerciseFeedback?; func preferredMediaId(for key: ExerciseKey) -> String?; func merge(_ remote: [ExerciseFeedback]) -> Bool }
struct ExerciseFeedbackSyncStore: RemoteBlobStore  // kind .preference, id "exerciseFeedback"
```

- [ ] **Step 1:** testes: `save_writes_file_before_sync` (arquivo existe e contém a entrada sem engine), `pending_until_pushed_then_not_pending`, `push_failure_keeps_pending` (sem `markBlobsPushed`, nova chamada a `pendingBlobs()` devolve a entrada), `merge_keeps_union_newest_entry_wins`, `merge_never_deletes_local_only_entry`, `resolved_status_from_remote_is_applied`, `preferred_media_is_latest_chosen_alternative`.
- [ ] **Step 2:** rodar → FAIL.
- [ ] **Step 3:** arquivo JSON atômico (`.atomic`) no diretório da conta; documento do blob = lista completa; `updatedAt` do blob = maior `updatedAt` das entradas; estado de envio no `UserDefaults` da conta como em `ClaudeContextSyncStore`.
- [ ] **Step 4:** rodar → PASS.
- [ ] **Step 5:** commit (com aprovação).

### Task 5: Observações do exercício

**Files:**
- Create: `App/Strength/Notes/ExerciseNotesStore.swift`, `ExerciseNotesTypes.swift`, `App/DeviceSync/ExerciseNotesSyncStore.swift`
- Modify: `App/AppModel.swift` (registrar), `App/Trainer/TrainerStrengthContextBuilder.swift` (notas no contexto do Claude)
- Test: `AppTests/ExerciseNotesTests.swift`, `AppTests/TrainerStrengthContextTests.swift`

**Interfaces:**
- Produces: `struct ExerciseNote: Codable, Sendable, Equatable, Identifiable { let id: UUID; let exercise: ExerciseKey; var text: String; let createdAt: Date; var updatedAt: Date; var deleted: Bool }`; `struct ExerciseNotesStore { func notes(for key: ExerciseKey) -> [ExerciseNote]; func save(_ note: ExerciseNote); func delete(_ id: UUID); func merge(_ remote: [ExerciseNote]) -> Bool; func allActive() -> [ExerciseNote] }`; sync id `"exerciseNotes"`. Apagar marca `deleted = true` (a entrada continua no documento para o merge).

- [ ] **Step 1:** testes: `note_saved_offline_is_pending`, `two_devices_edit_same_exercise_both_notes_survive`, `same_note_edited_newest_wins`, `deleted_note_hidden_but_kept_for_merge`, `mfit_and_catalog_keys_share_notes_when_mapped` (nota salva em `.catalog("SQUAT/GOBLET_SQUAT")` aparece para o nome MFIT mapeado), `context_includes_notes_for_exercise` (o texto entra em `contexto` com o `id`).
- [ ] **Step 2:** rodar → FAIL.
- [ ] **Step 3:** implementar como a Task 4; no contexto do Claude, campo `observacoes: {id: [texto]}`, e o servidor (`server/src/mcp/strengthTypes.ts`) aceita o campo opcional.
- [ ] **Step 4:** rodar → PASS (inclui `npm --prefix server test`).
- [ ] **Step 5:** commit (com aprovação).

### Task 6: Tela do exercício

**Files:**
- Create: `App/Strength/Exercise/ExerciseDetailSheet.swift`, `ExerciseMediaCarousel.swift`, `ExerciseFeedbackSection.swift`, `ExerciseNotesSection.swift`, `ExerciseDetailText.swift`, `ExerciseDetailConstants.swift`, `ExerciseDetailTypes.swift`
- Modify: `App/Trainer/TrainerStrengthWorkoutView.swift:101-118` (linha tocável + miniatura), `App/Strength/StrengthBlockList.swift:27-48` (idem para MFIT; `block.note` vira obs. MFIT só leitura)
- Test: `AppTests/ExerciseDetailSnapshotTests.swift`

**Interfaces:**
- Consumes: Tasks 2–5 e `SuggestedLoad` (Task 7, opcional na tela: `nil` até a Task 7).
- Produces: `struct ExerciseDetailInput: Equatable { let key: ExerciseKey; let name: String; let dose: String; let load: String?; let suggestedLoad: SuggestedLoad?; let pattern: MovementPattern?; let mfitNote: String?; let workoutDay: String? }`; `struct ExerciseDetailSheet: View { init(input: ExerciseDetailInput) }`.

Textos fixos (mock): "A imagem mostra a execução certa?", "✓ Corresponde", "✕ Não corresponde", "Confirmada por você em %@", "Desfazer", "Alguma destas mostra o movimento?", "Buscar na wger", "Usar o desenho", "Conte o que está diferente:", "Salvar sugestão", "Observações", "+ Adicionar", "Você escolheu esta imagem", "%d de %d".

- [ ] **Step 1:** snapshots: carrossel na 1ª e 2ª imagem, depois de "Corresponde", alternativas abertas, "Usar o desenho" com campo, observações com nota e obs. MFIT; teste `does_not_match_moves_choice_and_saves_before_closing` (entrada no store antes do sheet fechar).
- [ ] **Step 2:** rodar → FAIL.
- [ ] **Step 3:** carrossel com `ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)`, alternância de 2 quadros a cada 0,9 s; avaliação refere `ExerciseMedia.id` da página atual; "Não corresponde" → alternativas (`source: .freeExerciseDb`, `limit: 3`), "Buscar na wger" troca por `.wger`; miniatura 44 pt com raio 10 na linha do treino.
- [ ] **Step 4:** rodar → PASS; capturar no simulador e comparar com o mock.
- [ ] **Step 5:** commit (com aprovação).

### Task 7: Carga sugerida

**Files:**
- Create: `Packages/TrainingKit/Sources/Insights/StrengthLoadSuggestion.swift`, `StrengthLoadSuggestionTypes.swift`, `StrengthLoadSuggestionConstants.swift`
- Modify: `Packages/TrainingKit/Sources/Insights/StrengthGeneratorTypes.swift` (`StrengthLoadRecord.day: String?`, `GeneratedExercise.suggestedLoad: SuggestedLoad?`), `StrengthGenerator.swift:132`, o caminho que monta os treinos do Claude (`App/Trainer/Claude/TrainerModel+Claude.swift`), `App/Trainer/TrainerStrengthText.swift`, `docs/regras/prescricao.md`
- Test: `Packages/TrainingKit/Tests/InsightsTests/StrengthLoadSuggestionTests.swift`

**Interfaces:**
- Produces:

```swift
public struct SuggestedLoad: Codable, Sendable, Equatable { public let weight: Double; public let baseId: String; public let baseWeight: Double; public let baseDay: String? }
public enum StrengthLoadSuggestion { public static func suggest(for exercise: CatalogExercise, history: [String: StrengthLoadRecord]) -> SuggestedLoad? }
```

Constantes: `firstTimeShare = 0.8`, `unilateralShare = 0.5`, `perHandShare = 0.5` (barra → halter/kettlebell), incrementos `barbell 2.5, machine 2.5, cable 2.5, dumbbell 1, kettlebell 2, medicineBall 1`. Base: mesmo `pattern`, mesmo `equipment` primeiro, depois só o par barra ↔ halter/kettlebell; registro mais recente (`day`). Outras combinações não sugerem.

- [ ] **Step 1:** testes com valores do spec: `rdl_barbell_40_to_single_leg_dumbbell_is_8` (40 → 20 → 10 → 8), `same_equipment_bilateral_discount_only` (goblet 16 → agachamento frontal com halter 12,8 → 12), `rounds_down_to_increment` (barra 2,5), `bodyweight_never_suggests`, `no_same_pattern_history_returns_nil`, `existing_record_is_not_overridden` (gerador usa `StrengthProgression.next`), `mfit_workouts_untouched`.
- [ ] **Step 2:** `swift test --package-path Packages/TrainingKit --filter StrengthLoadSuggestion` → FAIL.
- [ ] **Step 3:** implementar; no gerador, `weight = next(loads[id]) ?? suggestion?.weight` e preencher `suggestedLoad`; texto "%@ kg sugerida", base "Base: %@, %@ kg em %@", e "Primeira vez: comece leve e registre a carga" quando `loadedEquipment` e `nil`. Atualizar `docs/regras/prescricao.md` com a regra.
- [ ] **Step 4:** testes do pacote e do app → PASS.
- [ ] **Step 5:** commit (com aprovação).

### Task 8: Ferramentas de admin no MCP

**Files:**
- Modify: `server/src/mcp/mcpTools.ts`, `server/src/mcp/mcpText.ts`, `server/src/mcp/mcpConstants.ts`, `server/src/mcp/mcpStore.ts`
- Create: `server/src/mcp/feedbackTools.ts`, `server/src/mcp/feedbackTypes.ts`
- Test: `server/test/mcpFeedback.test.ts`

**Interfaces:**
- Consumes: blob `exerciseFeedback` de cada conta (formato da Task 4), `isAdmin(env, email)`.
- Produces: ferramentas `avaliacoes_imagens` (sem argumentos; lista pendentes de todas as contas: conta abreviada, exercício, imagem, veredito, alternativa, frase, data) e `resolver_avaliacao` (`{conta, id, resolucao, versao}`; muda status para `resolved` e `updatedAt` = agora, regrava o blob da conta). Para conta não admin, as duas não aparecem em `tools/list` e respondem erro.

- [ ] **Step 1:** testes: `non_admin_does_not_see_feedback_tools`, `lists_pending_from_two_accounts`, `resolve_updates_only_that_entry_and_keeps_others`, `notes_never_listed`.
- [ ] **Step 2:** `npm --prefix server test` → FAIL.
- [ ] **Step 3:** implementar sobre `readBlob`/`writeBlob` com o `accountId` de cada linha.
- [ ] **Step 4:** `npm --prefix server test && npm --prefix server run typecheck` → PASS.
- [ ] **Step 5:** commit (com aprovação); deploy na Vercel depois do merge e antes de instalar.

### Task 9: iPhone na horizontal

**Files:**
- Modify: `project.yml:52` → `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone: "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"`; telas que quebrarem.

- [ ] **Step 1:** gerar o projeto, rodar no "trAIning iPhone 16 Pro Max", girar e capturar cada aba (Hoje, Evolução, Treinos, Provas, Mais/Treinador/Ajustes) e a tela do exercício com teclado aberto.
- [ ] **Step 2:** corrigir altura fixa, sheet e barra de abas que quebrarem; nova captura.
- [ ] **Step 3:** publicar as capturas para aprovação do usuário; esperar o ok.
- [ ] **Step 4:** `scripts/dev-run.sh --test` → PASS; commit (com aprovação).

### Task 10: Fechamento

- [ ] README (funcionalidade, scripts, versão) e `server/landing/index.html` (força com imagens, observações, carga sugerida, horizontal).
- [ ] Suítes: `scripts/dev-run.sh --test`, `swift test --package-path Packages/TrainingKit`, `npm --prefix server test`, `npm --prefix server run typecheck`, `python3 scripts/test_exercise_media.py`.
- [ ] Revisão do branch inteiro, merge com aprovação, `scripts/release.sh`, deploy, instalar nos 3 aparelhos com `--no-activate`.
