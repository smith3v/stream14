import Foundation
import Testing

struct AppConfigurationTests {
    @Test func hostedAppHasExpectedIdentityAndMinimumOS() throws {
        let info = try #require(Bundle.main.infoDictionary)

        #expect(Bundle.main.bundleIdentifier == "com.smith3v.stream14")
        #expect(info["CFBundleShortVersionString"] as? String == "0.4")
        #expect(info["CFBundleVersion"] as? String == "5")
        #expect(info["MinimumOSVersion"] as? String == "27.0")
        #expect(info["UIDeviceFamily"] as? [Int] == [1])
    }

    @Test func setupSupportsPortraitAndBothLandscapeOrientations() throws {
        let orientations = try #require(
            Bundle.main.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String]
        )

        #expect(Set(orientations) == [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight"
        ])
    }
}
