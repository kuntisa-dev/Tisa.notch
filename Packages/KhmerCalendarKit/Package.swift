// swift-tools-version: 6.0
//
//  KhmerCalendarKit — the Khmer lunar calendar behind Tisa Dynamic Island's Calendar tab.
//
//  The lunar maths (Chhankitek) is ported from momentkh by ThyrithSor (MIT, see LICENSE).
//  No UI and no dependencies, so everything here can be tested with `swift test`:
//  the lunar date of a day, holidays, Khmer names and numerals, the month grid, and the
//  day-notes file.
//

import PackageDescription

let package = Package(
    name: "KhmerCalendarKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "KhmerCalendarKit", type: .static, targets: ["KhmerCalendarKit"])
    ],
    targets: [
        .target(name: "KhmerCalendarKit"),
        .testTarget(
            name: "KhmerCalendarKitTests",
            dependencies: ["KhmerCalendarKit"],
            resources: [.copy("Fixtures")]
        )
    ]
)
