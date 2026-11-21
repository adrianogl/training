# Cantos concêntricos

Vale para o app e para a landing (`server/landing/index.html`). Toda tela nova segue esta regra.

## Regra

Elemento com fundo ou borda dentro de outro: `raio interno = raio externo − padding`. Assim as duas curvas têm o mesmo centro.

| Token | Valor | Uso |
| --- | --- | --- |
| `DSRadius.card` | 26 | card (`brandCard()`), linha de lista com cara de card, mídia da tela do exercício |
| `BrandConstants.cardPadding` | 14 | padding do card |
| `DSRadius.medium` | 12 | bloco dentro do card (26 − 14) |
| `DSRadius.control` | 12 | botão, aviso e campo de formulário |
| `DSRadius.small` | 8 | elemento pequeno dentro de bloco |

`BrandConstants.cardCornerRadius` é o mesmo `DSRadius.card`. Um token de raio novo só entra se fechar a conta com o pai.

## SwiftUI

- `brandCard()` aplica `.containerShape` com o raio do card.
- Bloco interno usa `.dsInner` (`ConcentricRectangle` com mínimo de 12). O SwiftUI calcula o raio pelo padding real, então não há conta fixa como `card − 6` ou `card / 2`.
- Fora de um card, `.dsInner` usa a forma do container mais próximo. Numa linha de `Form`, por exemplo, segue a borda da seção.
- `ConcentricRectangle` não é `InsettableShape`: borda com `.stroke`, não `.strokeBorder`.

## Landing

A conta vai direto no CSS. O card do app desenhado no iPhone e no iPad (`.app-card`) usa 26, como no app.

## Exceções

- Padding maior ou igual ao raio externo: as curvas ficam longe uma da outra e o elemento usa o próprio token.
- Cápsulas, círculos, chips e barras de gráfico ficam fora da regra.
- Sheets e telas seguem o canto do aparelho pelo sistema.

Testes: `AppTests/ConcentricCornerTests.swift`.
