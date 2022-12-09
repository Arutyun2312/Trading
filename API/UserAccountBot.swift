//
//  UserAccountBot.swift
//  Trading
//
//  Created by Arutyun Enfendzhyan on 15.05.22.
//

import Foundation

let MAIN_ASSET = "USDT"
final class UserAccountBot: ObservableObject {
    static let shared = UserAccountBot()
    private init() {}

    @Published var accountInfo: AccountInfo?
    var balance: Double {
        let main = accountInfo?[MAIN_ASSET]?.free ?? 0
        return main + GlobalData.shared.bots.filter { !$0.trades.isEmpty }.sum(value: \.investedInQuote)
    }

    @Published var fixatedBalance = 0.0

    @MainActor
    func update() async throws {
        accountInfo = try await API.shared.getAccountInfo()
    }

    @MainActor
    func listenToChanges() async throws {
        for try await data in try await API.shared.userDataSocket() {
            print(String(data: data, encoding: .utf8) ?? "nil")
            let base: BaseAccountUpdate = try data.decode()
            switch base.eventType {
            case "outboundAccountPosition":
                let accUpdate = try API.shared.decoder.decode(AccountUpdate.self, from: data)
                for balance in accUpdate.balances {
                    accountInfo?[balance.asset] = balance
                }
            case "executionReport":
                let report = try API.shared.decoder.decode(ExecutionReport.self, from: data)
                guard let bot = GlobalData.shared.bots.first(where: { $0.symbol.symbol == report.symbol }) else { continue }
                if report.orderStatus == "FILLED" {
                    switch report.side {
                    case .buy: bot.buys.append(report)
                    case .sell: bot.buys = []
                    }
                    if bot.expectedOrder == report.clientOrderId {
                        bot.expectedOrder = nil
                    }
                }
            default:
                print("Ignore: \(base.eventType)\n\(String(data: data, encoding: .utf8) ?? "nil")")
            }
            if balance - fixatedBalance <= -20 {
                GlobalData.shared.bots = []
            }
        }
    }
}
