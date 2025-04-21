//
//  ArgoTradingDocument.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var argoTradingDocument: UTType {
        UTType(importedAs: "lab.rxlab.argo-trading")
    }
}

enum ArgoTradingDocumentError: Error {
    case invalidData
}

struct ArgoTradingDocument: FileDocument {
    var dataFolder: URL
    var strategyFolder: URL
    var resultFolder: URL

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            let decoder = JSONDecoder()
            self = try decoder.decode(Self.self, from: data)
        }

        throw ArgoTradingDocumentError.invalidData
    }

    init(dataFolder: URL? = nil, strategyFolder: URL? = nil, resultFolder: URL? = nil) {
        self.dataFolder = dataFolder ?? URL(fileURLWithPath: "/data")
        self.strategyFolder = strategyFolder ?? URL(fileURLWithPath: "/strategy")
        self.resultFolder = resultFolder ?? URL(fileURLWithPath: "/result")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return .init(regularFileWithContents: data)
    }

    static var readableContentTypes: [UTType] { [.argoTradingDocument] }
}

extension ArgoTradingDocument: Codable {}
