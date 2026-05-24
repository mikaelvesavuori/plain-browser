import Foundation

public struct PlainLaterReadingSequence: Equatable, Sendable {
    public private(set) var activeURLString: String?

    public init(activeURLString: String? = nil) {
        self.activeURLString = activeURLString
    }

    public var isActive: Bool {
        activeURLString != nil
    }

    public mutating func activate(url: URL) {
        activeURLString = PlainNewsArticle.normalizedURLString(url)
    }

    public mutating func clear() {
        activeURLString = nil
    }

    public func containsActiveURL(_ url: URL) -> Bool {
        guard let activeURLString else {
            return false
        }
        return PlainNewsArticle.normalizedURLString(url) == activeURLString
    }

    public func activeIndex(in urls: [URL]) -> Int? {
        guard let activeURLString else {
            return nil
        }
        return urls.firstIndex { url in
            PlainNewsArticle.normalizedURLString(url) == activeURLString
        }
    }

    public func canMovePrevious(in urls: [URL]) -> Bool {
        guard let index = activeIndex(in: urls) else {
            return false
        }
        return urls.indices.contains(index - 1)
    }

    public func canMoveNext(in urls: [URL]) -> Bool {
        guard let index = activeIndex(in: urls) else {
            return false
        }
        return urls.indices.contains(index + 1)
    }

    public func previousURL(in urls: [URL]) -> URL? {
        guard let index = activeIndex(in: urls),
              urls.indices.contains(index - 1) else {
            return nil
        }
        return urls[index - 1]
    }

    public func nextURL(in urls: [URL]) -> URL? {
        guard let index = activeIndex(in: urls),
              urls.indices.contains(index + 1) else {
            return nil
        }
        return urls[index + 1]
    }
}

public struct PlainNewsReturnNavigation: Equatable, Sendable {
    public private(set) var isPending: Bool
    public private(set) var documentIndex: Int?
    public private(set) var isReturningFromFailure: Bool

    public init(
        isPending: Bool = false,
        documentIndex: Int? = nil,
        isReturningFromFailure: Bool = false
    ) {
        self.isPending = isPending
        self.documentIndex = documentIndex
        self.isReturningFromFailure = isReturningFromFailure
    }

    public mutating func prepareForOpen() {
        isPending = true
        isReturningFromFailure = false
    }

    public mutating func completeLoad(documentIndex: Int) {
        guard isPending else {
            return
        }
        self.documentIndex = documentIndex
        isPending = false
        isReturningFromFailure = false
    }

    public mutating func failLoad() {
        guard isPending else {
            return
        }
        isReturningFromFailure = true
        isPending = false
    }

    public func canReturnFromLoadedDocument(currentIndex: Int?) -> Bool {
        currentIndex != nil && currentIndex == documentIndex
    }

    public var canReturnFromFailure: Bool {
        isReturningFromFailure
    }

    public mutating func clearFailureReturn() {
        isReturningFromFailure = false
    }

    public mutating func clear() {
        isPending = false
        documentIndex = nil
        isReturningFromFailure = false
    }
}
