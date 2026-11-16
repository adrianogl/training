# Mostrador trAIning (Forerunner 965)

Mostrador Connect IQ com a identidade do app: logo e data, temperatura e umidade, bateria, hora em Archivo com os segundos ao lado, prontidão com régua (descanso, moderado, forte), VO2max com a variação de 3 meses, km da semana com barra feito/planejado/meta e o próximo compromisso da agenda. No modo sempre ligado ficam só a data, a hora e o próximo compromisso.

## De onde vem cada dado

| Dado | Fonte no relógio |
| --- | --- |
| Temperatura e umidade | `Weather.getCurrentConditions()` |
| Bateria | `System.getSystemStats().battery` |
| VO2max e km feitos na semana | complications do sistema (`Toybox.Complications`) |
| Prontidão, variação do VO2 em 3 meses, km planejados e meta da semana, próximos eventos da agenda | servidor de sync do app trAIning, buscado em background a cada 15 min e guardado em `Application.Storage` |
| Meta semanal sem o app | configurações do mostrador no Garmin Connect |

A prontidão ocupa o primeiro número, com o selo AI, e a cor segue a faixa: abaixo de 40 descanso, de 40 a 69 moderado, a partir de 70 forte. Os km planejados só aparecem se a nota for do dia.

O app lê o Calendário do iPhone (Ajustes › Sincronização › Relógio › Mostrar a agenda no relógio) e manda até 3 eventos dos próximos 7 dias, sem os de dia inteiro e os cancelados. O mostrador mostra o primeiro que ainda não começou: HOJE com quanto falta, AMANHÃ ou o dia da semana. O título desce de fonte e, se ainda não couber, é cortado na última palavra com reticências.

A hora usa fontes bitmap da Archivo (OFL) em `resources/fonts`, só com os dígitos e os dois pontos: peso 900 na tela ativa e 700 no sempre ligado, para ficar abaixo do limite de 10% de pixels acesos no AMOLED.

## Prontidão do app

1. No app trAIning do iPhone, gerar o token em Ajustes › Sincronização › Relógio.
2. No Garmin Connect do celular, abrir o mostrador e colar o token em Configurações › Token do relógio.

O mostrador busca a nota e os dados do mostrador em `GET /api/v1/watch/readiness` a cada 15 minutos, em background, pelo celular (Bluetooth) ou Wi-Fi. A nota só aparece se for do dia de hoje no relógio; depois da meia-noite volta "--" até chegar a nova. Quando a Garmin não registra o sono, o app manda a prontidão da própria Garmin; se nem ela existir, manda só a semana e a agenda, e a nota fica "--". Sem token, com token revogado (401) ou sem nota no servidor (404), aparece "--". Sem rede, fica a última nota recebida, se for de hoje.

## Build

Pré-requisitos: Java, Connect IQ SDK (via SDK Manager) com o device `fr965` baixado e uma chave de desenvolvedor.

```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt

monkeyc -f monkey.jungle -d fr965 -o bin/TrainingFace.prg -y developer_key.der
connectiq
monkeydo bin/TrainingFace.prg fr965
```

Para instalar no relógio, copiar `bin/TrainingFace.prg` para `GARMIN/APPS` com o relógio ligado no Mac por USB.

No simulador, conferir o modo sempre ligado em Settings → Display Mode e o mapa de burn-in em View → Burn-in.

### Token sem a loja

Instalado pelo cabo, o mostrador não aparece nas configurações do Garmin Connect, então não há onde colar o token. Nesse caso, salve o token em `~/.config/training-sync/watch-token` e compile com `./build-local.sh`: ele copia o mostrador para uma pasta temporária, embute o token em `BuildToken.mc` e gera `bin/TrainingFace.prg`. No repositório, `BuildToken.WATCH_TOKEN` fica sempre vazio. Se a configuração do Garmin Connect tiver um token, ela tem prioridade.
