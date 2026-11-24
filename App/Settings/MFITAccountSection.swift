import MFIT
import SwiftUI

struct MFITAccountSection: View {
    let model: MFITAccountModel
    @State private var email = ""
    @State private var password = ""
    @State private var program: MFITProgram?
    @State private var days: [Int64: Int] = [:]
    @State private var confirmsDisconnect = false

    private typealias C = MFITAccountConstants
    private let schedule = StrengthSchedule()

    var body: some View {
        Section {
            if model.isSignedIn {
                LabeledContent(C.sectionTitle) {
                    Text(C.connected).foregroundStyle(BrandColors.accent)
                }
                Button(C.disconnect, role: .destructive) { confirmsDisconnect = true }
                    .confirmationDialog(C.disconnectTitle, isPresented: $confirmsDisconnect, titleVisibility: .visible) {
                        Button(C.disconnect, role: .destructive) { model.signOut() }
                        Button(C.cancel, role: .cancel) {}
                    } message: {
                        Text(C.disconnectMessage)
                    }
            } else {
                TextField(C.emailPlaceholder, text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField(C.passwordPlaceholder, text: $password)
                    .textContentType(.password)
                Button(model.isWorking ? C.signingIn : C.signIn) {
                    Task {
                        await model.signIn(email: email, password: password)
                        password = ""
                    }
                }
                .disabled(model.isWorking || email.isEmpty || password.isEmpty)
            }
            if let message = model.message {
                DSNotice(tone: .error, text: message)
            }
        } header: {
            DSSectionTitle(C.sectionTitle)
        } footer: {
            Text(C.footer)
        }
        .task(id: model.revision) {
            reloadProgram()
        }
        if model.isSignedIn, let program, !program.workouts.isEmpty {
            Section {
                ForEach(program.workouts) { workout in
                    Picker(workout.title, selection: dayBinding(workout)) {
                        Text(C.noDay).tag(StrengthConstants.noWeekday)
                        ForEach(C.weekdayNames.indices, id: \.self) { index in
                            Text(C.weekdayNames[index]).tag(index)
                        }
                    }
                }
            } header: {
                DSSectionTitle(C.daysTitle)
            } footer: {
                Text(C.daysFooter)
            }
        }
    }

    private func dayBinding(_ workout: MFITWorkout) -> Binding<Int> {
        Binding(
            get: { days[workout.id] ?? StrengthConstants.noWeekday },
            set: { value in
                schedule.setWeekday(value == StrengthConstants.noWeekday ? nil : value, for: workout)
                days[workout.id] = value
            }
        )
    }

    private func reloadProgram() {
        program = StrengthProgramStore().load().program
        days = Dictionary(uniqueKeysWithValues: (program?.workouts ?? []).map { ($0.id, schedule.weekday(for: $0) ?? StrengthConstants.noWeekday) })
    }
}
