import Foundation
import Testing
@testable import QuickIconExporter

@Test func iconNameBeforeFilename() {
    let rules = FilenameRules(
        prefix: "icon",
        iconNamePosition: .beforeFilename,
        separator: .hyphen,
        spaceReplacement: .keep,
        removesUnwantedCharacters: false
    )
    let source = URL(fileURLWithPath: "/Sample App.app")
    #expect(IconExporter.outputBaseName(for: source, rules: rules) == "icon-Sample App")
}

@Test func iconNameAfterFilename() {
    let rules = FilenameRules(
        prefix: "artwork",
        iconNamePosition: .afterFilename,
        separator: .hyphen,
        spaceReplacement: .hyphen,
        removesUnwantedCharacters: false
    )
    let source = URL(fileURLWithPath: "/Sample App.app")
    #expect(IconExporter.outputBaseName(for: source, rules: rules) == "Sample-App-artwork")
}

@Test func replacesSpacesAndRemovesUnwantedCharacters() {
    let rules = FilenameRules(
        prefix: "my icon!",
        iconNamePosition: .beforeFilename,
        separator: .hyphen,
        spaceReplacement: .underscore,
        removesUnwantedCharacters: true
    )
    let source = URL(fileURLWithPath: "/Sample @ App.app")
    #expect(IconExporter.outputBaseName(for: source, rules: rules) == "my_icon-Sample__App")
}

@Test func usesUnderscoreSeparator() {
    let rules = FilenameRules(
        prefix: "icon",
        iconNamePosition: .afterFilename,
        separator: .underscore,
        spaceReplacement: .keep,
        removesUnwantedCharacters: false
    )
    let source = URL(fileURLWithPath: "/Sample App.app")
    #expect(IconExporter.outputBaseName(for: source, rules: rules) == "Sample App_icon")
}
