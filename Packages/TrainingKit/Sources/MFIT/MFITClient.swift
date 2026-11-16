import Foundation
import GarminAPI

public struct MFITClient: Sendable {
    private typealias C = MFITConstants

    public let token: String
    private let transport: any HTTPTransport
    private let baseURL: URL

    public init(token: String, transport: any HTTPTransport, baseURL: URL = MFITConstants.baseURL) {
        self.token = token
        self.transport = transport
        self.baseURL = baseURL
    }

    public static func signIn(email: String, password: String, transport: any HTTPTransport, baseURL: URL = MFITConstants.baseURL) async throws -> String {
        var request = URLRequest(url: URL(string: baseURL.absoluteString + C.loginPath)!, timeoutInterval: C.timeout)
        request.httpMethod = "POST"
        request.setValue(C.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(MFITLoginBody(mail: email, senha: password))
        let (data, response) = try await transport.send(request)
        let dto = try? JSONDecoder().decode(MFITTokenDTO.self, from: data)
        guard (200..<300).contains(response.statusCode) else { throw MFITError.invalidLogin(dto?.message) }
        guard let token = dto?.token ?? dto?.data?.token, !token.isEmpty else { throw MFITError.missingToken }
        return token
    }

    public func teachers() async throws -> [MFITTeacher] {
        let data = try await send(C.teachersPath, method: "GET")
        let list: [MFITTeacherDTO]
        if let direct = try? JSONDecoder().decode([MFITTeacherDTO].self, from: data) {
            list = direct
        } else {
            list = try JSONDecoder().decode(MFITTeachersEnvelopeDTO.self, from: data).data ?? []
        }
        return list.map { dto in
            MFITTeacher(id: dto.id, name: [dto.name, dto.lastname].compactMap { MFITParser.clean($0) }.joined(separator: " "))
        }
    }

    public func switchTeacher(_ id: Int64) async throws -> String {
        let data = try await send(C.switchTeacherPath + String(id), method: "POST", body: Data("{}".utf8))
        let dto = try JSONDecoder().decode(MFITTokenDTO.self, from: data)
        guard let token = dto.token ?? dto.data?.token, !token.isEmpty else { throw MFITError.missingToken }
        return token
    }

    public func currentProgram(today: String) async throws -> MFITProgram? {
        let summaries = try JSONDecoder().decode([MFITProgramSummaryDTO].self, from: try await send(C.programsPath, method: "GET"))
        guard let chosen = Self.pick(summaries, today: today) else { return nil }
        let dto = try JSONDecoder().decode(MFITProgramDTO.self, from: try await send(C.programPath + String(chosen.id), method: "GET"))
        var sessions: [Int64: MFITSessionDTO] = [:]
        for ref in dto.workouts ?? [] {
            sessions[ref.id] = try JSONDecoder().decode(MFITSessionDTO.self, from: try await send(C.sessionPath + String(ref.id), method: "GET"))
        }
        return MFITParser.program(dto, sessions: sessions)
    }

    static func pick(_ summaries: [MFITProgramSummaryDTO], today: String) -> MFITProgramSummaryDTO? {
        let dated = summaries.map { (dto: $0, start: MFITParser.day($0.dataInicio), end: MFITParser.day($0.dataFim)) }
        let current = dated.filter { ($0.start.map { $0 <= today } ?? true) && ($0.end.map { today <= $0 } ?? true) }
        let pool = current.isEmpty ? dated : current
        return pool.max { ($0.start ?? "") < ($1.start ?? "") }?.dto
    }

    private func send(_ path: String, method: String, body: Data? = nil) async throws -> Data {
        var request = URLRequest(url: URL(string: baseURL.absoluteString + path)!, timeoutInterval: C.timeout)
        request.httpMethod = method
        request.setValue(C.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: C.authorizationHeader)
        request.httpBody = body
        let (data, response) = try await transport.send(request)
        if response.statusCode == 401 || response.statusCode == 403 { throw MFITError.unauthorized }
        guard (200..<300).contains(response.statusCode) else { throw MFITError.unexpectedResponse(status: response.statusCode) }
        return data
    }
}
