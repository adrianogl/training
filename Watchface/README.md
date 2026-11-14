# Mostrador trAIning (Forerunner 965)

Mostrador Connect IQ com o layout Prontidão: anel de segundos, data, temperatura e umidade, bateria, hora com segundos, prontidão com régua (descanso, moderado, forte), VO2max com a variação de 3 meses, km da semana com barra feito/planejado/meta, treino de hoje com a estrutura colorida por zona e próxima prova com previsão e meta.

## De onde vem cada dado

| Dado | Fonte no relógio |
| --- | --- |
| Temperatura e umidade | `Weather.getCurrentConditions()` |
| Bateria | `System.getSystemStats().battery` |
| VO2max e km feitos na semana | complications do sistema (`Toybox.Complications`) |
| Prontidão, variação do VO2 em 3 meses, km planejados e meta da semana, treino de hoje, prova com meta e previsão | servidor de sync do app trAIning, buscado em background a cada 15 min e guardado em `Application.Storage` |
| Prova, meta semanal e previsão sem o app | configurações do mostrador no Garmin Connect e race predictor do relógio |

A prontidão ocupa o primeiro número, com o selo AI, e a cor segue a faixa: abaixo de 40 descanso, de 40 a 69 moderado, a partir de 70 forte. O treino de hoje e os km planejados só aparecem se a nota for do dia. A prova e a previsão vêm do app quando ele manda; sem isso, o mostrador usa as configurações e o race predictor da Garmin.

## Prontidão do app

1. No app trAIning do iPhone, gerar o token em Ajustes › Sincronização › Relógio.
2. No Garmin Connect do celular, abrir o mostrador e colar o token em Configurações › Token do relógio.

O mostrador busca a nota e os dados do mostrador em `GET /api/v1/watch/readiness` a cada 15 minutos, em background, pelo celular (Bluetooth) ou Wi-Fi. A nota só aparece se for do dia de hoje no relógio; depois da meia-noite volta "--" até chegar a nova. Sem token, com token revogado (401) ou sem nota no servidor (404), aparece "--". Sem rede, fica a última nota recebida, se for de hoje.

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
