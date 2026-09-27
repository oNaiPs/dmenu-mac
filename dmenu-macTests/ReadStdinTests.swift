import XCTest
@testable import dmenu_mac

final class ReadStdinTests: XCTestCase {
    private func readPipe(writing chunks: [Data], delay: TimeInterval = 0) -> String {
        let pipe = Pipe()
        let writer = pipe.fileHandleForWriting
        DispatchQueue.global().async {
            for chunk in chunks {
                if delay > 0 { Thread.sleep(forTimeInterval: delay) }
                writer.write(chunk)
            }
            try? writer.close()
        }
        return ReadStdin.read(fromFileDescriptor: pipe.fileHandleForReading.fileDescriptor)
    }

    func testReadsAllLines() {
        XCTAssertEqual(readPipe(writing: [Data("Yes\nNo\n".utf8)]), "Yes\nNo\n")
    }

    func testWaitsForSlowProducer() {
        let result = readPipe(writing: [Data("Yes\n".utf8), Data("No\n".utf8)], delay: 0.2)
        XCTAssertEqual(result, "Yes\nNo\n")
    }

    func testDecodesMultiByteCharacters() {
        XCTAssertEqual(readPipe(writing: [Data("aççç\nação\n".utf8)]), "aççç\nação\n")
    }

    func testMultiByteCharacterSplitAcrossWrites() {
        let bytes = Array("ç\n".utf8)
        let chunks = [Data(bytes[0..<1]), Data(bytes[1...])]
        XCTAssertEqual(readPipe(writing: chunks, delay: 0.05), "ç\n")
    }

    func testReadsLargeInput() {
        let input = (0..<20_000).map { "item \($0)" }.joined(separator: "\n")
        XCTAssertEqual(readPipe(writing: [Data(input.utf8)]), input)
    }

    func testEmptyInput() {
        XCTAssertEqual(readPipe(writing: []), "")
    }

    func testInvalidUTF8ReturnsEmpty() {
        XCTAssertEqual(readPipe(writing: [Data([0xFF, 0xFE, 0x0A])]), "")
    }
}
