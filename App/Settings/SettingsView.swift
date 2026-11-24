import Storage
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Query private var syncStates: [SyncState]
    @State private var pastedKey = ""
    @State private var keyMessage: String?
    @State private var showsKeyHelp = false
    @State private var confirmsDelete = false
    @State private var deleteMessage: String?
    @AppStorage(BackgroundConstants.noticeEnabledDefaultsKey) private var noticeEnabled = BackgroundConstants.defaultNoticeEnabled
    @AppStorage(WorkoutNoticeConstants.enabledKey) private var workoutNoticeEnabled = WorkoutNoticeConstants.defaultEnabled
    @AppStorage(BackgroundConstants.noticeMinimumMinutesDefaultsKey) private var noticeMinimumMinutes = BackgroundConstants.defaultMinimumMinutes
    @AppStorage(AppConstants.appearanceDefaultsKey, store: .standard) private var appearance = AppearanceOption.system.rawValue
    @AppStorage(AccentThemeConstants.defaultsKey, store: .standard) private var accentTheme = AccentTheme.pista.rawValue
    @AppStorage(AppIconConstants.defaultsKey, store: .standard) private var iconStyle = AppIconStyle.system.rawValue
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
            ForEach(SettingsSection.allCases) { section in
                Section {
                    ForEach(section.groups.filter(isVisible)) { group in
                        if sizeClass == .regular {
                            Button { selection = group } label: { groupRow(group) }
                                .buttonStyle(.plain)
                                .listRowBackground(group == selection ? BrandColors.accentFill.opacity(0.18) : BrandColors.card)
                        } else {
                            NavigationLink(value: group) { groupRow(group) }
                                .listRowBackground(BrandColors.card)
                        }
                    }
                } header: {
                    if sizeClass != .regular, section == SettingsSection.allCases.first {
                        VStack(alignment: .leading, spacing: DSSpacing.sectionTop) {
                            DSScreenHeader(title: AppSection.settings.title)
                                .textCase(nil)
                            DSSectionTitle(section.title)
                                .padding(.leading, SettingsConstants.sectionHeaderInset)
                        }
                        .listRowInsets(EdgeInsets())
                    } else {
                        DSSectionTitle(section.title)
                    }
                }
            }
            SettingsVersionSection(summary: model.appUpdate.summary, build: AppBuildInfo().build)
            buildFooter
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.top, sizeClass == .regular ? nil : DSSpacing.s2, for: .scrollContent)
        .background(BrandBackground())
        .task { await model.account.refresh() }
        .navigationTitle(AppSection.settings.title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .toolbarVisibility(sizeClass == .regular ? .automatic : .hidden, for: .navigationBar)
    }

    private func isVisible(_ group: SettingsGroup) -> Bool {
        switch group {
        case .invites: model.account.user?.isAdmin == true
        case .garmin, .watch: model.watchKind?.usesGarmin != false
        default: true
        }
    }

    private var buildFooter: some View {
        let info = AppBuildInfo()
        return Group {
            if let line = info.footerLine() { Text(line) }
        }
        .font(.caption)
        .foregroundStyle(BrandColors.dim)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0))
    }

    private func groupRow(_ group: SettingsGroup) -> some View {
        HStack(spacing: 12) {
            groupIcon(group)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title).font(.body.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(status(group)).font(.caption).foregroundStyle(BrandColors.dim).lineLimit(1)
            }
            Spacer(minLength: 0)
            if isConnected(group) {
                Circle()
                    .fill(BrandColors.accent)
                    .frame(width: AppConstants.settingsStatusDotSize, height: AppConstants.settingsStatusDotSize)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func groupIcon(_ group: SettingsGroup) -> some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous)
        if let logo = BrandLogo.image(for: group) {
            Image(uiImage: logo)
                .resizable()
                .scaledToFill()
                .frame(width: AppConstants.settingsIconSize, height: AppConstants.settingsIconSize)
                .clipShape(shape)
                .accessibilityHidden(true)
        } else {
            Image(systemName: group.systemImage)
                .font(.system(size: SettingsConstants.iconSymbolSize, weight: .semibold))
                .foregroundStyle(group.brandTint == nil ? BrandColors.text : .white)
                .frame(width: AppConstants.settingsIconSize, height: AppConstants.settingsIconSize)
                .background(group.brandTint ?? BrandColors.iconTile, in: shape)
                .accessibilityHidden(true)
        }
    }

    private func isConnected(_ group: SettingsGroup) -> Bool {
        switch group {
        case .garmin: garminConnected
        case .mfit: model.mfitAccount.isSignedIn
        case .strava: model.strava.status.connected
        default: false
        }
    }

    private var garminConnected: Bool {
        model.garminAccount.isSignedIn || model.hasKey
    }

    private func status(_ group: SettingsGroup) -> String {
        switch group {
        case .account: model.account.user.map { "\($0.name) · \($0.email)" } ?? AccountConstants.accountTitle
        case .invites: InvitesConstants.summary
        case .device: model.watchKind?.title ?? ""
        case .garmin: garminStatus
        case .mfit: model.mfitAccount.isSignedIn ? MFITAccountConstants.statusConnected : MFITAccountConstants.statusDisconnected
        case .strava: model.strava.status.connected ? (model.strava.status.enabled ? StravaConstants.statusConnectedWithSummary : StravaConstants.statusConnected) : StravaConstants.statusDisconnected
        case .watch: model.remoteSync.hasWatchToken ? SettingsConstants.tokenActive : SettingsConstants.tokenMissing
        case .claude: model.remoteSync.mcpTokenCreatedAt == nil ? SettingsConstants.tokenMissing : SettingsConstants.tokenActive
        case .notice: [noticeEnabled ? String(format: SettingsConstants.morningNoticeFormat, noticeMinimumTime.wrappedValue.formatted(date: .omitted, time: .shortened)) : SettingsConstants.morningNoticeOff, workoutNoticeEnabled ? SettingsConstants.workoutNoticeOn : SettingsConstants.workoutNoticeOff].joined(separator: SettingsConstants.statusSeparator)
        case .appearance: [AppearanceOption(rawValue: appearance)?.title ?? "", AccentTheme.stored(accentTheme).title].joined(separator: SettingsConstants.statusSeparator)
        case .data: model.storeError == nil ? SettingsConstants.dataStored : SettingsConstants.dataInMemory
        case .licenses: LicensesConstants.summary
        }
    }

    private var garminStatus: String {
        guard let date = syncStates.first?.lastSync else {
            return garminConnected ? GarminAccountConstants.statusConnected : GarminAccountConstants.statusDisconnected
        }
        let locale = WorkoutConstants.locale
        let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(locale))
        guard !Calendar.current.isDateInToday(date) else { return String(format: GarminAccountConstants.syncedTodayFormat, time) }
        let day = date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(locale))
        return String(format: GarminAccountConstants.syncedFormat, "\(day), \(time)")
    }

    @ViewBuilder
    private func form(for group: SettingsGroup) -> some View {
        Form {
            switch group {
            case .account:
                AccountSettingsView(model: model.account)
                RemoteSyncSection(model: model.remoteSync, part: .sync)
            case .invites:
                InvitesView(account: model.account)
            case .device:
                DeviceSettingsSection(model: model)
            case .garmin:
                GarminAccountSection(model: model.garminAccount)
                GarminZonesSection(model: model.garminZones) {
                    Task { await model.garminZones.sync(container: model.container, client: model.garminAccount.client) }
                }
                .task { model.garminZones.load(container: model.container) }
                keySection
                connectionSection
                syncSection
            case .mfit:
                MFITAccountSection(model: model.mfitAccount)
            case .strava:
                StravaSection(model: model.strava)
            case .watch:
                RemoteSyncSection(model: model.remoteSync, part: .watch)
            case .claude:
                ClaudeSettingsSection(model: model.remoteSync)
            case .notice:
                noticeSection
                workoutNoticeSection
            case .appearance:
                appearanceSection
            case .licenses:
                LicensesSection()
            case .data:
                dataSection
                if let storeError = model.storeError {
                    Section {
                        DSNotice(tone: .error, title: SettingsConstants.storeErrorTitle, text: String(format: SettingsConstants.storeErrorFormat, storeError))
                    } header: {
                        DSSectionTitle(SettingsConstants.storeSectionTitle)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BrandBackground())
        .navigationTitle(group.title)
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsKeyHelp) { GarminKeyHelpView() }
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
            DSSectionTitle("Chave da Personal API")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.hasKey ? "Há uma chave guardada no Keychain deste aparelho." : "Nenhuma chave guardada neste aparelho.")
                Button(GarminKeyHelpConstants.openLink) { showsKeyHelp = true }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BrandColors.accent)
            }
        }
    }

    private var connectionSection: some View {
        Section {
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
                FailureView(failure: failure) { showsKeyHelp = true }
            }
        } header: {
            DSSectionTitle("Conexão")
        }
    }

    private var syncSection: some View {
        Section {
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
                FailureView(failure: failure) { showsKeyHelp = true }
            }
            LabeledContent("Último sync", value: lastSyncText)
        } header: {
            DSSectionTitle("Sincronização")
        }
    }

    private var noticeSection: some View {
        Section {
            Toggle("Aviso de prontidão", isOn: $noticeEnabled)
                .onChange(of: noticeEnabled) { _, enabled in
                    Task { await model.missingNight.update(hasNightData: model.todayReadinessComplete, now: .now) }
                    guard enabled else { return }
                    Task { await UserNotificationScheduler.requestAuthorization() }
                }
            DatePicker("Horário mínimo", selection: noticeMinimumTime, displayedComponents: .hourAndMinute)
                .disabled(!noticeEnabled)
        } header: {
            DSSectionTitle("Aviso de manhã")
        } footer: {
            Text("Avisa a prontidão do dia quando o HRV e o sono da noite chegam, nunca antes do horário mínimo. O iOS decide quando o app acorda, então em alguns dias o aviso não sai.")
        }
    }

    private var workoutNoticeSection: some View {
        Section {
            Toggle("Avisar ao terminar um treino", isOn: $workoutNoticeEnabled)
                .onChange(of: workoutNoticeEnabled) { _, enabled in
                    guard enabled else {
                        WorkoutFinishNotifier.shared.stop()
                        return
                    }
                    Task {
                        await UserNotificationScheduler.requestAuthorization()
                        await WorkoutFinishNotifier.shared.requestAccess()
                        WorkoutFinishNotifier.shared.start(model: model)
                    }
                }
        } header: {
            DSSectionTitle("Aviso de treino")
        } footer: {
            Text("Quando o relógio sincroniza, o Garmin Connect grava o treino no Apple Health e o app avisa com a nota e o ponto principal da análise. Precisa da integração do Garmin Connect com o Apple Health ligada.")
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        Section {
            Picker(AccentThemeConstants.modeTitle, selection: $appearance) {
                ForEach(AppearanceOption.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            DSSectionTitle(AccentThemeConstants.modeTitle)
        } footer: {
            Text(AccentThemeConstants.modeFooter)
        }
        Section {
            AccentThemePicker(selection: $accentTheme)
                .onChange(of: accentTheme) { _, raw in AppIconSwitcher.apply(AccentTheme.stored(raw), style: AppIconStyle.stored(iconStyle)) }
                .dsCardRow()
        } header: {
            DSSectionTitle(AccentThemeConstants.colorTitle)
        } footer: {
            Text(AccentThemeConstants.colorFooter)
        }
        Section {
            AppIconStylePicker(selection: $iconStyle, theme: AccentTheme.stored(accentTheme))
                .onChange(of: iconStyle) { _, raw in AppIconSwitcher.apply(AccentTheme.stored(accentTheme), style: AppIconStyle.stored(raw)) }
                .dsCardRow()
        } header: {
            DSSectionTitle(AppIconConstants.sectionTitle)
        } footer: {
            Text(AppIconConstants.sectionFooter)
        }
        Section {
            AccentThemePreview()
                .dsCardRow()
        } header: {
            DSSectionTitle(AccentThemeConstants.previewTitle)
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
            DSSectionTitle("Neste aparelho")
        }
    }

    private static func initialGroup(defaults: UserDefaults = .standard) -> SettingsGroup {
        #if DEBUG
        if let group = defaults.string(forKey: AppConstants.openSettingsGroupDefaultsKey).flatMap(SettingsGroup.init(rawValue:)) { return group }
        return defaults.bool(forKey: AppConstants.settingsScrollDefaultsKey) ? .account : .garmin
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
