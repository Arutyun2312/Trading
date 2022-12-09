//
//  HMAC.swift
//  Trading
//
//  Created by Arutyun Enfendzhyan on 13.05.22.
//

import Alamofire
import CommonCrypto
import Foundation

//extension Data {
//    func hmac(base64key key: String) -> String {
//        let algorithm = CCHmacAlgorithm(kCCHmacAlgSHA256)
//        let keyLength = key.lengthOfBytes(using: .utf8)
//        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
//
//        var output = [UInt8](repeating: 0, count: digestLength)
//
//        key.withCString { keyPtr in
//            self.withUnsafeBytes { dataPtr in
//                CCHmac(algorithm, keyPtr, keyLength, dataPtr, self.count, &output)
//            }
//        }
//
//        let result = output.map { b in String(format: "%02x", b) }.joined()
//        return result
//    }
//}

extension String {
    func hmac(base64key key: String) -> String {
        let algorithm = CCHmacAlgorithm(kCCHmacAlgSHA256)
        let keyLength = key.lengthOfBytes(using: .utf8)
        let messageLength = lengthOfBytes(using: .utf8)
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)

        var output = [UInt8](repeating: 0, count: digestLength)

        key.withCString { keyPtr in
            self.withCString { messagePtr in
                CCHmac(algorithm, keyPtr, keyLength, messagePtr, messageLength, &output)
            }
        }

        let result = output.map { b in String(format: "%02x", b) }.joined()
        return result
    }
}

/// RequestAdapter to add authentification to requests with a `timestamp` parameter.
public struct BinanceRequestAdapter: RequestAdapter {
    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        completion(.init { try adapt(urlRequest) })
    }

    let apiKey = Strings.apiKey.rawValue
    let secretKey = Strings.secret.rawValue
    let receiveWindow: TimeInterval = 5000

    public func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        guard let url = urlRequest.url else { throw "unknown" }

        let query = (url.query ?? "").removingPercentEncoding ?? ""
        let body = String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) ?? ""

        if !query.contains("timestamp="), !body.contains("timestamp=") {
            return urlRequest
        }

        // Add apikey header
        var urlRequest = urlRequest
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-Mbx-Apikey")

        // Add receive window to query parameters
        var result: URLRequest
//        result = try URLEncoding.queryString.encode(urlRequest, with: ["recvWindow": receiveWindow])

        let signable = query.appending(body)
        let signature = signable.hmac(base64key: secretKey)

        // Add HMAC signature to query parameters
        result = try URLEncoding.queryString.encode(urlRequest, with: ["signature": signature])
        return result
    }
}
