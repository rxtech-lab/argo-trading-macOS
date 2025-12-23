//
//  StrategyParametersView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/23/25.
//

import JSONSchema
import JSONSchemaForm
import SwiftUI

struct StrategyParametersView: View {
    let jsonSchema: String
    var body: some View {
        Group {
            if let jsonSchema = try? JSONSchema(jsonString: jsonSchema) {
                Form {
                    JSONSchemaForm(schema: jsonSchema, formData: .constant(.object(properties: [:])), showSubmitButton: false)
                }
                .formStyle(.grouped)
                .disabled(true)

            } else {
                Text("Invalid JSON Schema")
            }
        }
    }
}
