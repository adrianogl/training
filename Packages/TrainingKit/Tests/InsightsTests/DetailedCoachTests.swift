import Foundation
import Testing
@testable import Insights

@Suite struct DetailedCoachTests {
    private func sections() throws -> [DetailedCoachSection] {
        let analysis = try #require(detailedScenario().analysis())
        return DetailedCoach.sections(for: analysis)
    }

    @Test func fivePartsComeFromTheirOwnFacts() throws {
        let sections = try sections()
        let parts = Dictionary(uniqueKeysWithValues: sections.map { ($0.part, $0) })

        #expect(sections.map(\.part) == [.workout, .context, .history, .next])
        #expect(parts[.workout]?.facts.contains { $0.contains("12,7 de 20,0 km planejados (63%)") } == true)
        #expect(parts[.workout]?.facts.contains("A FC foi de 159 para 170 bpm do primeiro ao último km.") == true)
        #expect(parts[.workout]?.facts.contains("Do km 1 ao km 9 o pace ficou entre 4:31 e 4:31/km.") == true)
        #expect(parts[.context]?.facts.first == "Comparado com 8 treinos parecidos dos últimos 90 dias.")
        #expect(parts[.context]?.facts.contains("O pace começou a cair no km 10; nos parecidos, a média foi o km 10.") == true)
        #expect(parts[.history]?.facts.count == 2)
        #expect(parts[.next]?.facts.count == 3)
        #expect(parts[.next]?.facts.first == "Gel no km 9. O pace de hoje caiu a partir do km 10. Nos treinos parecidos, a queda costuma vir no km 9.")
    }

    @Test func positivePartAppearsWhenThereIsSomethingGood() throws {
        let analysis = try #require(detailedScenario(name: "Rodagem", plan: nil).analysis())
        let positive = DetailedCoach.sections(for: analysis).first { $0.part == .positive }

        #expect(positive?.facts.contains { $0.hasPrefix("No pace de") } == true)
    }

    @Test func fallbackIsTheFactsInOrder() throws {
        let section = try #require(try sections().first { $0.part == .context })

        #expect(section.fallback == section.facts.joined(separator: " "))
    }

    @Test func generatedTextIsAcceptedWhenItOnlyCitesNumbersFromTheFacts() async throws {
        let section = try #require(try sections().first { $0.part == .context })
        let reply = "Foram 8 treinos parecidos nos últimos 90 dias. Você fez 63% da distância, contra 93% da média."

        #expect(await DetailedCoach.generate(section, generator: FakeGenerator(reply: reply)) == reply)
    }

    @Test func generatedTextWithAnInventedNumberIsRejected() async throws {
        let section = try #require(try sections().first { $0.part == .context })

        #expect(await DetailedCoach.generate(section, generator: FakeGenerator(reply: "Foram 12 treinos parecidos.")) == nil)
        #expect(await DetailedCoach.generate(section, generator: FakeGenerator(reply: "Foram 8 treinos parecidos!")) == nil)
    }

    @Test func eachPartHasItsOwnInstructionsAndCharacterLimit() {
        let instructions = Set(DetailedCoachPart.allCases.map { DetailedCoachConstants.instructions(for: $0) })

        #expect(instructions.count == DetailedCoachPart.allCases.count)
        #expect(DetailedCoachConstants.limits(for: .workout).maxCharacters > DetailedCoachConstants.limits(for: .positive).maxCharacters)
        #expect(DetailedCoachPart.allCases.map(\.title) == ["O treino", "No contexto dos seus treinos", "O que o histórico explica", "O lado bom", "Para o próximo"])
    }

    @Test func characterLimitFollowsThePart() async throws {
        let sections = try sections()
        let workout = try #require(sections.first { $0.part == .workout })
        let context = try #require(sections.first { $0.part == .context })
        let sentence = "O pace ficou estável nos primeiros quilômetros e a frequência cardíaca subiu devagar enquanto o atleta mantinha o mesmo ritmo do começo ao fim."
        let text = Array(repeating: sentence, count: 6).joined(separator: " ")

        #expect(text.count > 700 && text.count <= 900)
        #expect(await DetailedCoach.generate(workout, generator: FakeGenerator(reply: text)) == text)
        #expect(await DetailedCoach.generate(context, generator: FakeGenerator(reply: text)) == nil)
    }
}
