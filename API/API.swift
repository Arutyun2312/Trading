//
//  API.swift
//  Trading
//
//  Created by Arutyun Enfendzhyan on 13.05.22.
//

import AppKit
import CommonCrypto
import Foundation
import Starscream

final class API {
    static let shared = API()
    private init() {}

    let session = URLSession(configuration: .default)
    let decoder = { () -> JSONDecoder in
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    let encoder = { () -> JSONEncoder in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    func get(path: String, params: [String: String?] = [:]) async throws -> Data {
        var components = URLComponents(string: Strings.baseURL.appendingPathComponent(path).description)!
        components.queryItems = params.map { .init(name: $0.0, value: $0.1) }
        guard let url = components.url else { throw "Invalid url: \(components.description)" }
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = ["X-MBX-APIKEY": Strings.apiKey.rawValue]
        request.httpMethod = "get"
        return try await session.data(for: BinanceRequestAdapter().adapt(request)).0
    }

    func post(path: String, params: [String: String?] = [:]) async throws -> Data {
        var components = URLComponents(string: Strings.baseURL.appendingPathComponent(path).description)!
        components.queryItems = params.map { .init(name: $0.0, value: $0.1) }
        guard let url = components.url else { throw "Invalid url: \(components.description)" }
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = ["X-MBX-APIKEY": Strings.apiKey.rawValue]
        request.httpMethod = "post"
        return try await session.data(for: BinanceRequestAdapter().adapt(request)).0
    }

    func getServerTime() async throws -> Int {
        let time: [String: Int] = try await get(path: "api/v3/time").decode()
        return time["serverTime"]!
    }

    func ping() async throws {
        _ = try await get(path: "api/v3/ping")
    }

    func symbols() async throws -> [Symbol] {
        let info: ExchangeInfo = try await get(path: "api/v3/exchangeInfo").decode()
        return info.symbols
            .filter { [MAIN_ASSET].contains($0.quoteAsset) }
            .filter(\.canSpot)
            .filter(\.canMarket)
            .filter { $0.stepSize != nil }
            .unique { $0.baseAsset }.sorted(by: \.baseAsset)
    }

    func getAccountInfo() async throws -> AccountInfo {
        let time = try await getServerTime()
        let info: AccountInfo = try await get(path: "api/v3/account", params: ["timestamp": "\(time)"]).decode()

        return info
    }

    func buy(symbol: Symbol, quoteOrderQty: Double, id: ShortUUID) async throws { // https://binance-docs.github.io/apidocs/spot/en/#test-new-order-trade
        let time = try await getServerTime()
        let data = try await post(path: "api/v3/order", params: ["symbol": symbol.symbol, "side": Side.buy.rawValue, "type": "MARKET", "quoteOrderQty": "\(quoteOrderQty)", "timestamp": "\(time)", "newClientOrderId": id.description])
        print("Buy: \(String(data: data, encoding: .utf8) ?? "nil")")
        if let error = try? API.shared.decoder.decode(ResponseError.self, from: data) {
            throw error
        }
    }

    func sell(symbol: Symbol, quantity: Double, id: ShortUUID) async throws { // https://binance-docs.github.io/apidocs/spot/en/#test-new-order-trade
        let time = try await getServerTime()
        guard let stepSize = symbol.stepSize else { throw "Missing step size \(symbol)" }
        let q = String(format: "%.6f", (quantity / stepSize).rounded(.down) * stepSize)
        let data = try await post(path: "api/v3/order", params: ["symbol": symbol.symbol, "side": Side.sell.rawValue, "type": "MARKET", "quantity": q, "timestamp": "\(time)", "newClientOrderId": id.description])
        print("Sell: \(String(data: data, encoding: .utf8) ?? "nil")")
        if let error = try? API.shared.decoder.decode(ResponseError.self, from: data) {
            throw error
        }
    }

    func createSocket<T: Decodable>(streamName: String, dontDecodeData: Bool = false) -> AsyncThrowingStream<T, Error> {
        .init { cont in
            let url = URL(string: "wss://stream.binance.com:9443")!.appendingPathComponent("/ws/\(streamName)")
            let task = WebSocket(request: .init(url: url))
            task.onEvent = {
                switch $0 {
                case .text(let json):
                    do {
                        guard let data = json.data(using: .utf8) else { throw "Cannot convert string to data" }
                        if dontDecodeData {
                            cont.yield(data as! T)
                        } else {
                            cont.yield(try data.decode())
                        }
                    } catch {
                        cont.finish(throwing: error)
                    }
                case .cancelled, .disconnected:
                    cont.finish()
                case .connected:
                    print("Listening to: \(streamName)")
                default:
                    print($0)
                }
            }
            task.connect()
            cont.onTermination = { @Sendable _ in
                task.disconnect()
                print("Disconnected: \(streamName)")
            }
        }
    }

    func all24hChangeTracker() -> AsyncThrowingStream<TradeTicker, Error> { createSocket(streamName: "!ticker@arr") }
    func candleSocket(symbol: String) -> AsyncThrowingStream<CandlestickData, Error> { createSocket(streamName: "\(symbol.lowercased())@kline_1m") }
    func tradeSocket(symbol: String) -> AsyncThrowingStream<Trade, Error> { createSocket(streamName: "\(symbol.lowercased())@trade") }
    func userDataSocket() async throws -> AsyncThrowingStream<Data, Error> {
        let result: [String: String] = try await post(path: "api/v3/userDataStream").decode()
        guard let listenKey = result["listenKey"] else { throw "Missing listen key" }
        return createSocket(streamName: listenKey, dontDecodeData: true)
    }
}
