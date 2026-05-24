import Foundation
import PlainCore
import XCTest

final class PlainReadingNavigationStateTests: XCTestCase {
    func testLaterReadingSequenceMovesThroughItemsInOrder() {
        let urls = [
            URL(string: "https://example.com/one")!,
            URL(string: "https://example.com/two")!,
            URL(string: "https://example.com/three")!
        ]
        var sequence = PlainLaterReadingSequence()

        sequence.activate(url: urls[1])

        XCTAssertEqual(sequence.activeIndex(in: urls), 1)
        XCTAssertTrue(sequence.canMovePrevious(in: urls))
        XCTAssertTrue(sequence.canMoveNext(in: urls))
        XCTAssertEqual(sequence.previousURL(in: urls), urls[0])
        XCTAssertEqual(sequence.nextURL(in: urls), urls[2])
    }

    func testLaterReadingSequenceStopsAtListEdges() {
        let urls = [
            URL(string: "https://example.com/one")!,
            URL(string: "https://example.com/two")!
        ]
        var sequence = PlainLaterReadingSequence()

        sequence.activate(url: urls[0])
        XCTAssertFalse(sequence.canMovePrevious(in: urls))
        XCTAssertTrue(sequence.canMoveNext(in: urls))

        sequence.activate(url: urls[1])
        XCTAssertTrue(sequence.canMovePrevious(in: urls))
        XCTAssertFalse(sequence.canMoveNext(in: urls))
    }

    func testLaterReadingSequenceNormalizesActiveURL() {
        let urls = [
            URL(string: "https://example.com/article")!
        ]
        var sequence = PlainLaterReadingSequence()

        sequence.activate(url: URL(string: "https://EXAMPLE.com/article/#section")!)

        XCTAssertEqual(sequence.activeIndex(in: urls), 0)
        XCTAssertTrue(sequence.containsActiveURL(urls[0]))
    }

    func testClearingLaterReadingSequenceDisablesNavigation() {
        let urls = [
            URL(string: "https://example.com/one")!,
            URL(string: "https://example.com/two")!
        ]
        var sequence = PlainLaterReadingSequence()

        sequence.activate(url: urls[0])
        sequence.clear()

        XCTAssertFalse(sequence.isActive)
        XCTAssertNil(sequence.activeIndex(in: urls))
        XCTAssertFalse(sequence.canMoveNext(in: urls))
    }

    func testNewsReturnNavigationTracksLoadedDocument() {
        var navigation = PlainNewsReturnNavigation()

        navigation.prepareForOpen()
        navigation.completeLoad(documentIndex: 3)

        XCTAssertFalse(navigation.isPending)
        XCTAssertTrue(navigation.canReturnFromLoadedDocument(currentIndex: 3))
        XCTAssertFalse(navigation.canReturnFromLoadedDocument(currentIndex: 2))
        XCTAssertFalse(navigation.canReturnFromFailure)
    }

    func testNewsReturnNavigationTracksFailedLoad() {
        var navigation = PlainNewsReturnNavigation()

        navigation.prepareForOpen()
        navigation.failLoad()

        XCTAssertFalse(navigation.isPending)
        XCTAssertTrue(navigation.canReturnFromFailure)

        navigation.clearFailureReturn()
        XCTAssertFalse(navigation.canReturnFromFailure)
    }

    func testClearingNewsReturnNavigationResetsState() {
        var navigation = PlainNewsReturnNavigation()

        navigation.prepareForOpen()
        navigation.completeLoad(documentIndex: 1)
        navigation.clear()

        XCTAssertFalse(navigation.isPending)
        XCTAssertFalse(navigation.canReturnFromLoadedDocument(currentIndex: 1))
        XCTAssertFalse(navigation.canReturnFromFailure)
    }
}
