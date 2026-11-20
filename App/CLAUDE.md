# App (SwiftUI)

Telas, modelos de tela e integrações do app de iPhone e iPad. `Widgets/` e `Shared/` seguem as mesmas regras. Cálculo novo vai para `Packages/TrainingKit`, não para cá: o app monta a tela a partir do que o pacote devolve.

## Organização

- Uma pasta por área (`Today/`, `Trainer/`, `Workouts/`, `Strength/`, `Races/`, `Settings/`...). O nome da área no código está em inglês; o texto da tela é pt-BR.
- Constantes ficam em `<Nome>Constants.swift` e tipos e structs de props em `<Nome>Types.swift`, ao lado do arquivo que usa. Não declarar constante nem tipo dentro da view.
- Componentes visuais vêm de `DesignSystem/` (`DSButton`, `DSChip`, `DSNotice`, `DSRow`, `DSStat`, `DSScreenHeader`...), com espaçamento e raio de `DSSpacing` e `DSRadius` (`DSMetrics.swift`). Antes de criar um componente, procure um equivalente lá.
- Cores e marca em `Brand/` (`BrandColors`, `BrandConstants`). Os logos oficiais de Garmin, MFIT, Strava e Claude não estão no repo: o passo "Brand logos" do `project.yml` copia de `~/.config/training-sync/brand-logos/`, e sem a pasta `BrandLogo.image(for:)` devolve nil e a tela usa o ícone SF. Serviço novo entra em `BrandLogoConstants.files`.
- Texto gerado usa Foundation Models no aparelho. Toda tela precisa funcionar sem o modelo, com o template dos mesmos números.
- Prescrição na tela é sempre por distância (km ou metros). A única exceção é o descanso parado entre blocos, em tempo. Detalhes em `docs/regras/prescricao.md`.

## Testes

Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`). Sem XCTest.

Rode só a suíte que a mudança tocou:

```bash
xcodegen generate
xcodebuild test -project trAIning.xcodeproj -scheme trAIning \
  -destination 'platform=iOS Simulator,name=trAIning testes' \
  -derivedDataPath DerivedData \
  -only-testing:AppTests/TodayModelTests
```

- Rode a suíte num simulador limpo. Os simuladores "trAIning iPhone 16 Pro Max" e "iPad Air 13-inch (M4)" têm dados e login do app, e o sync em segundo plano quebra os testes de sync. Crie um temporário (`xcrun simctl create "trAIning testes" com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-27-0`) e apague no fim.
- `scripts/dev-run.sh --test` roda a suíte inteira. Use só antes do merge.
- Testes de imagem (`*SnapshotTests`) renderizam com `ImageRenderer` e gravam PNG quando `SNAPSHOT_DIR` existe. Pelo `xcodebuild`, passe `TEST_RUNNER_SNAPSHOT_DIR=<pasta>` no ambiente.
- O esquema define `TRAINING_TEST_HOST=1` e o app não inicia sync quando roda como host de teste (`AppConstants.testHostEnvironmentVariable`).

## Layout

- Mudança visual começa num mock aprovado. Depois de implementar, tire print no iPhone e no iPad e compare com o mock antes de propor commit.
- Para abrir no simulador com dados reais: `scripts/dev-run.sh`, que copia `garmin-data/snapshot/` (fora do git) para o simulador.
- Os prints de comparação usam o "trAIning iPhone 16 Pro Max" (tema escuro) e o "iPad Air 13-inch (M4)" (tema claro). O app restaura a rolagem, então arraste para o topo antes de capturar.
- Pasta `CaptureUITests/` e esquema `Capture` no `project.yml` são temporários de captura. Restaure o `project.yml` e apague a pasta antes do commit.
