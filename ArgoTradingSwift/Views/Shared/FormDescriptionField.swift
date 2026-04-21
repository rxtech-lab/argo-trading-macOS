//
//  FormDescriptionField.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/23/25.
//

import SwiftUI

struct FormDescriptionField: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}
