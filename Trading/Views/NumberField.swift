//
//  NumberField.swift
//  Trading
//
//  Created by Arutyun Enfendzhyan on 16.05.22.
//

import SwiftUI

struct NumberField<Number: CustomStringConvertible & Equatable>: View {
    @Binding var number: Number
    let fromString: (String) -> Number?
    @StateObject var model = Model()

    var body: some View {
        TextField("", text: $model.string)
            .frame(width: 70)
            .foregroundColor(fromString(model.string) == nil ? .red : nil)
            .onChange(of: number) {
                guard model.string != $0.description else { return }
                model.string = $0.description
            }
            .onReceive(model.$string) {
                guard let number = fromString($0) else { return }
                self.number = number
            }
            .onAppear {
                guard model.string != number.description else { return }
                model.string = number.description
            }
    }

    final class Model: ObservableObject {
        @Published var string = ""
    }
}

extension NumberField {
    init(number: Binding<Double>, asPercent: Bool = false) where Number == Double {
        self.init(number: asPercent ? .init { number.wrappedValue * 100 } set : { number.wrappedValue = $0 / 100 }: number) { Double($0) }
    }

    init(number: Binding<Int>) where Number == Int {
        self.init(number: number) { Int($0) }
    }
}

struct NumberField_Previews: PreviewProvider {
    static var previews: some View {
        NumberField(number: .constant(0))
    }
}
