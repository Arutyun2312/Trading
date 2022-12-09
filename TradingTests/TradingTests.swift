//
//  TradingTests.swift
//  TradingTests
//
//  Created by Arutyun Enfendzhyan on 13.05.22.
//

@testable import Trading
import XCTest

final class TradingTests: XCTestCase {
//    override func setUpWithError() throws {
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//    }
//
//    override func tearDownWithError() throws {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//    }

    @MainActor
    func testMinGainToInvest() async throws {
        let bot = TradeBot(symbol: .testSymbol)
        let q = 100.0
        UserAccountBot.shared.accountInfo = .init(makerCommission: 0, takerCommission: 0, buyerCommission: 0, sellerCommission: 0, canTrade: true, canWithdraw: true, canDeposit: true, updateTime: 100, accountType: "Type", balances: [], permissions: [])
        bot.parameters = .init(maxPercentProfit: 2, maxPercentLoss: 0.5, maxPercentProfitLoss: 0.2, minPercentToBuy: 1)
        bot.investQuote = 100
        try await bot.dateReceiver(data: .init(time: .now, price: 1, quantity: q))
        try await bot.dateReceiver(data: .init(time: .now, price: 2, quantity: q))
        await bot.buy(reason: .minPriceGain)
        try await bot.dateReceiver(data: .init(time: .now, price: 3, quantity: q))
        XCTAssertFalse(bot.hasEnoughProfit, "Actual profit: \(bot.profitPercent)")
        try await bot.dateReceiver(data: .init(time: .now, price: 6, quantity: q))
        XCTAssert(bot.hasEnoughProfit, "Actual profit: \(bot.profitPercent)")
    }

    @MainActor
    func testTooMuchLoss() async throws {
        let bot = TradeBot(symbol: .testSymbol)
        let q = 100.0
        UserAccountBot.shared.accountInfo = .init(makerCommission: 0, takerCommission: 0, buyerCommission: 0, sellerCommission: 0, canTrade: true, canWithdraw: true, canDeposit: true, updateTime: 100, accountType: "Type", balances: [], permissions: [])
        bot.parameters = .init(maxPercentProfit: 2, maxPercentLoss: 0.5, maxPercentProfitLoss: 0.2, minPercentToBuy: 1)
        bot.investQuote = 100
        try await bot.dateReceiver(data: .init(time: .now, price: 5, quantity: q))
        await bot.buy(reason: .minPriceGain)
        try await bot.dateReceiver(data: .init(time: .now, price: 4, quantity: q))
        try await bot.dateReceiver(data: .init(time: .now, price: 1, quantity: q))
        await bot.buy(reason: .minPriceGain)
        try await bot.dateReceiver(data: .init(time: .now, price: 0.1, quantity: q))
        XCTAssert(bot.tooMuchLoss)
        try await bot.dateReceiver(data: .init(time: .now, price: 7, quantity: q))
        XCTAssert(bot.hasEnoughProfit)
    }

    @MainActor
    func testTooMuchProfitLoss() async throws {
        let bot = TradeBot(symbol: .testSymbol)
        let q = 100.0
        UserAccountBot.shared.accountInfo = .init(makerCommission: 0, takerCommission: 0, buyerCommission: 0, sellerCommission: 0, canTrade: true, canWithdraw: true, canDeposit: true, updateTime: 100, accountType: "Type", balances: [], permissions: [])
        bot.parameters = .init(maxPercentProfit: 2, maxPercentLoss: 0.5, maxPercentProfitLoss: 0.2, minPercentToBuy: 1)
        bot.investQuote = 100
        try await bot.dateReceiver(data: .init(time: .now, price: 1, quantity: q))
        await bot.buy(reason: .minPriceGain)
        try await bot.dateReceiver(data: .init(time: .now, price: 7, quantity: q))
        try await bot.dateReceiver(data: .init(time: .now, price: 3, quantity: q))
        XCTAssert(bot.tooMuchProfitLoss, "Actual profit loss: \((bot.state.highestProfitPercent - bot.profitPercent).format())")
    }
    
    @MainActor
    func testHasEnoughProfit() async throws {
        let bot = TradeBot(symbol: .testSymbol)
        let q = 100.0
        UserAccountBot.shared.accountInfo = .init(makerCommission: 0, takerCommission: 0, buyerCommission: 0, sellerCommission: 0, canTrade: true, canWithdraw: true, canDeposit: true, updateTime: 100, accountType: "Type", balances: [], permissions: [])
        bot.parameters = .init(maxPercentProfit: 2, maxPercentLoss: 0.5, maxPercentProfitLoss: 0.2, minPercentToBuy: 1)
        bot.investQuote = 100
        try await bot.dateReceiver(data: .init(time: .now, price: 1, quantity: q))
        await bot.buy(reason: .minPriceGain)
        try await bot.dateReceiver(data: .init(time: .now, price: 7, quantity: q))
        try await bot.dateReceiver(data: .init(time: .now, price: 5, quantity: q))
        XCTAssert(bot.hasEnoughProfit, "Actual profit: \(bot.profitPercent.format())")
    }
    
    @MainActor
    func testReinvest() async throws {
        let bot = TradeBot(symbol: .testSymbol)
        let q = 100.0
        UserAccountBot.shared.accountInfo = .init(makerCommission: 0, takerCommission: 0, buyerCommission: 0, sellerCommission: 0, canTrade: true, canWithdraw: true, canDeposit: true, updateTime: 100, accountType: "Type", balances: [], permissions: [])
        bot.parameters = .init(maxPercentProfit: 2, maxPercentLoss: 0.5, maxPercentProfitLoss: 0.2, minPercentToBuy: 1, minPercentToBuyAfterSell: 0.5)
        bot.investQuote = 100
        try await bot.dateReceiver(data: .init(time: .now, price: 1, quantity: q))
        try await bot.dateReceiver(data: .init(time: .now, price: 2, quantity: q))
        XCTAssert(bot.action == .buy, "Action: \(bot.action?.rawValue ?? "wait")")
        await bot.buy(reason: .minPriceGain)
        try await bot.dateReceiver(data: .init(time: .now, price: 3, quantity: q))
        print("dip: \(bot.price.dip)")
        await bot.sellAll(reason: .hasEnoughProfit)
        print("dip: \(bot.price.dip)")
    }
}
