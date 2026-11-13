import Foundation

public actor GarminAccountAuth {
    private typealias E = GarminAccountEndpoints

    private let transport: HTTPTransport

    public init(transport: HTTPTransport) {
        self.transport = transport
    }

    public func signIn(email: String, password: String) async throws -> GarminLoginResult {
        let body: [String: Any] = ["username": email, "password": password, "rememberMe": true, "captchaToken": ""]
        let response = try await ssoPost(E.loginURL, body: body)
        switch response.responseStatus?.type {
        case E.successStatus:
            guard let ticket = response.serviceTicketId else { throw GarminAccountError.exchangeFailed }
            return .signedIn(try await exchange(ticket: ticket))
        case E.mfaStatus:
            return .needsCode(GarminMFAChallenge(method: response.customerMfaInfo?.mfaLastMethodUsed ?? E.defaultMFAMethod))
        case E.invalidCredentialsStatus:
            throw GarminAccountError.invalidCredentials
        default:
            throw GarminAccountError.unexpectedResponse(status: 200)
        }
    }

    public func verify(code: String, challenge: GarminMFAChallenge) async throws -> GarminAccountSession {
        let body: [String: Any] = [
            "mfaMethod": challenge.method,
            "mfaVerificationCode": code,
            "rememberMyBrowser": true,
            "reconsentList": [String](),
            "mfaSetup": false,
        ]
        let response = try await ssoPost(E.mfaURL, body: body)
        guard response.responseStatus?.type == E.successStatus, let ticket = response.serviceTicketId else {
            throw GarminAccountError.invalidCode
        }
        return try await exchange(ticket: ticket)
    }

    public func refresh(_ session: GarminAccountSession) async throws -> GarminAccountSession {
        guard let refreshToken = session.refreshToken else { throw GarminAccountError.sessionExpired }
        let form = ["grant_type": E.refreshGrant, "client_id": session.clientId, "refresh_token": refreshToken]
        let (data, response) = try await transport.send(tokenRequest(clientId: session.clientId, form: form))
        if response.statusCode == 429 { throw GarminAccountError.rateLimited }
        guard (200..<300).contains(response.statusCode) else { throw GarminAccountError.sessionExpired }
        let token = try JSONDecoder().decode(GarminTokenResponse.self, from: data)
        return try makeSession(from: token, fallbackClientId: session.clientId, previousRefresh: refreshToken)
    }

    private func exchange(ticket: String) async throws -> GarminAccountSession {
        for clientId in E.clientIds {
            let form = [
                "client_id": clientId,
                "service_ticket": ticket,
                "grant_type": E.serviceTicketGrant,
                "service_url": E.serviceURL,
            ]
            let (data, response) = try await transport.send(tokenRequest(clientId: clientId, form: form))
            if response.statusCode == 429 { throw GarminAccountError.rateLimited }
            guard (200..<300).contains(response.statusCode),
                  let token = try? JSONDecoder().decode(GarminTokenResponse.self, from: data)
            else { continue }
            return try makeSession(from: token, fallbackClientId: clientId, previousRefresh: nil)
        }
        throw GarminAccountError.exchangeFailed
    }

    private func makeSession(from token: GarminTokenResponse, fallbackClientId: String, previousRefresh: String?) throws -> GarminAccountSession {
        let claims = JWTClaims(token.access_token)
        guard let expiry = claims.expiry else { throw GarminAccountError.exchangeFailed }
        return GarminAccountSession(
            accessToken: token.access_token,
            refreshToken: token.refresh_token ?? previousRefresh,
            clientId: claims.clientId ?? fallbackClientId,
            expiresAt: expiry
        )
    }

    private func ssoPost(_ url: URL, body: [String: Any]) async throws -> GarminSSOResponse {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "clientId", value: E.ssoClientId),
            URLQueryItem(name: "locale", value: E.locale),
            URLQueryItem(name: "service", value: E.serviceURL),
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(E.loginUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(E.ssoOrigin, forHTTPHeaderField: "Origin")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await transport.send(request)
        if response.statusCode == 429 { throw GarminAccountError.rateLimited }
        guard let decoded = try? JSONDecoder().decode(GarminSSOResponse.self, from: data) else {
            throw GarminAccountError.unexpectedResponse(status: response.statusCode)
        }
        return decoded
    }

    private func tokenRequest(clientId: String, form: [String: String]) -> URLRequest {
        var request = URLRequest(url: E.tokenURL)
        request.httpMethod = "POST"
        for (field, value) in E.nativeHeaders { request.setValue(value, forHTTPHeaderField: field) }
        request.setValue("Basic " + Data("\(clientId):".utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        var components = URLComponents()
        components.queryItems = form.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = Data((components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B").utf8)
        return request
    }
}

struct JWTClaims {
    let expiry: Date?
    let clientId: String?

    init(_ token: String) {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else {
            expiry = nil
            clientId = nil
            return
        }
        var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        let json = Data(base64Encoded: base64).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        expiry = (json?["exp"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        clientId = json?["client_id"] as? String
    }
}
