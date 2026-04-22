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
    var translation: String? = nil

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .multilineTextAlignment(.trailing)
                if let translation, !translation.isEmpty, translation != value {
                    Text(translation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
}
