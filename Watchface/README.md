# Mostrador trAIning (Forerunner 965)

Mostrador Connect IQ com o layout Prontidão: anel de segundos, data, temperatura e umidade, bateria, hora com segundos, VO2max, km da semana com barra de progresso, próxima prova com meta e previsão, e horário da próxima reunião.

## De onde vem cada dado

| Dado | Fonte no relógio |
| --- | --- |
| Temperatura e umidade | `Weather.getCurrentConditions()` |
| Bateria | `System.getSystemStats().battery` |
| VO2max, km da semana, próxima reunião, previsão de prova, Body Battery, training status | complications do sistema (`Toybox.Complications`) |
| Meta semanal, nome, data, distância e meta da prova | configurações do mostrador no app Connect IQ do celular |
| Prontidão, veredito e HRV | `Application.Storage`, preenchido pela ponte com o app do iPhone (ainda não existe) |

Sem a ponte, a linha da prontidão mostra o training status da Garmin e o terceiro número mostra a Body Battery no lugar do HRV. A previsão é a do relógio (race predictor da Garmin), por isso aparece sem o selo AI.

A complication de calendário devolve só o horário do próximo evento, sem o nome.

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
