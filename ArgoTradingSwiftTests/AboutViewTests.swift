//
//  AboutViewTests.swift
//  ArgoTradingSwiftTests
//

import Testing
@testable import ArgoTradingSwift

struct AboutViewTests {

    @Test func semverVersionLinksToReleaseTag() {
        let url = AboutView.engineVersionURL(for: "v1.17.0")
        #expect(url.absoluteString == "https://github.com/rxtech-lab/argo-trading/releases/tag/v1.17.0")
    }

    @Test func multiDigitSemverLinksToReleaseTag() {
        let url = AboutView.engineVersionURL(for: "v10.234.5")
        #expect(url.absoluteString == "https://github.com/rxtech-lab/argo-trading/releases/tag/v10.234.5")
    }

    @Test func zeroVersionLinksToReleaseTag() {
        let url = AboutView.engineVersionURL(for: "v0.0.1")
        #expect(url.absoluteString == "https://github.com/rxtech-lab/argo-trading/releases/tag/v0.0.1")
    }

    @Test func branchNameLinksToTree() {
        let url = AboutView.engineVersionURL(for: "main")
        #expect(url.absoluteString == "https://github.com/rxtech-lab/argo-trading/tree/main")
    }

    @Test func featureBranchLinksToTree() {
        let url = AboutView.engineVersionURL(for: "feature/hold-time")
        #expect(url.absoluteString == "https://github.com/rxtech-lab/argo-trading/tree/feature/hold-time")
    }

    @Test func versionWithoutVPrefixLinksToTree() {
        let url = AboutView.engineVersionURL(for: "1.17.0")
        #expect(url.absoluteString == "https://github.com/rxtech-lab/argo-trading/tree/1.17.0")
    }

    @Test func semverWithSuffixLinksToTree() {
        let url = AboutView.engineVersionURL(for: "v1.17.0-beta")
        #expect(url.absoluteString == "https://github.com/rxtech-lab/argo-trading/tree/v1.17.0-beta")
    }

    @Test func commitShaLinksToTree() {
        let url = AboutView.engineVersionURL(for: "8be77b3")
        #expect(url.absoluteString == "https://github.com/rxtech-lab/argo-trading/tree/8be77b3")
    }
}
