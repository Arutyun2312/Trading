//
//  ContentView.swift
//  Trading
//
//  Created by Arutyun Enfendzhyan on 13.05.22.
//

import AppKit
import MyExtensions
import OrderedCollections
import SwiftUI

struct ContentView: View {
    @State var columnCount = 3
    @State var showGlobalParams = false
    @StateObject var userAccount = UserAccountBot.shared
    @EnvironmentObject var globalData: GlobalData
    var targetTestingBot: TradeBot? { globalData.bots.first(where: \.isTestMode) }

    var body: some View {
        VStack(alignment: .leading) {
            if userAccount.accountInfo == nil || globalData.symbols.isEmpty {
                ProgressView()
                    .task {
                        globalData.symbols = try! await [.testSymbol] + API.shared.symbols()
                        try! await userAccount.update()
                        fixateBalance()
                    }
            } else {
                VStack(alignment: .leading) {
                    HStack {
                        Menu("Select token to create bot") {
                            ForEach(globalData.symbols.filter { s in !globalData.bots.contains { $0.symbol.symbol == s.symbol } }, id: \.symbol) { sym in
                                Button(sym.baseAsset) {
                                    globalData.bots.append(.init(symbol: sym))
                                }
                            }
                        }
                        .frame(width: 200)
                        Button("Clear all bots") { globalData.bots.removeAll() }
                        if !globalData.favorites.isEmpty {
                            Button("Set up favourites") {
                                for fav in globalData.favorites {
                                    guard let symbol = globalData.symbols.first(where: { $0.symbol == fav }) else { continue }
                                    globalData.bots.append(.init(symbol: symbol))
                                }
                            }
                        }
                        Button("Track all") {
                            globalData.bots = OrderedSet(globalData.symbols.map { TradeBot(symbol: $0) })
                        }
                        Button("Refresh wallet") {
                            AsyncTask { try await userAccount.update() }
                        }
                        Button("Fixate balance", action: fixateBalance)
                        Text("Balance: \(userAccount.balance.format()) Change: \((userAccount.balance - userAccount.fixatedBalance).format())")
                            .font(.system(size: 20))
                    }
                    HStack {
                        Toggle("Should sort", isOn: $globalData.shouldSort)
                        HStack {
                            Text("Columns: ")
                            NumberField(number: $columnCount)
                        }
                        Toggle("All is Auto", isOn: .init { globalData.bots.contains(where: \.isAuto) } set: { bool in globalData.bots.forEach { $0.isAuto = bool } })
                        Toggle("Show global params", isOn: $showGlobalParams)
                    }
                }
                .task {
                    try! await userAccount.listenToChanges()
                    do {
                        for try await ticker in API.shared.all24hChangeTracker() {
                            if ticker.priceChangePercent > 0.15,
                               let symbol = globalData.symbols.first(where: { $0.symbol == ticker.symbol }),
                               !globalData.bots.contains(where: { $0.symbol.symbol == symbol.symbol })
                            {
                                globalData.bots.append(.init(symbol: symbol))
                            }
                        }
                    } catch {
                        print(error)
                    }
                }
                let row = GridItem(alignment: .top)
                ScrollView {
                    LazyVGrid(columns: .init(repeating: row, count: columnCount), alignment: .leading) {
                        Group {
                            if showGlobalParams {
                                GlobalParameters()
                            }
                            ForEach(globalData.botsSorted) { bot in
                                TradeBotView(bot: bot)
                            }
                            if let targetTestingBot = targetTestingBot {
                                FakeDataBotView(tradeBot: targetTestingBot)
                            }
                        }
                        .padding(1)
                        .border(Color.gray)
                    }
                }
            }
        }
    }

    struct GlobalParameters: View {
        @State var parameters = TradeBot.Params()
        @EnvironmentObject var globalData: GlobalData

        var body: some View {
            VStack {
                HStack {
                    VStack {
                        VStack {
                            Text("Min % to buy")
                            NumberField(number: $parameters.minPercentToBuy, asPercent: true)
                        }
                        VStack {
                            Text("Min % to re-buy")
                            NumberField(number: $parameters.minPercentToBuyAfterSell, asPercent: true)
                        }
                    }
                    VStack {
                        HStack {
                            VStack {
                                Text("Max % profit loss")
                                NumberField(number: $parameters.maxPercentProfitLoss, asPercent: true)
                            }
                            VStack {
                                Text("Max % profit gain")
                                NumberField(number: $parameters.maxPercentProfit, asPercent: true)
                            }
                        }
                        VStack {
                            Text("Max % loss")
                            NumberField(number: $parameters.maxPercentLoss, asPercent: true)
                        }
                    }
                }
                Button("Set to all bots") {
                    for bot in globalData.bots {
                        bot.parameters = parameters
                    }
                }
            }
        }
    }

    func fixateBalance() { userAccount.fixatedBalance = userAccount.balance }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
