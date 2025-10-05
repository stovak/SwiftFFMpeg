import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
  return [
    testCase(AVBufferTests.allTests),
    testCase(AVFrameTests.allTests),
    testCase(AVImageTests.allTests),
    testCase(AVRationalTests.allTests),
    testCase(FixtureManagerTests.allTests),
    testCase(AVConcatTests.allTests),
  ]
}
#endif
