import Common

extension TagMask {
    /// The configured names of the tags in the mask, in config order
    @MainActor var tagNames: [String] {
        let tags = config.tags
        return indices.compactMap { $0 < tags.count ? tags[$0] : nil }
    }

    /// Every tag the config declares
    @MainActor static var allConfigured: TagMask { .all(count: config.tags.count) }

    @MainActor static func named(_ name: String) -> TagMask? {
        config.tags.firstIndex(of: name).map { TagMask(index: $0) }
    }

    /// Drop bits that no longer have a name, which happens when the `tags` config option shrinks
    @MainActor var clampedToConfig: TagMask {
        let clamped = intersection(.allConfigured)
        return clamped.isEmpty ? TagMask(index: 0) : clamped
    }
}
