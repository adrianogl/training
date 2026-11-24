import Foundation
import Insights
import TrainingCore

enum StrengthLiveText {
    static let onWatch = "● no relógio"
    static let time = "Tempo"
    static let heartRate = "FC"
    static let sets = "Séries"
    static let now = "Agora"
    static let rest = "Descanso"
    static let restOver = "Hora da série"
    static let paused = "Pausado no relógio"
    static let setColumn = "Série"
    static let doneColumn = "Feito"
    static let planColumn = "Plano"
    static let lastColumn = "Última"
    static let next = "próxima"
    static let none = "—"
    static let later = "Para depois"
    static let leftOut = "de fora"
    static let todayTitle = "Ao vivo · Força"
    static let skipAction = "↻ Pular · fazer depois"
    static let doNowAction = "Fazer agora"
    static let cancel = "Cancelar"
    static let sending = "Enviando ao relógio…"
    static let commandTimeout = "O relógio não respondeu. Confira se ele está por perto."
    static let upcoming = "A seguir"
    static let roundsSection = "Rodadas"
    static let bodyweightShort = "PC"
    static let bodyweightSuffix = " · PC"

    static func doingMain(_ target: String?) -> String {
        guard let target else { return none }
        if target.hasSuffix(bodyweightSuffix) { return String(target.dropLast(bodyweightSuffix.count)) + " reps" }
        return target.contains("×") ? target + " kg" : target
    }

    static func doingDetail(_ target: String?, last: String?) -> String {
        var parts: [String] = []
        if target?.hasSuffix(bodyweightSuffix) == true { parts.append("peso corporal") }
        if let last { parts.append("última " + last) }
        return parts.isEmpty ? "" : " · " + parts.joined(separator: " · ")
    }
    static let roundColumn = "Rod."
    static let lastShortColumn = "Últ."
    static let bodyweightToggle = "Peso corporal"
    static let remainingScope = "Séries que faltam"
    static let nextScope = "Só a próxima"
    static let sendToWatch = "Mandar ao relógio"
    static let kilogramUnit = "kg"
    static let noLoad = "sem carga"
    static let repsUnit = "repetições"
    static let saveCorrection = "Salvar correção"
    static let correctionNote = "Atualiza o resumo, as séries no Garmin Connect e a carga do próximo treino."
    static let bodyweightNote = "Vale também para os próximos treinos com este exercício."

    static func roundTitle(_ letter: String, number: Int, rounds: Int) -> String {
        "Bi-set \(letter) · rodada \(number) de \(rounds)"
    }

    static func roundSubtitle(_ markers: [String], rest: Int) -> String {
        markers.joined(separator: " + ") + ", sem descanso entre eles" + (rest > 0 ? " · desc. " + clock(rest) + " no fim" : "")
    }

    static func roundExerciseLine(_ exercise: LiveStrengthExercise) -> String {
        var parts = [target(exercise)]
        if let weight = exercise.weight, weight > 0 { parts.append(kilograms(weight) + " kg") } else if exercise.bodyweight { parts.append("peso corporal") }
        if let last = exercise.last.last?.weight, last > 0 { parts.append("última " + kilograms(last) + " kg") }
        return parts.joined(separator: " · ")
    }

    static func setsLeft(_ count: Int, last: Double?) -> String {
        let left = count == 1 ? "falta 1 série" : "faltam \(count) séries"
        return last.map { left + " · última vez " + kilograms($0) + " kg" } ?? left
    }

    static func correctionTitle(_ name: String, set: Int) -> String {
        name + " · série \(set)"
    }
    static let setsSection = "Séries"

    static func nowSetLine(card: LiveStrengthCard, now: LiveStrengthNow) -> String {
        var parts = ["série \(max(card.setNumber, 1)) de \(now.rounds)", target(now.exercise)]
        if now.restSeconds > 0 { parts.append("desc. " + clock(now.restSeconds)) }
        return parts.joined(separator: " · ")
    }

    static func doneSection(_ done: Int, total: Int) -> String {
        "Feitos · \(done) de \(total)"
    }

    static func remaining(_ item: LiveStrengthItem) -> String {
        let left = max(item.rounds - item.setsDone, 0)
        return left == 1 ? "falta 1 série" : "faltam \(left) séries"
    }
    static let disconnected = "Relógio desconectado: os botões voltam quando ele estiver por perto."

    static func commandNotice(_ command: StrengthLiveCommand, name: String) -> String {
        let short = LiveStrengthLive.shortName(name).lowercased()
        switch command {
        case .skip: return "✓ Relógio atualizado: \(short) ficou para depois"
        case .doNow: return "✓ Relógio atualizado: \(short) é o próximo"
        case .setWeight: return "✓ Relógio atualizado: carga de \(short)"
        }
    }

    static func skipConfirmation(done: Int, rounds: Int) -> String {
        "\(done) de \(rounds) séries feitas"
    }

    static func skipExplanation(remaining: Int) -> String {
        (remaining == 1 ? "A que falta vai" : "As \(remaining) que faltam vão") + " para o fim da fila. No fim, dá para fazer ou deixar de fora."
    }

    static let strength = "Força"
    static let volume = "Volume"
    static let duration = "Duração"
    static let averageHR = "FC média "
    static let exercises = "Exercícios"
    static let skipped = "pulado"
    static let same = "="
    static let watchSection = "Relógio"
    static let watchFallbackName = "Relógio"
    static let watchHintPrefix = "No relógio: "
    static let watchHintApp = "trAIning Força"
    static let watchHintSuffix = " › START. Esta tela vira o acompanhamento ao vivo."
    static let watchPendingHint = "Abra o trAIning Força no relógio com o iPhone por perto. O treino chega em alguns segundos."
    static let watchResend = "Enviar de novo"
    static let watchChoose = "Escolher relógio"
    static let watchNone = "Escolha o relógio para receber o treino e acompanhar as séries aqui"

    static func watchReady(_ title: String) -> String {
        title + " de hoje salvo no relógio · funciona sem o iPhone"
    }

    static func watchPending(_ title: String) -> String {
        title + " ainda não chegou ao relógio"
    }

    static func nextTitle(_ title: String, day: Day?) -> String {
        guard let day else { return "Próximo " + title }
        return "Próximo " + title + " · " + StrengthText.dayLabel(day)
    }

    static func nextLoad(_ load: LiveStrengthNextLoad) -> String {
        (load.rises ? "sobe para " : "fica em ") + kilograms(load.next) + " kg"
    }

    static func nextNote(rises: Bool) -> String {
        rises
            ? "Fechou todas as séries: sobe 2,5%, no mínimo 1 kg. O relógio já começa com essas cargas."
            : "Nenhum exercício com todas as séries fechadas: as cargas ficam iguais."
    }

    static func uploadChip(_ state: StrengthLiveUploadState) -> String {
        switch state {
        case .sent: "✓ séries no Garmin Connect"
        case .alreadyHadSets: "atividade já tinha séries"
        case .pending, .notFound: "enviando séries ao Garmin…"
        case .failed: "séries não enviadas"
        case .resend: "enviando a correção ao Garmin…"
        }
    }

    static func summaryHeader(_ start: Date) -> String {
        header(start) + " · " + start.formatted(.dateTime.hour().minute().locale(Locale(identifier: "pt_BR")))
    }

    static func volumeValue(_ volume: Double) -> String {
        volume.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "pt_BR")))
    }

    static func volumeChange(_ change: Double?) -> String? {
        guard let change else { return nil }
        let percent = Int((change * 100).rounded())
        return (percent > 0 ? "+" : percent < 0 ? "−" : "") + "\(abs(percent))% vs última"
    }

    static func offPlan(_ count: Int) -> String? {
        count == 0 ? nil : count == 1 ? "1 fora do plano" : "\(count) fora do plano"
    }

    static func durationValue(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60) : String(format: "%d:%02d", total / 60, total % 60)
    }

    static func change(_ change: LiveStrengthChange) -> String {
        switch change {
        case .asPlanned: same
        case .heavier(let kg): "+" + kilograms(kg) + " kg"
        case .lighter(let kg): "−" + kilograms(kg) + " kg"
        case .fewerReps(let reps): "−\(reps) reps"
        case .skipped: skipped
        }
    }

    static let doing = "Fazendo"

    static func header(_ day: Date) -> String {
        "Força · " + day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "pt_BR")))
    }

    static func itemDetail(_ item: LiveStrengthItem) -> String {
        let hasTarget = item.exercise.kind == .timed ? item.exercise.seconds != nil : item.exercise.reps != nil
        var parts = [hasTarget ? "\(item.rounds) × " + target(item.exercise) : "\(item.rounds) séries"]
        if let weight = item.exercise.weight, weight > 0 { parts.append(kilograms(weight) + " kg") }
        else if item.exercise.bodyweight { parts.append("peso corporal") }
        return parts.joined(separator: " · ")
    }

    static func nextLine(_ target: String?) -> String? {
        target.map { "próxima " + $0 + ($0.contains("×") ? " kg" : "") }
    }

    static func target(_ exercise: LiveStrengthExercise) -> String {
        let base = exercise.kind == .timed ? exercise.seconds.map { "\($0) s" } ?? none : exercise.reps.map { "\($0) reps" } ?? none
        return exercise.perSide ? base + " cada lado" : base
    }

    static func supersetHeader(_ letter: String, rounds: Int, rest: Int) -> String {
        var parts = ["BI-SET \(letter)", "\(rounds) rodadas"]
        if rest > 0 { parts.append("desc. " + clock(rest)) }
        return parts.joined(separator: " · ")
    }

    static func supersetDetail(_ item: LiveStrengthItem) -> String {
        var parts = [target(item.exercise)]
        if let weight = item.exercise.weight, weight > 0 { parts.append(kilograms(weight) + " kg") }
        else if item.exercise.bodyweight { parts.append("peso corporal") }
        return parts.joined(separator: " · ")
    }

    static func progress(_ item: LiveStrengthItem) -> String {
        "\(item.setsDone)/\(item.rounds)"
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func kilograms(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "pt_BR")))
    }
}
