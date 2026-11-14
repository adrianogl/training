import SwiftUI

struct WorkoutChatSheet: View {
    let activityId: Int64
    let context: WorkoutChatContext
    var store = WorkoutChatStore.shared
    var autoQuestion: String?
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var question = ""
    @State private var thinking = false
    @State private var engine: WorkoutChatEngine?
    @FocusState private var focused: Bool

    private typealias C = WorkoutChatConstants

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            bubble(ChatMessage(role: .assistant, text: context.copy.welcome))
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                if index == 0 || !Calendar.current.isDate(messages[index - 1].date, inSameDayAs: message.date) {
                                    dayDivider(message.date)
                                }
                                bubble(message).id(message.id)
                            }
                            if thinking {
                                HStack(spacing: 8) { ProgressView(); Text(C.thinking).font(.caption).foregroundStyle(BrandColors.dim) }
                                    .id("thinking")
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                    }
                }
                Divider().overlay(BrandColors.line)
                composer
            }
            .background(BrandBackground())
            .navigationTitle(context.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(context.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(C.onDevice).font(.caption2).foregroundStyle(BrandColors.dim)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pronto") { dismiss() }.tint(BrandColors.accent)
                }
            }
        }
        .task {
            messages = await store.messages(for: activityId)
            engine = WorkoutChatEngine(context: context, history: messages)
            if let autoQuestion { send(autoQuestion) }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(context.suggestions, id: \.self) { suggestion in
                        Button(suggestion) { send(suggestion) }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandColors.text)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(BrandColors.track, in: Capsule())
                            .buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: 8) {
                TextField(context.copy.placeholder, text: $question, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onSubmit { send(question) }
                Button { send(question) } label: {
                    Image(systemName: "arrow.up").font(.body.weight(.bold)).foregroundStyle(BrandColors.onAccent)
                        .frame(width: 38, height: 38)
                        .background(BrandColors.accentFill, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || thinking)
            }
        }
        .padding(12)
        .disabled(thinking || engine == nil)
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !thinking, let engine else { return }
        question = ""
        messages.append(ChatMessage(role: .user, text: trimmed))
        thinking = true
        Task {
            let reply = await engine.answer(trimmed)
            messages.append(reply)
            thinking = false
            await store.save(messages, for: activityId)
        }
    }

    @ViewBuilder
    private func bubble(_ message: ChatMessage) -> some View {
        if message.role == .user {
            Text(message.text)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .foregroundStyle(.white)
                .background(BrandColors.fitness.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 60)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if let note = message.toolNote {
                    Label(note, systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2).foregroundStyle(BrandColors.dim)
                }
                Text(message.text).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
                if message.unverified {
                    Label(C.unverified, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(BrandColors.attention)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 40)
        }
    }

    private func dayDivider(_ date: Date) -> some View {
        let label = Calendar.current.isDateInToday(date) ? C.today
            : Calendar.current.isDateInYesterday(date) ? C.yesterday
            : date.formatted(.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale))
        return HStack {
            Rectangle().fill(BrandColors.line).frame(height: 1)
            Text("\(label), \(date.formatted(.dateTime.hour().minute()))").font(.caption2).foregroundStyle(BrandColors.dim).fixedSize()
            Rectangle().fill(BrandColors.line).frame(height: 1)
        }
    }
}
