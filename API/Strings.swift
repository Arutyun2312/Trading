//
//  Strings.swift
//  Trading
//
//  Created by Arutyun Enfendzhyan on 13.05.22.
//

import Foundation

enum Strings: String {
    case baseUrl = "https://api.binance.com",
         secret = "A6JAkovbn1NNrJb77R3oWjQBDECUSEJ7ILKHmMv1p8jgFipyOr79fkctZ6iW5n0W",
         apiKey = "YO1vxiph1iitLOiuCMMAFI9fRVwIyIMVoUNAeDPaWP9u6roceEr7V0HPCqq8Brhr",
         signature = "724e5f7d790dde4ca0ede0421217e020e77c5cb848abe6c04f06da60a7bd0a4b"

    static let baseURL = URL(string: Strings.baseUrl.rawValue)!
}

