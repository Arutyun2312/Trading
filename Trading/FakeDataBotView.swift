//
//  FakeDataBotView.swift
//  Trading
//
//  Created by Arutyun Enfendzhyan on 15.05.22.
//

import SwiftUI

struct FakeDataBotView: View {
    @ObservedObject var tradeBot: TradeBot
    @State var price = 1.0
    @State var quantity = 100.0

    var body: some View {
        VStack {
            topView
            Spacer()
            HStack {
                VStack {
                    Text("Price")
                    NumberField(number: $price)
                }
                VStack {
                    Text("Quantity")
                    NumberField(number: $quantity)
                }
            }
            HStack {
                Button("Send") {
                    Task {
                        try await tradeBot.dateReceiver(data: .init(time: .now, price: price, quantity: quantity))
                    }
                }
                Button("Reset") {
                    tradeBot.trades = []
                    tradeBot.price = .init()
                    tradeBot.buys = []
                }
            }
        }
        .onAppear {
            guard let last = tradeBot.trades.last else { return }
            price = last.price
            quantity = last.quantity
        }
    }

    var topView: some View {
        HStack(alignment: .top) {
            Spacer()
            let symbol = tradeBot.symbol.symbol
            Text("Fake: \(symbol)")
                .font(.system(size: 20))
            Spacer()
        }
    }
}
