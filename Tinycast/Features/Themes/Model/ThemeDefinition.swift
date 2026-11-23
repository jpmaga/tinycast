import Foundation

struct ThemeDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let variant: ThemeVariant
    var inherits: String?
    var colors: [ThemeSlot: ThemeColor] = [:]

    enum Issue: Hashable, Sendable {
        case invalidJSON
        case invalidField(String)
        case unknownKey(String)
        case invalidColor(String)
        case duplicateID(String)
        case missingParent(theme: String, parent: String)
        case incompatibleParent(theme: String, parent: String)
        case cycle([String])
        case unavailableSelection(id: String, variant: ThemeVariant)
    }

    static func decode(_ data: Data) -> (definition: Self?, issues: [Issue]) {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return (nil, [.invalidJSON])
        }
        let fields: Set<String> = ["id", "name", "variant", "inherits", "colors"]
        var issues = object.keys.filter { !fields.contains($0) }.sorted().map(Issue.unknownKey)
        func string(_ key: String) -> String? {
            guard let value = object[key] as? String,
                !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                issues.append(.invalidField(key))
                return nil
            }
            return value
        }

        let id = string("id")
        let name = string("name")
        let variantName = string("variant")
        let variant = variantName.flatMap(ThemeVariant.init(rawValue:))
        if variantName != nil && variant == nil { issues.append(.invalidField("variant")) }
        guard let id, let name, let variant else { return (nil, issues) }

        let inherits = object["inherits"].flatMap { _ in string("inherits") }
        var colors: [ThemeSlot: ThemeColor] = [:]
        if let value = object["colors"] {
            if let slots = value as? [String: Any] {
                for key in slots.keys.sorted() {
                    let path = "colors.\(key)"
                    guard let slot = ThemeSlot(rawValue: key) else {
                        issues.append(.unknownKey(path))
                        continue
                    }
                    guard let literal = slots[key] as? String, let color = ThemeColor(hex: literal) else {
                        issues.append(.invalidColor(path))
                        continue
                    }
                    colors[slot] = color
                }
            } else {
                issues.append(.invalidField("colors"))
            }
        }
        return (Self(id: id, name: name, variant: variant, inherits: inherits, colors: colors), issues)
    }
}
