import Foundation

enum CodeGenerator {
    // No I, O, 0, 1 — avoids ambiguity on printed labels
    private static let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private static let codeLength = 4

    static func generateCode(existingCodes: Set<String> = []) -> String {
        var code: String
        repeat {
            code = String((0..<codeLength).map { _ in characters.randomElement() ?? Character("A") })
        } while existingCodes.contains(code)
        return code
    }
}
