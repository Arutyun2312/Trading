//
//  TradeBot.swift
//  Trading
//
//  Created by Arutyun Enfendzhyan on 14.05.22.
//

import AppKit
import Combine
import Foundation
import MyExtensions
import OrderedCollections

private let maxEntryCount = 200
final class TradeBot: ObservableObject, Bot {
    let symbol: Symbol
    var isTestMode: Bool { symbol.baseAsset == Symbol.testSymbol.baseAsset }
    @Published var logs: [AnyLog] = []
    @Published var trades: OrderedSet<Trade> = []
    @Published var parameters = Params()
    @Published var state = State() {
        didSet {
            var oldValue = oldValue
            oldValue.bot = self
            states.append(oldValue)
        }
    }

    var states: [State] = []

    /// Amount to be invested as quote asset
    @Published var investQuote = 20.0
    @Published var notifyRise = true
    @Published var notifyDip = true
    @Published var isAuto = false
    @Published var buys: [ExecutionReport] = []
    @Published var expectedOrder: ShortUUID?
    var hasBought: Bool { state.hasBought }
    var priceChange: Double { state.priceChange }
    var profit: Double { state.profit }
    var profitPercent: Double { state.profitPercent }
    var shouldInvest: Bool { state.shouldInvest }
    var hasEnoughProfit: Bool { state.hasEnoughProfit }
    var tooMuchProfitLoss: Bool { state.tooMuchProfitLoss }
    var tooMuchLoss: Bool { state.tooMuchLoss }
    var reason: ActionReason? { state.reason }
    var isConfirmed: Bool? { reason.map { r in states.suffix(parameters.numberOfTradesToConfirm).allSatisfy { $0.reason?.side == r.side } } }
    var action: Side? { isConfirmed == true ? reason?.side : nil }

    var invested: Double { UserAccountBot.shared.accountInfo?[symbol.baseAsset]?.free ?? 0 }
    var investedInQuote: Double { invested * state.price.current }

    var responseSpeed: Double? {
        let suffix = trades.suffix(10)
        guard let first = suffix.first, let last = suffix.last, !suffix.isEmpty else { return nil }
        return (last.time.timeIntervalSince1970 - first.time.timeIntervalSince1970) / Double(suffix.count)
    }

    init(symbol: Symbol) {
        self.symbol = symbol
        state.bot = self
        trades.reserveCapacity(maxEntryCount)
        states.reserveCapacity(maxEntryCount)
    }

    @MainActor
    func buy(reason: ActionReason) async {
        guard expectedOrder == nil else { return }
        let id = ShortUUID()
        expectedOrder = id

        do {
            logs.append(.action(.init(reason: reason)))
            if isTestMode {
                UserAccountBot.shared.accountInfo?[symbol.baseAsset] = .init(asset: symbol.symbol, free: investQuote, locked: 0)
                buys.append(.init(clientOrderId: id, eventType: "executionReport", executionType: "TRADE", symbol: symbol.symbol, orderStatus: "FILLED", side: .buy, quantity: investQuote / state.price.current, quoteQuantity: investQuote))
                expectedOrder = nil
            } else {
                try await API.shared.buy(symbol: symbol, quoteOrderQty: investQuote, id: id)
            }
            state.highestProfitPercent = 0
        } catch {
            expectedOrder = nil
        }
    }

    @MainActor
    func sellAll(reason: ActionReason) async {
        guard expectedOrder == nil else { return }
        let id = ShortUUID()
        expectedOrder = id

        do {
            logs.append(.action(.init(reason: reason)))
            if profit > 0 { // new_invest = current + min = dip + min_old
                state.price.dip = state.price.current * (1 + parameters.minPercentToBuyAfterSell - parameters.minPercentToBuy)
            } else { // in order to avoid buying after selling and losing
                state.price.forceDip()
            }
            if isTestMode {
                buys = []
                expectedOrder = nil
            } else {
                try await API.shared.sell(symbol: symbol, quantity: invested, id: id)
            }
        } catch {
            expectedOrder = nil
        }
    }

    @MainActor
    func startSocket() async throws {
        for try await data in API.shared.tradeSocket(symbol: symbol.symbol) {
            guard !isTestMode else { continue }
            try await dateReceiver(data: data)
        }
    }

    @MainActor
    func dateReceiver(data: Trade) async throws {
        if trades.count == maxEntryCount {
            trades.removeFirst(150)
        }
        if states.count == maxEntryCount {
            states.removeFirst(150)
        }
        logs.append(.trade(data))
        onDataReceive(data: data)
        trades.append(data)
        await takeAction()
    }

    @MainActor
    func takeAction() async {
        guard isAuto, let reason = reason, isConfirmed == true else { return }

        switch reason.side {
        case .buy: await buy(reason: reason)
        case .sell: await sellAll(reason: reason)
        }
    }

    func onDataReceive(data current: Trade) {
        if trades.isEmpty {
            state.price.forceDip(current: current.price)
        }

        switch state.price.modifyPrice(current: current.price) {
        case .increased: makeIncreaseSound()
        case .dipped: makeDipSound()
        case .none: break
        }
        GlobalData.shared.objectWillChange.send() // recalculate bot order
    }

    struct Params: Equatable, Encodable {
        /// Usefult against cases, where drops too quickly, so gather money early
        var maxPercentProfit = 0.04
        var maxPercentLoss = 0.1
        var maxPercentProfitLoss = 0.01
        var minPercentToBuy = 0.02
        var minPercentToBuyAfterSell = 0.01
        var numberOfTradesToConfirm = 6

        var isInvalid: Bool {
            false
        }
    }

    struct Price: Equatable, Encodable {
        private(set) var current = 0.0
        var rise = 0.0, dip = 0.0

        mutating func modifyPrice(current: Double) -> Reaction? {
            let oldValue = self.current
            var reaction: Reaction?
            if current > oldValue {
                reaction = .increased
                if current > rise {
                    rise = current
                }
            } else if current < dip {
                forceDip(current: current)
                reaction = .dipped
            }
            self.current = current
            return reaction
        }

        mutating func forceDip(current: Double? = nil) {
            dip = current ?? self.current
            rise = dip
        }

        enum Reaction { case dipped, increased }
    }

    struct State {
        var bot: TradeBot!
        var price = Price() {
            didSet {
                if profitPercent > highestProfitPercent {
                    highestProfitPercent = profitPercent
                }
            }
        }

        var highestProfitPercent = 0.0

        var hasBought: Bool { !bot.buys.isEmpty }
        var priceChange: Double { price.current / price.dip - 1 }
        var profit: Double { bot.buys.sum { (price.current - $0.price) * $0.quantity } }
        var profitPercent: Double { bot.buys.sum { (price.current - $0.price) * $0.quantity / $0.quoteQuantity } }
        var shouldInvest: Bool { priceChange >= bot.parameters.minPercentToBuy && !hasBought }

        var hasEnoughProfit: Bool { profitPercent >= bot.parameters.maxPercentProfit }
        var tooMuchProfitLoss: Bool { highestProfitPercent - profitPercent >= bot.parameters.maxPercentProfitLoss }
        var tooMuchLoss: Bool { profitPercent < 0 && abs(profitPercent) > bot.parameters.maxPercentLoss }

        var reason: ActionReason? {
            if hasBought {
                if tooMuchLoss {
                    return .tooMuchLoss
                } else if hasEnoughProfit {
                    return .hasEnoughProfit
                } else if tooMuchProfitLoss {
                    return .tooMuchProfitLoss
                } else {
                    return .none
                }
            } else {
                if shouldInvest {
                    return .minPriceGain
                } else {
                    return .none
                }
            }
        }

        var action: Side? { reason?.side }
    }
}

extension TradeBot: Hashable, Identifiable {
    static func == (lhs: TradeBot, rhs: TradeBot) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { id.hash(into: &hasher) }
    var id: String { symbol.symbol }
}

extension TradeBot {
    var price: Price {
        get { state.price }
        set { state.price = newValue }
    }

    func makeIncreaseSound() {
        guard priceChange > parameters.minPercentToBuy, notifyRise else { return }
        NSSound.glass!.play()
    }

    func makeDipSound() {
        guard notifyDip else { return }
        NSSound.submarine!.play()
    }

    var silent: Bool {
        get { !notifyDip && !notifyRise }
        set {
            notifyDip = !newValue
            notifyRise = notifyDip
        }
    }
}

enum AnyLog: Encodable {
    case trade(Trade), action(Action)

    func encode(to encoder: Encoder) throws {
        switch self {
        case .trade(let data):
            try data.encode(to: encoder)
        case .action(let data):
            try data.encode(to: encoder)
        }
    }

    var asAction: Action? {
        guard case .action(let action) = self else { return nil }
        return action
    }
}

protocol Log: Encodable {
    var time: Date { get }
}

extension Trade: Log {}
struct Action: Log {
    let time = Date()
    let reason: ActionReason
    var side: Side { reason.side }
}

enum ActionReason: String, Codable {
    case tooMuchLoss, tooMuchProfitLoss, hasEnoughProfit, minPriceGain
    var side: Side {
        switch self {
        case .hasEnoughProfit, .tooMuchLoss, .tooMuchProfitLoss:
            return .sell
        case .minPriceGain:
            return .buy
        }
    }
}
