import Foundation
import GarminAPI
import Synchronization
import Testing
@testable import MFIT

private final class FixtureTransport: HTTPTransport {
    private let requests = Mutex<[URLRequest]>([])
    let routes: [String: (Int, Data)]

    init(routes: [String: (Int, Data)]) {
        self.routes = routes
    }

    var sent: [URLRequest] { requests.withLock { $0 } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.withLock { $0.append(request) }
        let key = request.url?.absoluteString.replacingOccurrences(of: "https://api.mfitpersonal.com.br", with: "") ?? ""
        let (status, data) = routes[key] ?? (404, Data())
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Suite struct MFITTests {
    private func transport() throws -> FixtureTransport {
        FixtureTransport(routes: [
            "/v2/client/workout/all": (200, try fixture("all")),
            "/v2/client/workout/?id=1001": (200, try fixture("program")),
            "/v2/client/workout/session?id=2001": (200, try fixture("session-2001")),
            "/v2/client/workout/session?id=2002": (200, try fixture("session-2002")),
            "/v2/client/workout/session?id=2003": (200, try fixture("session-2003")),
        ])
    }

    @Test func readsCurrentProgramWithPeriodAndOrder() async throws {
        let transport = try transport()
        let program = try #require(try await MFITClient(token: "t", transport: transport).currentProgram(today: "2026-11-16"))

        #expect(program.title == "Treino 7")
        #expect(program.start == "2026-11-13")
        #expect(program.end == "2026-12-18")
        #expect(program.teacherId == 18970)
        #expect(program.workouts.map(\.title) == ["Superiores", "MMII", "Full Body"])
        #expect(program.workouts.map(\.order) == [0, 1, 2])
        #expect(program.workouts[0].completions.map(\.day) == ["2026-11-16"])
        #expect(program.workouts[0].completions.first?.minutes == 46)
        #expect(program.workouts[0].completions.first?.effort == 3)
        #expect(transport.sent.allSatisfy { $0.value(forHTTPHeaderField: "authorization") == "t" })
    }

    @Test func parsesBlocksFromTeacherText() async throws {
        let program = try #require(try await MFITClient(token: "t", transport: try transport()).currentProgram(today: "2026-11-16"))
        let upper = program.workouts[0].blocks
        let legs = program.workouts[1].blocks

        #expect(upper[0].exercises.map(\.name) == ["Panturrilha unilateral no leg 45"])
        #expect(upper[0].exercises[0].detail == "15 rep")
        #expect(upper[0].exercises[0].reps == 15)
        #expect(upper[0].exercises[0].category == "CALF_RAISE")
        #expect(upper[0].sets == 3)
        #expect(upper[0].restSeconds == 30)

        #expect(upper[1].exercises.map(\.name) == ["Prancha Copenhagen", "Oblíquo Alternando com Wall Ball"])
        #expect(upper[1].note == "prancha conpenhagen 30 segundos cada lado + Oblíquo 20 rep")
        #expect(upper[1].restSeconds == 45)

        #expect(upper[2].exercises[0].detail == "10 rep")
        #expect(upper[2].exercises[0].weight == 14)
        #expect(upper[2].exercises[0].category == "BENCH_PRESS")
        #expect(upper[4].sets == 4)

        #expect(legs[0].exercises[0].category == "HIP_RAISE")
        #expect(legs[0].exercises[0].seconds == 45)
        #expect(legs[0].restSeconds == 60)
        #expect(legs[4].exercises[0].category == "LEG_EXTENSION")
        #expect(legs[4].restSeconds == 90)
        #expect(legs[5].exercises.map(\.category) == ["CALF_RAISE", "SQUAT"])
        #expect(legs[5].restSeconds == nil)
        #expect(program.workouts[2].blocks[1].exercises[0].detail == "10 rep")
        #expect(program.workouts[2].blocks.flatMap(\.exercises).allSatisfy { $0.category != nil })
    }

    @Test func picksProgramForToday() {
        let summaries = [
            MFITProgramSummaryDTO(id: 1, nome: "A", dataInicio: "Oct 1, 2026", dataFim: "Nov 12, 2026"),
            MFITProgramSummaryDTO(id: 2, nome: "B", dataInicio: "Nov 13, 2026", dataFim: "Dec 18, 2026"),
        ]
        #expect(MFITClient.pick(summaries, today: "2026-11-01")?.id == 1)
        #expect(MFITClient.pick(summaries, today: "2026-11-20")?.id == 2)
        #expect(MFITClient.pick(summaries, today: "2027-01-10") == nil)
    }

    @Test func signsInAndReportsInvalidLogin() async throws {
        let ok = FixtureTransport(routes: ["/auth/client": (200, Data(#"{"token":"abc"}"#.utf8))])
        #expect(try await MFITClient.signIn(email: "a@b.c", password: "x", transport: ok) == "abc")
        let body = try #require(ok.sent.first?.httpBody)
        #expect(String(decoding: body, as: UTF8.self).contains(#""senha":"x""#))

        let bad = FixtureTransport(routes: ["/auth/client": (400, Data(#"{"message":"Senha incorreta"}"#.utf8))])
        await #expect(throws: MFITError.invalidLogin("Senha incorreta")) {
            try await MFITClient.signIn(email: "a@b.c", password: "x", transport: bad)
        }
    }
}

@Suite struct MFITTeacherTests {
    private func programs(_ name: String, start: String, end: String) -> Data {
        Data(#"[{"id":1,"nome":"\#(name)","dataInicio":"\#(start)","dataFim":"\#(end)"}]"#.utf8)
    }

    @Test func switchTeacherReadsPlainStringToken() async throws {
        let transport = FixtureTransport(routes: ["/check/authenticate-to-user?id=7": (200, Data(#""novo.token.x""#.utf8))])
        #expect(try await MFITClient(token: "t", transport: transport).switchTeacher(7) == "novo.token.x")
        #expect(transport.sent.first?.httpMethod == "POST")
    }

    @Test func picksTeacherWithMostRecentCurrentProgram() async throws {
        let transport = TokenRoutedTransport(
            teachers: Data(#"[{"id":1,"name":"Jonathan"},{"id":2,"name":"Pedro"}]"#.utf8),
            switches: [1: "jonathan", 2: "pedro"],
            programs: [
                "inicial": programs("Antigo", start: "Jan 5, 2026", end: "Dec 31, 2026"),
                "jonathan": programs("Antigo", start: "Jan 5, 2026", end: "Dec 31, 2026"),
                "pedro": programs("Treino 7", start: "Nov 13, 2026", end: "Dec 18, 2026"),
            ]
        )
        let token = try await MFITClient(token: "inicial", transport: transport).tokenForActiveTeacher(today: "2026-11-17")
        #expect(token == "pedro")
    }
}

private final class TokenRoutedTransport: HTTPTransport {
    let teachers: Data
    let switches: [Int64: String]
    let programs: [String: Data]

    init(teachers: Data, switches: [Int64: String], programs: [String: Data]) {
        self.teachers = teachers
        self.switches = switches
        self.programs = programs
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        let token = request.value(forHTTPHeaderField: "authorization") ?? ""
        let body: Data
        if url.path.hasSuffix("check-users") {
            body = teachers
        } else if url.path.hasSuffix("authenticate-to-user"), let id = url.query?.split(separator: "=").last.flatMap({ Int64($0) }), let next = switches[id] {
            body = Data("\"\(next)\"".utf8)
        } else {
            body = programs[token] ?? Data("[]".utf8)
        }
        return (body, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
