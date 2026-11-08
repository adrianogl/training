import Foundation

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func makeJWT(exp: Int?) -> String {
    let header = base64URL(Data(#"{"alg":"none"}"#.utf8))
    let payloadJSON = exp.map { #"{"exp":\#($0)}"# } ?? #"{"sub":"x"}"#
    return "\(header).\(base64URL(Data(payloadJSON.utf8))).sig"
}
