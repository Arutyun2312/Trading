//
//  TradingApp.swift
//  Trading
//
//  Created by Arutyun Enfendzhyan on 13.05.22.
//

import MyExtensions
import OrderedCollections
import SwiftUI

@main
struct TradingApp: App {
    @ObservedObject var globalData = GlobalData.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
                .environmentObject(globalData)
        }
        .commands {
            CommandMenu("Manage Favourites" as String) {
                Button("Delete all") { globalData.favorites = [] }
            }
        }
    }
}

final class GlobalData: ObservableObject {
    static let shared = GlobalData()

    @Published var symbols: [Symbol] = []
    @Published var favorites: OrderedSet<String>
    @Published var bots: OrderedSet<TradeBot> = []
    @Published var shouldSort = false

    private init() {
        _favorites = .init(key: "favourites", default: [])
    }

    var botsSorted: [TradeBot] {
        guard shouldSort else { return .init(bots) }
        let shouldInvest = bots.filter(\.shouldInvest).descendingSorted(by: \.priceChange)
        let rest = bots.filter { !$0.shouldInvest }.descendingSorted(by: \.priceChange)
        return shouldInvest + rest
    }
}
