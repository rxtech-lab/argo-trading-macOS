//
//  WelcomeOption.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/22/25.
//

import SwiftUI

// Custom folder selection view
struct WelcomeOption: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void // Add an action closure

    @State private var isPressed: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
        )
        .scaleEffect(isPressed ? 0.98 : 1.0) // Subtle scale down when pressed
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onPress {
            // Visual animation
            withAnimation {
                isPressed = true
            }
        } onRelease: {
            action() // Execute the provided action

            // Reset the pressed state
            withAnimation {
                isPressed = false
            }
        }
    }
}
