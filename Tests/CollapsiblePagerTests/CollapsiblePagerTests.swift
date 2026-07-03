import Testing
@testable import CollapsiblePager

@Test func moduleReportsRewriteArchitectureVersion() {
    #expect(CollapsiblePagerModule.architectureVersion == "v1-rewrite")
}
