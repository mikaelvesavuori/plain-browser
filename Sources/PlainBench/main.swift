import Darwin
import Foundation
import PlainCore

@main
struct PlainBench {
    static func main() async {
        do {
            let options = try BenchmarkOptions(arguments: CommandLine.arguments)
            let urls = try loadURLs(from: options.urlsFile, fallbackURLs: options.urls)

            guard !urls.isEmpty else {
                throw BenchmarkError.message("No benchmark URLs provided.")
            }

            let suiteStartedAt = Date()
            var results: [PlainBenchmarkResult] = []

            for url in urls {
                for iteration in 1...options.iterations {
                    if options.mode.includesTextOnly {
                        results.append(await run(url: url, iteration: iteration, fetchImages: false))
                    }

                    if options.mode.includesImages {
                        results.append(await run(url: url, iteration: iteration, fetchImages: true))
                    }
                }
            }

            let report = PlainBenchmarkReport(
                generatedAt: suiteStartedAt,
                toolVersion: "1.0.0",
                iterations: options.iterations,
                results: results
            )

            try write(report: report, jsonURL: options.outputJSON, markdownURL: options.outputMarkdown)

            print("Wrote \(options.outputJSON.path)")
            print("Wrote \(options.outputMarkdown.path)")
            print(summaryLine(for: report))
        } catch {
            fputs("PlainBench: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run(url: String, iteration: Int, fetchImages: Bool) async -> PlainBenchmarkResult {
        let pipeline = DocumentPipeline()
        let resourceStart = ResourceSnapshot.current()
        let startedAt = DispatchTime.now().uptimeNanoseconds

        do {
            let output = try await pipeline.loadWithMetrics(url, fetchImages: fetchImages)
            let endedAt = DispatchTime.now().uptimeNanoseconds
            let resourceEnd = ResourceSnapshot.current()

            return PlainBenchmarkResult(
                url: url,
                finalURL: output.document.finalURL.absoluteString,
                title: output.document.title,
                mode: fetchImages ? .images : .textOnly,
                iteration: iteration,
                success: true,
                error: nil,
                totalMilliseconds: milliseconds(from: startedAt, to: endedAt),
                pageFetchMilliseconds: output.pageMetrics.durationMilliseconds,
                imageFetchMilliseconds: output.imageMetrics.durationMilliseconds,
                htmlBytes: output.pageMetrics.responseBytes,
                imageBytes: output.imageMetrics.downloadedBytes,
                requestCount: 1 + output.imageMetrics.requestedCount,
                imageCandidates: output.imageMetrics.candidateCount,
                imageRequests: output.imageMetrics.requestedCount,
                imageCacheHits: output.imageMetrics.cacheHitCount,
                imageSuccesses: output.imageMetrics.succeededCount,
                elementCount: output.document.elements.count,
                extractedImageCount: output.document.images.count,
                extractionQuality: output.document.extractionQuality.rawValue,
                cpuUserMilliseconds: (resourceEnd.userCPUSeconds - resourceStart.userCPUSeconds) * 1_000,
                cpuSystemMilliseconds: (resourceEnd.systemCPUSeconds - resourceStart.systemCPUSeconds) * 1_000,
                residentBytesBefore: resourceStart.residentBytes,
                residentBytesAfter: resourceEnd.residentBytes,
                peakResidentBytes: max(resourceStart.residentBytes, resourceEnd.residentBytes)
            )
        } catch {
            let endedAt = DispatchTime.now().uptimeNanoseconds
            let resourceEnd = ResourceSnapshot.current()

            return PlainBenchmarkResult(
                url: url,
                finalURL: nil,
                title: nil,
                mode: fetchImages ? .images : .textOnly,
                iteration: iteration,
                success: false,
                error: error.localizedDescription,
                totalMilliseconds: milliseconds(from: startedAt, to: endedAt),
                pageFetchMilliseconds: 0,
                imageFetchMilliseconds: 0,
                htmlBytes: 0,
                imageBytes: 0,
                requestCount: 0,
                imageCandidates: 0,
                imageRequests: 0,
                imageCacheHits: 0,
                imageSuccesses: 0,
                elementCount: 0,
                extractedImageCount: 0,
                extractionQuality: nil,
                cpuUserMilliseconds: (resourceEnd.userCPUSeconds - resourceStart.userCPUSeconds) * 1_000,
                cpuSystemMilliseconds: (resourceEnd.systemCPUSeconds - resourceStart.systemCPUSeconds) * 1_000,
                residentBytesBefore: resourceStart.residentBytes,
                residentBytesAfter: resourceEnd.residentBytes,
                peakResidentBytes: max(resourceStart.residentBytes, resourceEnd.residentBytes)
            )
        }
    }

    private static func loadURLs(from file: URL?, fallbackURLs: [String]) throws -> [String] {
        if let file {
            let contents = try String(contentsOf: file, encoding: .utf8)
            return contents
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        }

        return fallbackURLs
    }

    private static func write(
        report: PlainBenchmarkReport,
        jsonURL: URL,
        markdownURL: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: jsonURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(report).write(to: jsonURL, options: [.atomic])
        try markdown(for: report).write(to: markdownURL, atomically: true, encoding: .utf8)
    }

    private static func markdown(for report: PlainBenchmarkReport) -> String {
        var lines: [String] = []
        lines.append("# Plain Benchmark Report")
        lines.append("")
        lines.append("- Generated: \(ISO8601DateFormatter().string(from: report.generatedAt))")
        lines.append("- Iterations per mode: \(report.iterations)")
        lines.append("- Successful runs: \(report.results.filter(\.success).count)/\(report.results.count)")
        lines.append("")
        lines.append("These numbers are local measurements on this machine and network. Use them for comparative claims only when the browser baseline was captured under the same conditions.")
        lines.append("")

        for mode in BenchmarkMode.allCases {
            let values = report.results.filter { $0.mode == mode && $0.success }
            guard !values.isEmpty else { continue }

            lines.append("## Plain \(mode.label)")
            lines.append("")
            lines.append("- Median time to rendered document: \(format(milliseconds: median(values.map(\.totalMilliseconds))))")
            lines.append("- Median HTML bytes: \(format(bytes: Int(median(values.map { Double($0.htmlBytes) }))))")
            lines.append("- Median image bytes: \(format(bytes: Int(median(values.map { Double($0.imageBytes) }))))")
            lines.append("- Median request count: \(String(format: "%.1f", median(values.map { Double($0.requestCount) })))")
            lines.append("- Median CPU time: \(format(milliseconds: median(values.map { $0.cpuUserMilliseconds + $0.cpuSystemMilliseconds })))")
            lines.append("- Median resident memory after load: \(format(bytes: Int(median(values.map { Double($0.residentBytesAfter) }))))")
            lines.append("")
        }

        lines.append("## Runs")
        lines.append("")
        lines.append("| URL | Mode | Iteration | Success | Time | HTML | Images | Requests | CPU | Resident Memory | Quality |")
        lines.append("| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |")

        for result in report.results {
            let cpu = result.cpuUserMilliseconds + result.cpuSystemMilliseconds
            lines.append(
                "| \(escapePipe(result.url)) | \(result.mode.rawValue) | \(result.iteration) | \(result.success ? "yes" : "no") | \(format(milliseconds: result.totalMilliseconds)) | \(format(bytes: result.htmlBytes)) | \(format(bytes: result.imageBytes)) | \(result.requestCount) | \(format(milliseconds: cpu)) | \(format(bytes: Int(result.residentBytesAfter))) | \(result.extractionQuality ?? result.error ?? "") |"
            )
        }

        lines.append("")
        lines.append("## Claim-Safe Language")
        lines.append("")
        lines.append("- Plain executes 0 page JavaScript by design.")
        lines.append("- Plain avoids live web-app rendering and converts pages into a native document model.")
        lines.append("- In text-only mode, Plain fetches no page images.")
        lines.append("- Resource and energy claims should cite the benchmark set, date, hardware, browser baseline, and median values.")

        return lines.joined(separator: "\n")
    }

    private static func summaryLine(for report: PlainBenchmarkReport) -> String {
        let successes = report.results.filter(\.success)
        guard !successes.isEmpty else {
            return "No successful runs."
        }

        return "Median Plain time: \(format(milliseconds: median(successes.map(\.totalMilliseconds)))) across \(successes.count) successful runs."
    }

    private static func milliseconds(from start: UInt64, to end: UInt64) -> Double {
        Double(end - start) / 1_000_000.0
    }
}

struct PlainBenchmarkReport: Codable {
    var generatedAt: Date
    var toolVersion: String
    var iterations: Int
    var results: [PlainBenchmarkResult]
}

struct PlainBenchmarkResult: Codable {
    var url: String
    var finalURL: String?
    var title: String?
    var mode: BenchmarkMode
    var iteration: Int
    var success: Bool
    var error: String?
    var totalMilliseconds: Double
    var pageFetchMilliseconds: Double
    var imageFetchMilliseconds: Double
    var htmlBytes: Int
    var imageBytes: Int
    var requestCount: Int
    var imageCandidates: Int
    var imageRequests: Int
    var imageCacheHits: Int
    var imageSuccesses: Int
    var elementCount: Int
    var extractedImageCount: Int
    var extractionQuality: String?
    var cpuUserMilliseconds: Double
    var cpuSystemMilliseconds: Double
    var residentBytesBefore: UInt64
    var residentBytesAfter: UInt64
    var peakResidentBytes: UInt64
}

enum BenchmarkMode: String, Codable, CaseIterable {
    case textOnly = "text-only"
    case images

    var label: String {
        switch self {
        case .textOnly:
            return "Text-Only"
        case .images:
            return "Images"
        }
    }
}

enum BenchmarkModeSelection {
    case textOnly
    case images
    case both

    var includesTextOnly: Bool {
        self == .textOnly || self == .both
    }

    var includesImages: Bool {
        self == .images || self == .both
    }
}

struct BenchmarkOptions {
    var urlsFile: URL?
    var urls: [String] = []
    var iterations = 1
    var mode: BenchmarkModeSelection = .both
    var outputJSON = URL(fileURLWithPath: "benchmarks/results/plain.json")
    var outputMarkdown = URL(fileURLWithPath: "benchmarks/results/plain.md")

    init(arguments: [String]) throws {
        var iterator = Array(arguments.dropFirst()).makeIterator()

        while let argument = iterator.next() {
            switch argument {
            case "--":
                continue
            case "--urls":
                guard let value = iterator.next() else { throw BenchmarkError.message("Missing value for --urls") }
                urlsFile = URL(fileURLWithPath: value)
            case "--url":
                guard let value = iterator.next() else { throw BenchmarkError.message("Missing value for --url") }
                urls.append(value)
            case "--iterations":
                guard let value = iterator.next(), let parsed = Int(value), parsed > 0 else {
                    throw BenchmarkError.message("--iterations must be a positive integer")
                }
                iterations = parsed
            case "--mode":
                guard let value = iterator.next() else { throw BenchmarkError.message("Missing value for --mode") }
                switch value {
                case "text-only":
                    mode = .textOnly
                case "images":
                    mode = .images
                case "both":
                    mode = .both
                default:
                    throw BenchmarkError.message("--mode must be text-only, images, or both")
                }
            case "--out":
                guard let value = iterator.next() else { throw BenchmarkError.message("Missing value for --out") }
                outputJSON = URL(fileURLWithPath: value)
                outputMarkdown = outputJSON.deletingPathExtension().appendingPathExtension("md")
            case "--help", "-h":
                printHelp()
                exit(0)
            default:
                if argument.hasPrefix("-") {
                    throw BenchmarkError.message("Unknown option: \(argument)")
                }
                urls.append(argument)
            }
        }
    }

    private func printHelp() {
        print("""
        Usage:
          swift run PlainBench -- --urls benchmarks/urls.txt --iterations 3 --mode both

        Options:
          --urls <path>          Newline-delimited URL file
          --url <url>            Add one URL
          --iterations <n>       Runs per URL and mode (default: 1)
          --mode <mode>          text-only, images, or both (default: both)
          --out <path>           JSON output path (Markdown is written next to it)
        """)
    }
}

enum BenchmarkError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let value):
            return value
        }
    }
}

struct ResourceSnapshot {
    var userCPUSeconds: Double
    var systemCPUSeconds: Double
    var residentBytes: UInt64

    static func current() -> ResourceSnapshot {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)

        return ResourceSnapshot(
            userCPUSeconds: seconds(from: usage.ru_utime),
            systemCPUSeconds: seconds(from: usage.ru_stime),
            residentBytes: currentResidentBytes()
        )
    }

    private static func seconds(from timeval: timeval) -> Double {
        Double(timeval.tv_sec) + Double(timeval.tv_usec) / 1_000_000
    }
}

func currentResidentBytes() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), reboundPointer, &count)
        }
    }

    guard result == KERN_SUCCESS else {
        return 0
    }

    return UInt64(info.resident_size)
}

func median(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let midpoint = sorted.count / 2
    if sorted.count.isMultiple(of: 2) {
        return (sorted[midpoint - 1] + sorted[midpoint]) / 2
    }
    return sorted[midpoint]
}

func format(milliseconds: Double) -> String {
    if milliseconds >= 1_000 {
        return String(format: "%.2fs", milliseconds / 1_000)
    }
    return String(format: "%.0fms", milliseconds)
}

func format(bytes: Int) -> String {
    let value = Double(bytes)
    if value >= 1_000_000 {
        return String(format: "%.2f MB", value / 1_000_000)
    }
    if value >= 1_000 {
        return String(format: "%.1f KB", value / 1_000)
    }
    return "\(bytes) B"
}

func escapePipe(_ value: String) -> String {
    value.replacingOccurrences(of: "|", with: "\\|")
}
