//
//  Bot.swift
//  Trading
//
//  Created by Arutyun Enfendzhyan on 15.05.22.
//

import Foundation

enum AnyBot {
    case tradeBot(TradeBot), fakeDataBot(FakeDataBot)
}

protocol Bot: AnyObject {}
