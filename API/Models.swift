//
//  Models.swift
//  Trading
//
//  Created by Arutyun Enfendzhyan on 13.05.22.
//

import Foundation
import OrderedCollections

struct ServerTime: Codable {
    let serverTime: Date
}

struct ExchangeInfo: Codable {
    let symbols: [Symbol]
}

struct Symbol: Codable {
    let symbol, status, baseAsset, quoteAsset: String
    let isSpotTradingAllowed: Bool
    let orderTypes, permissions: [String]
    let filters: [Filter]
    var stepSize: Double? {
        guard let stepSize = filters.first(where: { $0.filterType == "LOT_SIZE" })?.stepSize else { return nil }
        return Double(stepSize)
    }

    var canSpot: Bool { isSpotTradingAllowed && permissions.contains("SPOT") }
    var canMarket: Bool { orderTypes.contains("MARKET") }

    static let testSymbol = Symbol(symbol: "TESTUSDT", status: "status", baseAsset: "TEST", quoteAsset: "USDT", isSpotTradingAllowed: true, orderTypes: ["MARKET"], permissions: ["SPOT"], filters: [.init(filterType: "LOT_SIZE", minPrice: nil, maxPrice: nil, tickSize: nil, multiplierUp: nil, multiplierDown: nil, avgPriceMins: nil, minQty: nil, maxQty: nil, stepSize: "1.000000", minNotional: nil, applyToMarket: nil, limit: nil, minTrailingAboveDelta: nil, maxTrailingAboveDelta: nil, minTrailingBelowDelta: nil, maxTrailingBelowDelta: nil, maxNumOrders: nil, maxNumAlgoOrders: nil)])
}

struct Filter: Codable {
    let filterType: String
    let minPrice, maxPrice, tickSize, multiplierUp: String?
    let multiplierDown: String?
    let avgPriceMins: Int?
    let minQty, maxQty, stepSize, minNotional: String?
    let applyToMarket: Bool?
    let limit, minTrailingAboveDelta, maxTrailingAboveDelta, minTrailingBelowDelta: Int?
    let maxTrailingBelowDelta, maxNumOrders, maxNumAlgoOrders: Int?
}

struct AccountAsset: Codable {}

struct TradeData: Codable {
    let tradeDataE: String
    let e: Int
    let s: String
    let tradeDataT: Int
    let p, q: String
    let b, a, t: Int
    let tradeDataM, m: Bool

    enum CodingKeys: String, CodingKey {
        case tradeDataE = "e"
        case e = "E"
        case s
        case tradeDataT = "t"
        case p, q, b, a
        case t = "T"
        case tradeDataM = "m"
        case m = "M"
    }
}

struct CandlestickData: Hashable, Codable {
    let eventType: EventType
    let eventTime: Date
    let symbol: String
    let candle: Candle

    enum CodingKeys: String, CodingKey {
        case eventType = "e"
        case eventTime = "E"
        case symbol = "s"
        case candle = "k"
    }
}

struct Candle: Hashable, Codable, CustomStringConvertible {
    let time = Date()
    @ToDouble var open: Double
    @ToDouble var close: Double
    @ToDouble var high: Double
    @ToDouble var low: Double

    enum CodingKeys: String, CodingKey {
        case open = "o", close = "c", high = "h", low = "l"
    }

    var description: String {
        "\(time.format())\nopen/close: \(open.format()) / \(close.format())\nlow/high: \(low.format()) / \(high.format())"
    }
}

struct Trade: Hashable, Codable, CustomStringConvertible {
    let time: Date
//    let marketMaker: Bool
    @ToDouble var price: Double
    @ToDouble var quantity: Double

    enum CodingKeys: String, CodingKey {
        case price = "p", quantity = "q",
//             marketMaker = "s",
             time = "E"
    }

    var description: String {
        "\(time.format())\nprice: \(price.format())\nqnt: \(quantity.format())"
    }
}

struct OrderBook: Hashable, Codable, CustomStringConvertible {
    let time = Date()
    let id: Int, symbol, bidPrice, bidQuantity, askPrice, askQuantity: String

    enum CodingKeys: String, CodingKey {
        case id = "u", symbol = "s", bidPrice = "b", bidQuantity = "B", askPrice = "a", askQuantity = "A"
    }

    var description: String {
        "\(time.format())\nbid price/qnt: \(bidPrice.double.format()) / \(bidQuantity.double.format())\nask price/qnt: \(askPrice.double.format()) / \(askQuantity.double.format())"
    }
}

enum EventType: String, Codable {
    case candle = "kline", trade
}

struct PercentageChange: CustomStringConvertible {
    init(open: Double, close: Double, low: Double, high: Double) {
        self.open = open
        self.close = close
        self.low = low
        self.high = high
    }

    init() {
        self.open = 0
        self.close = 0
        self.low = 0
        self.high = 0
    }

    var open, close, low, high: Double

    var description: String {
        "open: \(open * 100)%\nclose: \(close * 100)%\nlow: \(low * 100)%\nhigh: \(high * 100)%"
    }
}

// MARK: - AccountInfo

struct AccountInfo: Hashable, Codable {
    let makerCommission, takerCommission, buyerCommission, sellerCommission: Int
    let canTrade, canWithdraw, canDeposit: Bool
    let updateTime: Int
    let accountType: String
    var balances: OrderedSet<Balance>
    let permissions: [String]

    subscript(asset: String) -> Balance? {
        get { balances.first { $0.asset == asset } }
        set {
            if let old = self[asset] {
                balances.remove(old)
            }
            guard let new = newValue else { return }
            balances.append(new)
        }
    }
}

// MARK: - Balance

struct Balance: Hashable {
    init(asset: String, free: Double, locked: Double) {
        self.asset = asset
        self.free = free
        self.locked = locked
    }

    let asset: String
    @ToDouble var free: Double
    @ToDouble var locked: Double

    enum CodingKeys: String, CodingKey {
        case asset, locked, free
    }
}

extension Balance: Codable {
    init(from decoder: Decoder) throws {
        enum StreamCodingKeys: String, CodingKey {
            case asset = "a", locked = "l", free = "f"
        }
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let asset = try container.decode(String.self, forKey: .asset)
            let _free = try container.decode(ToDouble.self, forKey: .free)
            let _locked = try container.decode(ToDouble.self, forKey: .locked)
            self.init(asset: asset, free: _free.wrappedValue, locked: _locked.wrappedValue)
        } catch {
            let container = try decoder.container(keyedBy: StreamCodingKeys.self)
            let asset = try container.decode(String.self, forKey: .asset)
            let _free = try container.decode(ToDouble.self, forKey: .free)
            let _locked = try container.decode(ToDouble.self, forKey: .locked)
            self.init(asset: asset, free: _free.wrappedValue, locked: _locked.wrappedValue)
        }
    }
}

enum Side: String, Codable { case buy = "BUY", sell = "SELL" }

struct ExecutionReport: Equatable, Codable {
    let clientOrderId: ShortUUID
    let eventType: String
    let executionType, symbol: String
    let orderStatus: String
    let side: Side

    var price: Double { quoteQuantity / quantity } // apparently binance sent p = 0, therefore calculate manually
    @ToDouble var quantity: Double
    /// Cumulative quote asset transacted quantity
    @ToDouble var quoteQuantity: Double

    enum CodingKeys: String, CodingKey {
        case eventType = "e", executionType = "x", orderStatus = "X", quoteQuantity = "Z", quantity = "q", symbol = "s", side = "S", clientOrderId = "c"
    }
}

struct AccountUpdate: Codable {
    let eventType: String
    let balances: [Balance]

    enum CodingKeys: String, CodingKey {
        case eventType = "e", balances = "B"
    }
}

struct BaseAccountUpdate: Codable {
    let eventType: String

    enum CodingKeys: String, CodingKey {
        case eventType = "e"
    }

    enum EventType: String, Codable {
        case executionReport, outboundAccountPosition
    }
}

struct ResponseError: Codable, Error {
    let code: Int, msg: String
}

struct TradeTicker: Codable {
    let symbol: String
    @ToDouble var priceChangePercent: Double

    enum CodingKeys: String, CodingKey {
        case symbol = "s", priceChangePercent = "P"
    }
}

struct ShortUUID {
    private static let base62chars = [Character]("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz").map(\.description)

    init() {
        let base: UInt32 = 62, length = 22
        self.code = (0 ..< length).map { _ in
            let random = Int(arc4random_uniform(base))
            return ShortUUID.base62chars[random]
        }
        .joined()
    }

    let code: String
}

extension ShortUUID: Hashable, CustomStringConvertible {
    var description: String { code }
}

extension ShortUUID: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.code = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        try code.encode(to: encoder)
    }
}
