//
//  TradeBotView.swift
//  Trading
//
//  Created by Arutyun Enfendzhyan on 14.05.22.
//

import SwiftUI

struct TradeBotView: View {
    @ObservedObject var bot: TradeBot
    @State var error: Error?
    @State var custom = false
    @EnvironmentObject var globalData: GlobalData

    var body: some View {
        VStack(alignment: .leading) {
            Calculator()
            Divider()
            HStack(alignment: .top) {
                Button { globalData.bots.remove(bot) } label: {
                    Image(systemName: "multiply")
                }
                .foregroundColor(.red)
                Spacer()
                let symbol = bot.symbol.symbol
                Text("\(bot.isTestMode ? "Test: " : "")\(symbol)")
                    .font(.system(size: 20))
                Spacer()
                let contains = globalData.favorites.contains(symbol)
                VStack(alignment: .trailing) {
                    Button {
                        if contains {
                            globalData.favorites.remove(symbol)
                        } else {
                            globalData.favorites.append(symbol)
                        }
                    } label: {
                        Image(systemName: contains ? "star.fill" : "star")
                    }
                    Toggle("Is Auto", isOn: $bot.isAuto)
                    Button("Copy logs") {
                        let encoder = JSONEncoder()
                        let formatter = DateFormatter()
                        formatter.dateFormat = "dd-MM HH:mm:ss"
                        encoder.dateEncodingStrategy = .formatted(formatter)
                        guard let string = String(data: try! encoder.encode(bot.logs), encoding: .utf8) else { return }
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(string, forType: .string)
                    }
                }
            }
            if let error = error {
                Text("Oops: \n\(error)" as String)
            } else {
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            VStack {
                                VStack {
                                    Text("Min % to buy (\(((bot.parameters.minPercentToBuy + 1) * bot.state.price.dip).format()))")
                                    NumberField(number: $bot.parameters.minPercentToBuy, asPercent: true)
                                }
                                VStack {
                                    Text("Min % to re-buy (\(((bot.parameters.minPercentToBuyAfterSell + 1) * bot.state.price.dip).format()))")
                                    NumberField(number: $bot.parameters.minPercentToBuyAfterSell, asPercent: true)
                                }
                            }
                            VStack {
                                HStack {
                                    VStack {
                                        Text("Max % profit loss (\((bot.investQuote * bot.parameters.maxPercentProfitLoss).format())$)")
                                        NumberField(number: $bot.parameters.maxPercentProfitLoss, asPercent: true)
                                    }
                                    VStack {
                                        Text("Max % profit gain (\((bot.investQuote * bot.parameters.maxPercentProfit).format())$)")
                                        NumberField(number: $bot.parameters.maxPercentProfit, asPercent: true)
                                    }
                                }
                                HStack {
                                    VStack {
                                        Text("Max % loss (\((bot.investQuote * bot.parameters.maxPercentLoss).format())$)")
                                        NumberField(number: $bot.parameters.maxPercentLoss, asPercent: true)
                                    }
                                    VStack {
                                        Text("# of trades to confirm")
                                        NumberField(number: $bot.parameters.numberOfTradesToConfirm)
                                    }
                                }
                            }
                        }
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Invested: \(bot.invested.format())")
                                    .fixedSize(horizontal: true, vertical: false)
                                if bot.hasBought {
                                    let change = bot.profitPercent
                                    Text("Profit: \(bot.profit.format()) (\((change * 100).format()) %)")
                                        .foregroundColor(change > 0 ? .green : change < 0 ? .red : nil)
                                }
                                Text("Rise/Current/Dip: \(bot.price.rise.format()) / \(bot.price.current.format()) / \(bot.price.dip.format())")
                                    .fixedSize(horizontal: true, vertical: false)
                                Text("Price change: \((bot.priceChange * 100).format())%")
                                    .foregroundColor(bot.shouldInvest ? .green : bot.priceChange > 0 ? .yellow : .red)
                                    .fixedSize(horizontal: true, vertical: false)
                                if let str = bot.responseSpeed?.format(fractionDigits: 3) {
                                    Text("Response speed: \(str)")
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            }
                            VStack(alignment: .leading) {
                                if let c = bot.isConfirmed {
                                    Text(c ? "Confirmed" : "Confirming")
                                }
                                if bot.tooMuchLoss {
                                    Text("Too much loss")
                                        .foregroundColor(.red)
                                }
                                if bot.tooMuchProfitLoss {
                                    Text("Too much profit loss. \((bot.state.highestProfitPercent * 100).format()) / \((bot.profitPercent * 100).format())")
                                        .foregroundColor(.red)
                                }
                                if bot.hasEnoughProfit {
                                    Text("Has Enough Profit")
                                        .foregroundColor(.red)
                                }
                                if bot.shouldInvest {
                                    Text("Should invest")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        HStack(alignment: .bottom) {
                            if bot.expectedOrder == nil {
                                VStack {
                                    NumberField(number: $bot.investQuote)
                                        .frame(width: 50)
                                    Button("Buy \(bot.investQuote.format())$") { Task { await bot.buy(reason: .minPriceGain) } }
                                        .foregroundColor(.green)
                                }
                                Button("Sell All") { Task { await bot.sellAll(reason: .hasEnoughProfit) } }
                                    .foregroundColor(.red)
                            } else {
                                ProgressView()
                                Button("Override") { bot.expectedOrder = nil } // useful when trade happened not in bot or error with bot
                                    .disabled(false)
                            }
                            Text("Action: \(bot.action?.rawValue ?? "wait")")
                                .foregroundColor(bot.action == .buy ? .green : bot.action == .sell ? .red : .yellow)
                        }
                        Button("Custom") { custom.toggle() }
                        if custom {
                            CustomView(bot: bot, dip: bot.state.price.dip)
                        }
                    }
                    .disabled(bot.isAuto)
                }
                .task {
                    do {
                        try await bot.startSocket()
                    } catch {
                        self.error = error
                    }
                }
            }
        }
    }

    struct Calculator: View {
        @State var last = 0.1
        @State var first = 0.1

        var body: some View {
            HStack {
                NumberField(number: $last)
                Text("/")
                NumberField(number: $first)
                Text("=")
                Text("\(((last / first - 1) * 100).format())%")
            }
        }
    }

    struct CustomView: View {
        let bot: TradeBot
        @State var dip: Double

        var body: some View {
            HStack {
                Text("Dip: ")
                NumberField(number: $dip)
                Button("Set") { bot.state.price.dip = dip }
            }
        }
    }
}
