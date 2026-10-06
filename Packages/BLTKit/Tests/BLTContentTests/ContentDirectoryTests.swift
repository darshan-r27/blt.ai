import Foundation
import Testing

struct ContentDirectoryTests {
    /// Repo root, found from this file's path: Packages/BLTKit/Tests/BLTContentTests/<file>.
    private var contentDirectory: URL {
        var url = URL(filePath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url.appending(path: "content", directoryHint: .isDirectory)
    }

    @Test func contentFolderHoldsJSONScenarioFiles() throws {
        let files = try FileManager.default.contentsOfDirectory(at: contentDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        #expect(!files.isEmpty)
        for file in files {
            precondition(file.isFileURL)
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
            #expect(object?["items"] is [Any])
        }
    }
}
