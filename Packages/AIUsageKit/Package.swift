// swift-tools-version: 6.0
//
//  AIUsageKit — the AI usage engine behind Tisa Dynamic Island's AI tab.
//
//  Adapted from OpenUsage 0.7.16 by Robin Ebers (MIT, see LICENSE). The "OpenUsage"
//  name and logo are the author's trademarks and are not used. Its menu-bar app shell,
//  updater, shortcuts, launch-at-login and analytics were removed; providers, pricing,
//  stores and the dashboard views are kept.
//

import PackageDescription

let package = Package(
    name: "AIUsageKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "AIUsageKit", type: .static, targets: ["AIUsageKit"])
    ],
    targets: [
        .target(
            name: "AIUsageKit",
            path: "Sources/AIUsageKit",
            resources: [
                .copy("Resources/ProviderIcons"),
                .copy("Resources/pricing_supplement.json"),
                .copy("Resources/pricing_litellm_snapshot.json"),
                .copy("Resources/pricing_models_dev_snapshot.json")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
