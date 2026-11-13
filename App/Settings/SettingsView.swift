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

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            Form {
                keySection
                connectionSection
                syncSection
                RemoteSyncSection(model: model.remoteSync)
                    .id(RemoteSyncSettingsConstants.sectionAnchor)
                noticeSection
                dataSection
                if let storeError = model.storeError {
                    Section("Banco local") {
                        Text("Não abriu o banco local, o app está usando memória: \(storeError)")
                            .foregroundStyle(BrandColors.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BrandBackground())
            .navigationTitle("Ajustes")
            .task {
                guard Self.debugScrollsToRemoteSync() else { return }
                try? await Task.sleep(for: .milliseconds(600))
                proxy.scrollTo(RemoteSyncSettingsConstants.sectionAnchor, anchor: .top)
            }
            }
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

    private static func debugScrollsToRemoteSync(defaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        return defaults.bool(forKey: AppConstants.settingsScrollDefaultsKey)
        #else
        return false
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
