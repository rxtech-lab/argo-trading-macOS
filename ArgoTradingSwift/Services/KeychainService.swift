//
//  KeychainService.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import Foundation
import LocalAuthentication
import Security
import SwiftUI

@Observable
class KeychainService {
    static let serviceName = "lab.rxlab.argo-trading"
    static let keychainPrefix = "argo-trading"

    var isAuthenticated: Bool = false
    var authError: String?

    private var cachedContext: LAContext?

    // Allow overriding service name for tests
    let serviceNameOverride: String?

    var effectiveServiceName: String {
        serviceNameOverride ?? Self.serviceName
    }

    init(serviceNameOverride: String? = nil) {
        self.serviceNameOverride = serviceNameOverride
    }

    // MARK: - Biometric Authentication

    func authenticateWithBiometrics() async -> Bool {
        // If already authenticated with a valid context, reuse it
        if let context = cachedContext, context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
            return true
        }

        let context = LAContext()
        context.localizedReason = "Access secure credentials"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            let errorMessage = error?.localizedDescription ?? "Biometric authentication is not available"
            await MainActor.run {
                self.authError = errorMessage
                self.isAuthenticated = false
            }
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Access your secure API keys and credentials"
            )
            await MainActor.run {
                if success {
                    self.cachedContext = context
                    self.isAuthenticated = true
                    self.authError = nil
                } else {
                    self.isAuthenticated = false
                    self.authError = "Authentication failed"
                }
            }
            return success
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
                self.authError = error.localizedDescription
            }
            return false
        }
    }

    func resetAuthentication() {
        cachedContext = nil
        isAuthenticated = false
        authError = nil
    }

    // MARK: - Keychain CRUD

    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: effectiveServiceName,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Use simple accessible attribute without access control
        // This avoids the -34018 errSecMissingEntitlement error when running from Xcode
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: effectiveServiceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: effectiveServiceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: effectiveServiceName,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Batch Operations

    static func keychainKey(identifier: String, fieldName: String) -> String {
        "\(keychainPrefix).\(identifier).\(fieldName)"
    }

    func loadKeychainValues(identifier: String, fieldNames: Set<String>) -> [String: String] {
        var values: [String: String] = [:]
        for fieldName in fieldNames {
            let key = Self.keychainKey(identifier: identifier, fieldName: fieldName)
            if let value = read(key: key) {
                values[fieldName] = value
            }
        }
        return values
    }

    func saveKeychainValues(identifier: String, values: [String: String]) {
        for (fieldName, value) in values {
            let key = Self.keychainKey(identifier: identifier, fieldName: fieldName)
            _ = save(key: key, value: value)
        }
    }

    func deleteKeychainValues(identifier: String, fieldNames: [String]) {
        for fieldName in fieldNames {
            let key = Self.keychainKey(identifier: identifier, fieldName: fieldName)
            _ = delete(key: key)
        }
    }
}
