import Storage
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Query private var syncStates: [SyncState]
    @State private var pastedKey = ""
    @State private var keyMessage: String?
    @State private var confirmsDelete = false
    @State private var deleteMessage: String?
    @AppStorage(BackgroundConstants.noticeEnabledDefaultsKey) private var noticeEnabled = BackgroundConstants.defaultNoticeEnabled
    @AppStorage(BackgroundConstants.noticeMinimumMinutesDefaultsKey) private var noticeMinimumMinutes = BackgroundConstants.defaultMinimumMinutes
    @AppStorage(AppConstants.appearanceDefaultsKey) private var appearance = AppearanceOption.system.rawValue
    @AppStorage(AppConstants.weeklyGoalDefaultsKey) private var weeklyGoal = 0
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selection: SettingsGroup = SettingsView.initialGroup()

    var body: some View {
        if sizeClass == .regular {
            HStack(spacing: 0) {
                groupList
                    .frame(width: AppConstants.settingsListWidth)
                Divider().overlay(BrandColors.line)
                NavigationStack {
                    form(for: selection)
                }
            }
        } else {
            NavigationStack {
                groupList
                    .navigationDestination(for: SettingsGroup.self) { group in form(for: group) }
            }
        }
    }

    private var groupList: some View {
        List {
            CompactLogoHeader()
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            ForEach(SettingsGroup.allCases) { group in
                if sizeClass == .regular {
                    Button { selection = group } label: { groupRow(group) }
                        .buttonStyle(.plain)
                        .listRowBackground(group == selection ? BrandColors.accentFill.opacity(0.18) : BrandColors.card)
                } else {
                    NavigationLink(value: group) { groupRow(group) }
                        .listRowBackground(BrandColors.card)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BrandBackground())
        .navigationTitle("Ajustes")
    }

    private func groupRow(_ group: SettingsGroup) -> some View {
        HStack(spacing: 12) {
            Image(systemName: group.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: AppConstants.settingsIconSize, height: AppConstants.settingsIconSize)
                .background(group.tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title).font(.body.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(status(group)).font(.caption).foregroundStyle(BrandColors.dim).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private func status(_ group: SettingsGroup) -> String {
        switch group {
        case .garmin: [model.hasKey ? "sync \(lastSyncText)" : "sem chave da API", model.garminAccount.isSignedIn ? GarminAccountConstants.statusSignedIn : GarminAccountConstants.statusSignedOut].joined(separator: " · ")
        case .devices: model.remoteSync.isEnabled ? "Ligada" : "Desligada"
        case .watch: model.remoteSync.hasWatchToken ? "Token ativo" : "Sem token"
        case .notice: noticeEnabled ? "Ligado · a partir das \(noticeMinimumTime.wrappedValue.formatted(date: .omitted, time: .shortened))" : "Desligado"
        case .goals: weeklyGoal > 0 ? "\(weeklyGoal) km por semana" : "Sem meta semanal"
        case .appearance: AppearanceOption(rawValue: appearance)?.title ?? ""
        case .data: model.storeError == nil ? "Guardados neste aparelho" : "Usando memória"
        }
    }

    @ViewBuilder
    private func form(for group: SettingsGroup) -> some View {
        Form {
            switch group {
            case .garmin:
                GarminAccountSection(model: model.garminAccount)
                keySection
                connectionSection
                syncSection
            case .devices:
                RemoteSyncSection(model: model.remoteSync, part: .sync)
            case .watch:
                RemoteSyncSection(model: model.remoteSync, part: .watch)
            case .notice:
                noticeSection
            case .goals:
                goalsSection
            case .appearance:
                appearanceSection
            case .data:
                dataSection
                if let storeError = model.storeError {
                    Section("Banco local") {
                        Text("Não abriu o banco local, o app está usando memória: \(storeError)")
                            .foregroundStyle(BrandColors.danger)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BrandBackground())
        .navigationTitle(group.title)
    }

    private var goalsSection: some View {
        Section {
            Stepper(value: $weeklyGoal, in: AppConstants.weeklyGoalRange, step: AppConstants.weeklyGoalStep) {
                HStack {
                    Text("Volume semanal")
                    Spacer()
                    Text(weeklyGoal > 0 ? "\(weeklyGoal) km" : "sem meta").foregroundStyle(BrandColors.dim)
                }
            }
        } header: {
            Text("Metas")
        } footer: {
            Text("A meta semanal aparece no volume semanal e na semana de treino da Hoje.")
        }
    }

    private var keySection: some View {
        Section {
            SecureField("Cole a chave aqui", text: $pastedKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Salvar chave") { saveKey() }
                .disabled(pastedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let keyMessage {
                Text(keyMessage).font(.footnote).foregroundStyle(BrandColors.dim)
            }
        } header: {
            Text("Chave da Personal API")
        } footer: {
            Text(model.hasKey ? "Há uma chave guardada no Keychain deste aparelho." : "Nenhuma chave guardada neste aparelho.")
        }
    }

    private var connectionSection: some View {
        Section("Conexão") {
            Button("Testar conexão") {
                Task { await model.testConnection() }
            }
            .disabled(model.connectionStatus == .testing)
            switch model.connectionStatus {
            case .untested:
                EmptyView()
            case .testing:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Testando…").foregroundStyle(BrandColors.dim)
                }
            case .connected(let date):
                Label("Conectado em \(date.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(BrandColors.accent)
            case .failed(let failure):
                FailureView(failure: failure)
            }
        }
    }

    private var syncSection: some View {
        Section("Sincronização") {
            if case .running(let progress) = model.syncStatus {
                ProgressView(value: progress) {
                    Text("Sincronizando \(Int((progress * 100).rounded(.down)))%")
                }
                Button("Cancelar", role: .cancel) { model.cancelSync() }
            } else {
                Button("Sincronizar agora") {
                    Task { await model.syncNow(.settings) }
                }
            }
            if case .failed(let failure) = model.syncStatus {
                FailureView(failure: failure)
            }
            LabeledContent("Último sync", value: lastSyncText)
        }
    }

    private var noticeSection: some View {
        Section {
            Toggle("Aviso de prontidão", isOn: $noticeEnabled)
                .onChange(of: noticeEnabled) { _, enabled in
                    guard enabled else { return }
                    Task { await UserNotificationScheduler.requestAuthorization() }
                }
            DatePicker("Horário mínimo", selection: noticeMinimumTime, displayedComponents: .hourAndMinute)
                .disabled(!noticeEnabled)
        } header: {
            Text("Aviso de manhã")
        } footer: {
            Text("Avisa a prontidão do dia quando o HRV e o sono da noite chegam, nunca antes do horário mínimo. O iOS decide quando o app acorda, então em alguns dias o aviso não sai.")
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("Tema", selection: $appearance) {
                ForEach(AppearanceOption.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Aparência")
        } footer: {
            Text("\"Sistema\" segue o modo claro ou escuro do aparelho.")
        }
    }

    private var noticeMinimumTime: Binding<Date> {
        Binding {
            Calendar.current.date(byAdding: .minute, value: noticeMinimumMinutes, to: Calendar.current.startOfDay(for: .now)) ?? .now
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            noticeMinimumMinutes = (components.hour ?? 0) * BackgroundConstants.minutesPerHour + (components.minute ?? 0)
        }
    }

    private var dataSection: some View {
        Section {
            Button("Apagar dados locais", role: .destructive) { confirmsDelete = true }
                .disabled(model.syncStatus.isRunning)
                .confirmationDialog("Apagar todos os dados locais?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                    Button("Apagar", role: .destructive) { deleteData() }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Treinos, dados diários e provas saem deste aparelho. A chave continua no Keychain e o próximo sync baixa o histórico de novo.")
                }
            if let deleteMessage {
                Text(deleteMessage).font(.footnote).foregroundStyle(BrandColors.dim)
            }
        } header: {
            Text("Dados locais")
        }
    }

    private static func initialGroup(defaults: UserDefaults = .standard) -> SettingsGroup {
        #if DEBUG
        return defaults.bool(forKey: AppConstants.settingsScrollDefaultsKey) ? .devices : .garmin
        #else
        return .garmin
        #endif
    }

    private var lastSyncText: String {
        guard let date = syncStates.first?.lastSync else { return "nunca" }
        return date.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(WorkoutConstants.locale))
    }

    private func saveKey() {
        do {
            try model.saveKey(pastedKey)
            pastedKey = ""
            keyMessage = "Chave salva."
        } catch {
            keyMessage = "Não salvou no Keychain: \(error)"
        }
    }

    private func deleteData() {
        Task {
            do {
                try await model.deleteLocalData()
                deleteMessage = "Dados locais apagados."
            } catch {
                deleteMessage = "Não apagou: \(error)"
            }
        }
    }
}
