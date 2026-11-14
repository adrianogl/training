import GarminAPI
import Storage
import SwiftData
import SwiftUI
import TrainingCore
import WorkoutAnalysis

struct PlannedWorkoutDetailView: View {
    let plan: PlannedWorkout
    var week: [PlannedWorkout] = []
    @Environment(\.modelContext) private var context
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(AppConstants.weeklyGoalDefaultsKey) private var weeklyGoal = 0
    @State private var briefing: PlannedBriefing?
    @State private var weather: [HourlyWeather] = []
    @State private var course: CourseSuggestion?
    @State private var packed: Set<String> = []

    private typealias C = PlannedViewConstants

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) {
                header
                if let briefing {
                    content(briefing)
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.vertical, 16)
        }
        .background(BrandBackground())
        .task(id: plan.id) {
            rebuild()
            await loadExtras()
        }
    }

    private func rebuild() {
        let input = PlannedBriefingLoader.input(
            plan: plan, week: week, context: context, today: Day.today(),
            weeklyGoalKm: weeklyGoal, weather: weather, course: course
        )
        briefing = PlannedBriefingBuilder.briefing(input)
    }

    private func loadExtras() async {
        if let day = Day(iso: plan.day), Day.today().days(until: day) <= PlannedExtrasConstants.forecastDaysAhead,
           let coordinate = PlannedWeather.lastRunStart(context: context) {
            weather = await PlannedWeather.morning(day: day, coordinate: coordinate)
        }
        if let client = app.garminAccount.client {
            course = await PlannedCourseFinder.suggestion(client: client, plannedMeters: plan.estimatedMeters ?? 0)
        }
        rebuild()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateText).font(.subheadline).foregroundStyle(BrandColors.dim)
            HStack(spacing: 10) {
                Text(plan.title).font(.title2.bold()).foregroundStyle(BrandColors.text)
                if let tag = dayTag {
                    Text(tag)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandColors.onAccent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(BrandColors.accentFill, in: Capsule())
                }
            }
            HStack(spacing: 8) {
                TreinusBadge()
                Text(WorkoutConstants.plannedDetailSubtitle).font(.subheadline).foregroundStyle(BrandColors.dim)
            }
        }
    }

    @ViewBuilder
    private func content(_ briefing: PlannedBriefing) -> some View {
        statsRow(briefing.stats)
        summaryCard(briefing)
        if !briefing.comparison.isEmpty { comparisonCard(briefing) }
        let cards = cards(briefing)
        ForEach(Array(stride(from: 0, to: cards.count, by: 2)), id: \.self) { index in
            pair {
                card(cards[index], briefing)
                if index + 1 < cards.count { card(cards[index + 1], briefing) }
            }
        }
        triple {
            if let course = briefing.course { courseCard(course) }
            if !briefing.bestHours.isEmpty { hoursCard(briefing) }
            if let tip = briefing.watchTip { watchCard(tip) }
        }
    }

    private enum Card {
        case how, reps, expect, previous, attention, planB, carry, race
    }

    private func cards(_ briefing: PlannedBriefing) -> [Card] {
        var cards: [Card] = [.how]
        if !briefing.attention.isEmpty { cards.append(.attention) }
        if !briefing.reps.isEmpty { cards.append(.reps) }
        if !briefing.expectations.isEmpty { cards.append(.expect) }
        cards.append(.planB)
        if !briefing.previous.isEmpty { cards.append(.previous) }
        cards.append(.carry)
        if briefing.raceNote != nil { cards.append(.race) }
        return cards
    }

    @ViewBuilder
    private func card(_ card: Card, _ briefing: PlannedBriefing) -> some View {
        switch card {
        case .how: howCard(briefing)
        case .reps: repsCard(briefing)
        case .expect: expectCard(briefing)
        case .previous: previousCard(briefing)
        case .attention: listCard(C.attention, briefing.attention)
        case .planB: listCard(C.planB, briefing.planB)
        case .carry: carryCard(briefing.carry)
        case .race: textCard(C.race, briefing.raceNote ?? "")
        }
    }

    private func statsRow(_ stats: [BriefingStat]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: sizeClass == .regular ? max(stats.count, 1) : 2), alignment: .leading, spacing: 12) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.value).font(BrandFonts.number(26)).foregroundStyle(BrandColors.text).lineLimit(1).minimumScaleFactor(0.7)
                    Text(stat.label).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    private func summaryCard(_ briefing: PlannedBriefing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(C.summary).padding(.top, 0).padding(.bottom, 0)
            Text(briefing.summary).font(.body).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
            if !briefing.tags.isEmpty {
                FlowTags(tags: briefing.tags)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    private func howCard(_ briefing: PlannedBriefing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(C.how).padding(.top, 0).padding(.bottom, 0)
            PlannedShape(steps: plan.steps).frame(height: TodayConstants.planShapeHeight)
            ForEach(Array(briefing.phases.enumerated()), id: \.offset) { index, phase in
                if index > 0 { Divider().overlay(BrandColors.line) }
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(phase.when).font(BrandFonts.number(15)).foregroundStyle(BrandColors.text)
                        if let length = phase.length { Text(length).font(.caption2).foregroundStyle(BrandColors.dim) }
                    }
                    .frame(width: C.phaseColumn, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(phase.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
                        if !phase.detail.isEmpty {
                            Text(phase.detail).font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    private func repsCard(_ briefing: PlannedBriefing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(C.reps).padding(.top, 0).padding(.bottom, 0)
            ForEach(Array(briefing.reps.enumerated()), id: \.offset) { index, rep in
                if index > 0 { Divider().overlay(BrandColors.line) }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(rep.label).font(.subheadline.weight(.semibold)).frame(width: C.repLabelColumn, alignment: .leading)
                    Text(rep.pace).font(BrandFonts.number(16)).frame(width: C.repValueColumn, alignment: .leading)
                    if let heart = rep.heartRate {
                        Text(heart).font(BrandFonts.number(14)).foregroundStyle(BrandColors.rest).frame(width: C.repValueColumn, alignment: .leading)
                    }
                    Text(rep.note).font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(BrandColors.text)
            }
            if let note = briefing.repsNote {
                Text(note).font(.caption).foregroundStyle(BrandColors.dim)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    private func expectCard(_ briefing: PlannedBriefing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(C.expect).padding(.top, 0).padding(.bottom, 0)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 10) {
                ForEach(Array(briefing.expectations.enumerated()), id: \.offset) { _, stat in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.value).font(BrandFonts.number(22)).foregroundStyle(BrandColors.text)
                        Text(stat.label).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(BrandColors.line, lineWidth: 1))
                }
            }
            if let note = briefing.expectationNote {
                Text(note).font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    private func previousCard(_ briefing: PlannedBriefing) -> some View {
        let longest = briefing.previous.map(\.kilometers).max() ?? 1
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(C.previous).padding(.top, 0).padding(.bottom, 0)
            ForEach(Array(briefing.previous.enumerated()), id: \.offset) { _, run in
                HStack(spacing: 10) {
                    Text(run.day.chartDate.formatted(.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale)))
                        .font(.subheadline).lineLimit(1).fixedSize().frame(width: C.previousDateColumn, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule().fill(BrandColors.track)
                            .overlay(alignment: .leading) {
                                Capsule().fill(BrandColors.accentFill).frame(width: proxy.size.width * run.kilometers / longest)
                            }
                    }
                    .frame(height: 8)
                    Text("\(TodayText.decimal(run.kilometers, fractionDigits: 1)) km").font(BrandFonts.number(14)).frame(width: C.previousValueColumn, alignment: .trailing)
                    Text(WorkoutFormat.clock(run.paceSecondsPerKm)).font(BrandFonts.number(14)).frame(width: C.previousPaceColumn, alignment: .trailing)
                }
                .foregroundStyle(BrandColors.text)
            }
            if let note = briefing.previousNote {
                Text(note).font(.caption).foregroundStyle(BrandColors.dim)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    private func listCard(_ title: String, _ items: [BriefingItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title).padding(.top, 0).padding(.bottom, 0)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(color(item.tone)).frame(width: 8, height: 8).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                        Text(item.detail).font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    private func carryCard(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(C.carry).padding(.top, 0).padding(.bottom, 0)
            ForEach(items, id: \.self) { item in
                Button {
                    if packed.contains(item) { packed.remove(item) } else { packed.insert(item) }
                } label: {
                    Label(item, systemImage: packed.contains(item) ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline)
                        .foregroundStyle(packed.contains(item) ? BrandColors.accent : BrandColors.text)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    private func textCard(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title).padding(.top, 0).padding(.bottom, 0)
            Text(text).font(.subheadline).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    private func comparisonCard(_ briefing: PlannedBriefing) -> some View {
        PlanComparisonCard(rows: briefing.comparison, note: briefing.comparisonNote)
    }

    private func courseCard(_ course: CourseSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(C.course).padding(.top, 0).padding(.bottom, 0)
            ElevationLine(values: course.profile).frame(height: C.profileHeight)
            Text(course.laps > 1 ? String(format: C.courseLapsFormat, course.name, course.laps) : course.name)
                .font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
            Text(courseDetail(course)).font(.caption).foregroundStyle(BrandColors.dim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    private func courseDetail(_ course: CourseSuggestion) -> String {
        var text = String(format: C.courseLapFormat, TodayText.decimal(course.lapKilometers, fractionDigits: 1))
        if let gain = course.elevationGain { text += String(format: C.courseGainFormat, Int(gain.rounded())) }
        return text + C.courseFooter
    }

    private func hoursCard(_ briefing: PlannedBriefing) -> some View {
        let coolest = Set(PlannedBriefingBuilder.coolest(briefing.bestHours).map(\.hour))
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(C.hours).padding(.top, 0).padding(.bottom, 0)
            HStack(spacing: 6) {
                ForEach(briefing.bestHours, id: \.hour) { hour in
                    VStack(spacing: 2) {
                        Text("\(Int(hour.temperature.rounded()))°").font(BrandFonts.number(16))
                        Text("\(hour.hour)h").font(.caption2).foregroundStyle(BrandColors.dim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(coolest.contains(hour.hour) ? BrandColors.accentFill.opacity(0.18) : BrandColors.track, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(coolest.contains(hour.hour) ? BrandColors.accentFill : .clear, lineWidth: 1.5))
                }
            }
            .foregroundStyle(BrandColors.text)
            if let note = briefing.bestHoursNote {
                Text(note).font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    private func watchCard(_ tip: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(C.watch).padding(.top, 0).padding(.bottom, 0)
            ZStack {
                Circle().fill(Color.black).overlay(Circle().strokeBorder(Color(white: 0.2), lineWidth: 5))
                VStack(spacing: 4) {
                    Text(plan.title.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(Color(red: 0.89, green: 1, blue: 0.1)).lineLimit(1)
                    PlannedShape(steps: plan.steps).frame(width: 80, height: 10)
                    Text(tip).font(.system(size: 8, weight: .semibold)).foregroundStyle(Color(red: 1, green: 0.76, blue: 0.3)).lineLimit(2).multilineTextAlignment(.center)
                }
                .padding(18)
            }
            .frame(width: C.watchSize, height: C.watchSize)
            .frame(maxWidth: .infinity)
            .environment(\.colorScheme, .dark)
            Text(C.watchFooter).font(.caption).foregroundStyle(BrandColors.dim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    @ViewBuilder
    private func pair<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: TodayConstants.rowSpacing) { content() }
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) { content() }
        }
    }

    @ViewBuilder
    private func triple<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: TodayConstants.rowSpacing) { content() }
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) { content() }
        }
    }

    private func color(_ tone: BriefingTone) -> Color {
        switch tone {
        case .good: BrandColors.accentFill
        case .info: BrandColors.fitness
        case .warn: BrandColors.attention
        case .bad: BrandColors.rest
        }
    }

    private var dayTag: String? {
        guard let day = Day(iso: plan.day) else { return nil }
        switch Day.today().days(until: day) {
        case 0: return WorkoutConstants.plannedToday
        case 1: return C.tomorrow
        default: return nil
        }
    }

    private var dateText: String {
        guard let day = Day(iso: plan.day) else { return plan.day }
        return day.chartDate.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(WorkoutConstants.locale))
    }
}

struct FlowTags: View {
    let tags: [BriefingTag]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            VStack(alignment: .leading, spacing: 6) { chips }
        }
    }

    private var chips: some View {
        ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
            Text(tag.text)
                .font(.caption.weight(.bold))
                .foregroundStyle(foreground(tag.tone))
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(foreground(tag.tone).opacity(0.14), in: Capsule())
        }
    }

    private func foreground(_ tone: BriefingTone) -> Color {
        switch tone {
        case .good: BrandColors.accent
        case .info: BrandColors.fitness
        case .warn: BrandColors.attention
        case .bad: BrandColors.rest
        }
    }
}

struct ElevationLine: View {
    let values: [Double]

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2, let low = values.min(), let high = values.max() else { return }
            let span = max(high - low, 10)
            var path = Path()
            for (index, value) in values.enumerated() {
                let point = CGPoint(x: size.width * Double(index) / Double(values.count - 1), y: size.height - (value - low) / span * size.height)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            var area = path
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.addLine(to: CGPoint(x: 0, y: size.height))
            area.closeSubpath()
            context.fill(area, with: .color(BrandColors.fitness.opacity(0.18)))
            context.stroke(path, with: .color(BrandColors.fitness), lineWidth: 2)
        }
        .accessibilityHidden(true)
    }
}
