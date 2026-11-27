# TrainingKit

Pacote Swift com toda a lógica do app: leitura do Garmin e do Apple Saúde, `.FIT`, sync, SwiftData, métricas, análise, treinador e textos. Roda no Mac (`macOS 26`), então os testes não precisam de simulador.

## Testes

```bash
swift test --package-path Packages/TrainingKit --filter TrainerEngineTests
swift test --package-path Packages/TrainingKit --filter InsightsTests
```

Sempre com `--filter` durante o trabalho; a suíte inteira fica para antes do merge. Swift Testing (`@Suite`, `@Test`, `#expect`), sem XCTest. Fixtures de rede ficam em `Tests/GarminAPITests/Fixtures` e `Tests/MFITTests/Fixtures`, e nunca podem ter dado real de conta.

## Módulos

Dependência só de cima para baixo; um módulo de baixo nunca importa um de cima.

| Módulo | Papel | Depende de |
| --- | --- | --- |
| `TrainingCore` | Tipos base (`Day`, zonas, unidades) | — |
| `GarminAPI` | Cliente do Garmin Connect, treinos planejados, envio de treino | `TrainingCore` |
| `FITReader` | Leitura de `.FIT` e estrutura do treino | `TrainingCore` |
| `Storage` | Modelos SwiftData e schema versionado | `TrainingCore` |
| `Metrics`, `Projections` | Carga, zonas, VO2, previsões | `TrainingCore`, `FITReader` |
| `WorkoutAnalysis` | Blocos, voltas, nota do treino | `FITReader`, `Storage` |
| `Narrative` | Texto a partir dos números | `WorkoutAnalysis`, `Metrics` |
| `Sync`, `HealthImport` | Sync incremental Garmin e Apple Saúde | vários |
| `Reports` | Relatório da semana | vários |
| `Insights` | Prontidão, treinador (`TrainerEngine*`), força, metas, provas | quase todos |
| `RemoteSync` | Cliente da API do servidor | `Storage`, `GarminAPI`, `Metrics` |
| `MFIT` | Treinos do MFIT Personal | `GarminAPI` |
| `trainingctl` | CLI que roda o sync e reprocessa um `store.sqlite` | vários |

Convenção de arquivo: `<Nome>.swift` com a lógica, `<Nome>Types.swift` com os tipos e `<Nome>Constants.swift` com os limites e números. Regra nova de treinador quase sempre é um `TrainerEngine<Tema>.swift` com constantes no `TrainerEngine<Tema>Constants.swift`.

## Regras de negócio

As regras do treinador e da análise estão escritas em `docs/regras/prescricao.md` e `docs/regras/analise.md`. Leia a seção que vai mudar antes de mexer em `Insights`, `WorkoutAnalysis` ou `Metrics`, e atualize o arquivo no mesmo commit.

O essencial da prescrição:

- Tudo em distância: aquecimento de 3 km, blocos em km ou metros, sem desaquecimento (exceto com "Ida e volta", ver `docs/regras/prescricao.md`). Limite de tamanho por tempo da literatura, convertido para km inteiro no pace atual.
- Exceção: descanso parado entre blocos vai em tempo.
- Meta de prova continua em tempo, porque é resultado.
- Força não reduz o volume de corrida.
- Quem muda regra de prescrição (zonas, ritmos, formato dos treinos) sobe `TrainerEngineConstants.prescriptionRulesVersion`. Sem isso, o plano salvo segue com os treinos antigos até o fim da semana.

## SwiftData

O schema é versionado em `Storage/SchemaV<N>.swift` + `SchemaV<N>Models.swift`, e `TrainingMigrationPlan` lista todos. Para mudar um `@Model`:

1. Copie o schema atual para `SchemaV<N+1>` com a mudança.
2. Aponte `TrainingSchema` para o novo e adicione o estágio no `TrainingMigrationPlan`.
3. Nunca edite um `SchemaV<N>` que já foi para os aparelhos. Isso quebra a abertura do banco de quem já tem o app.

## Catálogo de força

`Insights/GarminStrengthCatalogData.swift` (cerca de 370 KB) é gerado por `scripts/garmin-catalog.py` a partir do catálogo oficial da Garmin. Não edite à mão e não leia o arquivo inteiro; procure pelo id `CATEGORIA/EXERCICIO`. Correções de classificação vão em `scripts/garmin-catalog-overrides.json`. O MFIT usa os exercícios do professor, fora desse catálogo.

Depois de regenerar, atualize a fixture dos testes do MCP no servidor:

```bash
cd Packages/TrainingKit && WRITE_FIXTURES=1 swift test --filter StrengthCatalogFixtureTests
```

O comando grava `server/test/fixtures/strength-catalog.json`. Commit dos dois lados juntos.
