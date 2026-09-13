import XCTest
@testable import GoveeMenuBar

final class GoveeSceneLoaderTests: XCTestCase {
    private var scenesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scenes", isDirectory: true)
    }

    func testLoadsEveryRepositoryScene() throws {
        let result = GoveeSceneLoader.loadScenes(from: scenesDirectory)

        XCTAssertTrue(result.errors.isEmpty, result.errors.joined(separator: "\n"))
        XCTAssertEqual(result.presets.count, 8)
        XCTAssertEqual(Set(result.presets.map(\.id)), [
            "80s-tie-dye-flip",
            "80s-tie-dye-inverse",
            "80s-tie-dye-shift",
            "80s-tie-dye",
            "all-off",
            "all-white",
            "christmas",
            "movie-night",
        ])
    }

    func testParsesAllAndPerDeviceSettings() throws {
        let result = GoveeSceneLoader.loadScenes(from: scenesDirectory)
        let allWhite = try XCTUnwrap(result.presets.first { $0.id == "all-white" })
        let movie = try XCTUnwrap(result.presets.first { $0.id == "movie-night" })

        XCTAssertEqual(allWhite.apply["all"]?.on, true)
        XCTAssertEqual(allWhite.apply["all"]?.brightness, 100)
        XCTAssertEqual(allWhite.apply["all"]?.kelvin, 4000)
        XCTAssertEqual(movie.apply["floor-lamp-1"]?.brightness, 30)
        XCTAssertEqual(movie.apply["floor-lamp-1"]?.kelvin, 3000)
        XCTAssertEqual(movie.apply["neon-rope-black"]?.color, RGBColor(0, 0, 128))
    }
}
