import Foundation

private struct MobileProvision: Decodable {
    private enum CodingKeys: String, CodingKey {
        case teamIdentifier = "TeamIdentifier"
    }

    var teamIdentifier: [String]
}

func retrieveTeamIdentifier() -> String? {
    guard
        let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
        let contents = try? String(contentsOfFile: path, encoding: .isoLatin1),
        let start = contents.range(of: "<plist"),
        let end = contents.range(of: "</plist>", range: start.upperBound ..< contents.endIndex),
        let data = String(contents[start.lowerBound ..< end.upperBound]).data(using: .isoLatin1)
    else {
        return nil
    }

    guard
        let mobileProvision = try? PropertyListDecoder().decode(MobileProvision.self, from: data)
    else {
        return nil
    }

    return mobileProvision.teamIdentifier.first
}
