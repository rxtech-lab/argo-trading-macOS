//
//  Bundle+Extension.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/29/25.
//

import AppKit
import Foundation

extension Bundle {
    /// Returns the app icon, compatible with both traditional AppIcon assets and Icon Composer .icon files
    var appIcon: NSImage {
        NSApplication.shared.applicationIconImage
    }
    var appName: String? {
        // CFBundleDisplayName is the user-visible name, often preferred over CFBundleName
        return infoDictionary?["CFBundleDisplayName"] as? String ?? infoDictionary?["CFBundleName"] as? String
    }

    var appVersion: String? {
        // CFBundleShortVersionString is the marketing version (e.g., 1.0.0)
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var appBuild: String? {
        // CFBundleVersion is the internal build number (e.g., 1)
        return infoDictionary?["CFBundleVersion"] as? String
    }

}
