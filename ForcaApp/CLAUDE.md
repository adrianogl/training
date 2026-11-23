# ForcaApp (Monkey C)

App Connect IQ de força para o Forerunner 965 e o Venu 3/3S. O `README.md` explica o app, os botões e o build.

- Sem comentários no código. Constantes em `source/Constants.mc`, em módulos (`Palette`, `Timing`, `PlanKeys`, `LinkKeys`...).
- As chaves de `PlanKeys` e `EventKeys` são o contrato com o iPhone (`LiveStrengthWatch`, `LiveStrengthQueue.decodeWatchEvents`). Mudou uma, muda os dois lados e os testes de contrato no `TrainingKit`.
- Ação essencial só com `KEY_ENTER` e `KEY_ESC`, lidas em `onKey` de um `InputDelegate`. `BehaviorDelegate` engole as teclas depois do START no 965.
- Testes `(:test)` em `test/`, com `FakeServices` e `FakeRecorder`: `./test-local.sh` com o simulador aberto. Se o `monkeydo` não responder, feche e abra o simulador.
- Telas conferidas no simulador do 965 e do Venu 3 contra o mock aprovado. Tela nova precisa de mock aprovado.
- Não commitar `.prg`, `developer_key*`, `.FIT` nem log do relógio (`CIQ_LOG*`).
