//
//  Extensions.swift
//  Trading
//
//  Created by Arutyun Enfendzhyan on 13.05.22.
//

import Foundation
import OrderedCollections

extension Data {
    func decode() throws -> Any {
        try JSONSerialization.jsonObject(with: self)
    }

    func decode<T: Decodable>() throws -> T {
        try API.shared.decoder.decode(T.self, from: self)
    }
}

extension OrderedSet where Element == Candle {
    var change: Double? {
        guard let first = first, let last = last, count > 1 else { return nil }
        return last.close / first.open - 1
    }
}

extension Array where Element == Candle {
    var change: Double? { OrderedSet(sorted { $0.time < $1.time }).change }
}

extension Sequence {
    func suffix(while predicate: (Element) -> Bool) -> [Element] { reversed().prefix(while: predicate).reversed().map { $0 } }
    func descendingSorted(by: (Element) -> Double) -> [Element] { sorted { by($0) > by($1) } }
    func sum(value: (Element) -> Double) -> Double { reduce(0.0) { sum, el in sum + value(el) } }
}

extension Date {
    func format(_ format: String = "dd-MM HH:mm:ss") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

extension Double {
    func format(fractionDigits: Int = 3) -> String {
        let formatter = NumberFormatter()
        let minimum = 1e-5
        formatter.minimum = minimum as NSNumber
        if self > 1 {
            formatter.maximumFractionDigits = fractionDigits
        } else {
            if self > minimum {
                formatter.usesSignificantDigits = true
                formatter.minimumSignificantDigits = 1
                formatter.maximumSignificantDigits = 4
            } else {
                formatter.usesSignificantDigits = false
            }
            formatter.maximumFractionDigits = 4
        }
        return formatter.string(from: self as NSNumber) ?? "nil"
    }
}

extension String {
    var double: Double { .init(self)! }
}

@propertyWrapper struct ToDouble {
    var wrappedValue: Double
}

extension ToDouble: Hashable, Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let double = Double(string) else { throw "Invalid double: \(string)" }
        wrappedValue = double
    }

    func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}
