//
//  RemoveListPadding+Extension.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

import SwiftUI

struct RemoveListPadding: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(EdgeInsets(top: 0, leading: -20, bottom: 0, trailing: -20))
    }
}

extension View {
    func removeListPadding() -> some View {
        self.modifier(RemoveListPadding())
    }
}
