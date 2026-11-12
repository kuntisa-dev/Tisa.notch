import Foundation

extension UserDefaults {
    /// The engine keeps its settings in its own suite, apart from Tisa Dynamic Island's settings,
    /// because several keys ("appearance", "density", "logLevel"…) are generic enough to collide.
    static let aiUsageSuiteName = "com.kuntisa.tisadynamicisland.aiusage"

    nonisolated(unsafe) static let aiUsage = UserDefaults(suiteName: aiUsageSuiteName) ?? .standard
}
