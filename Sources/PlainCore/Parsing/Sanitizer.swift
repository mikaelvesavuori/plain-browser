import Foundation
import SwiftSoup

public struct SanitizedHTML: Sendable, Equatable {
    public let html: String
    public let baseURL: URL

    public init(html: String, baseURL: URL) {
        self.html = html
        self.baseURL = baseURL
    }
}

public struct Sanitizer: Sendable {
    private let blockedSelectors = [
        "style",
        "video",
        "audio",
        "track",
        "iframe",
        "object",
        "embed",
        "canvas",
        "form",
        "input",
        "button",
        "select",
        "textarea",
        "svg",
        "template",
        "link[rel=preload]",
        "link[rel=prefetch]",
        "link[rel=preconnect]",
        "meta[http-equiv=refresh]",
        "[hidden]",
        "[aria-hidden=true]"
    ].joined(separator: ",")

    public init() {}

    public func sanitize(html: String, baseURL: URL) throws -> SanitizedHTML {
        let document = try SwiftSoup.parse(html, baseURL.absoluteString)
        document.outputSettings().prettyPrint(pretty: false)

        try removeExecutableScripts(from: document)
        try document.select(blockedSelectors).remove()
        try removeHiddenStyledElements(from: document)
        try removeTrackingPixels(from: document)
        try cleanAttributes(in: document)

        return SanitizedHTML(html: try document.html(), baseURL: baseURL)
    }

    private func removeExecutableScripts(from document: Document) throws {
        for script in try document.select("script").array() {
            let type = try script.attr("type")
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard type == "application/ld+json" else {
                try script.remove()
                continue
            }

            for name in script.getAttributes()?.asList().map({ $0.getKey() }) ?? [] {
                try script.removeAttr(name)
            }
            try script.attr("type", "application/ld+json")
        }
    }

    private func removeHiddenStyledElements(from document: Document) throws {
        for element in try document.select("[style]").array() {
            let style = try element.attr("style").lowercased()
            if style.contains("display:none")
                || style.contains("display: none")
                || style.contains("visibility:hidden")
                || style.contains("visibility: hidden")
                || style.contains("opacity:0")
                || style.contains("opacity: 0") {
                try element.remove()
            }
        }
    }

    private func removeTrackingPixels(from document: Document) throws {
        for image in try document.select("img").array() {
            let width = Int(try image.attr("width")) ?? Int.max
            let height = Int(try image.attr("height")) ?? Int.max
            let source = try image.attr("src").lowercased()

            if (width <= 2 && height <= 2)
                || source.contains("pixel")
                || source.contains("tracking")
                || source.contains("analytics") {
                try image.remove()
            }
        }
    }

    private func cleanAttributes(in document: Document) throws {
        for element in try document.select("*").array() {
            for name in element.getAttributes()?.asList().map({ $0.getKey() }) ?? [] {
                let lowercased = name.lowercased()
                if lowercased.hasPrefix("on")
                    || lowercased == "style"
                    || shouldRemoveDataAttribute(lowercased, from: element)
                    || lowercased.hasPrefix("aria-") {
                    try element.removeAttr(name)
                }
            }

            for urlAttribute in ["href", "src", "srcset"] {
                let value = try element.attr(urlAttribute)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                if value.hasPrefix("javascript:")
                    || value.hasPrefix("data:text/html")
                    || value.hasPrefix("vbscript:") {
                    try element.removeAttr(urlAttribute)
                }
            }
        }
    }

    private func shouldRemoveDataAttribute(_ name: String, from element: Element) -> Bool {
        guard name.hasPrefix("data-") else {
            return false
        }

        let tag = element.tagName().lowercased()
        guard tag == "img" || tag == "source" else {
            return true
        }

        let allowedImageURLAttributes = [
            "data-src",
            "data-srcset",
            "data-original",
            "data-original-srcset",
            "data-lazy-src",
            "data-lazy-srcset",
            "data-zoom-src",
            "data-zoom-srcset",
            "data-hi-res-src"
        ]

        return !allowedImageURLAttributes.contains(name)
    }
}
