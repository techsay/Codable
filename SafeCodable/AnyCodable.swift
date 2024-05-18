import Foundation

// =========================================
// MARK: - AnyCodable
// =========================================

@frozen public struct AnyCodable: Codable {
    public let value: Any

    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }
}

extension AnyCodable: _AnyEncodable, _AnyDecodable {}

private func areAnyNullValuesEqual (lhs: Any, rhs: Any) -> Bool {
    switch (lhs, rhs) {
    case is (NSNull, NSNull), is (Void, Void):
        return true
    default:
        return false
    }
}

private func combineEqual<H, A>(_ value: H, _ valuer: A) -> Bool where H : Equatable, A : Equatable {
    if let rv = valuer as? H {
       return value == rv
    }
    return false
}

private func areAnyValuesEqual (lhs: Any, rhs: Any) -> Bool {
    if let l = lhs as? (any Equatable) , let r = rhs as? (any Equatable) {
        return combineEqual(l, r)
    }
    return false
}

extension AnyCodable: Equatable {
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        return areAnyNullValuesEqual(lhs: lhs.value, rhs: rhs.value) ? true : areAnyValuesEqual(lhs: lhs, rhs: rhs)
    }
}

extension AnyCodable: CustomStringConvertible {
    public var description: String {
        switch value {
        case is Void:
            return String(describing: nil as Any?)
        case let value as CustomStringConvertible:
            return value.description
        default:
            return String(describing: value)
        }
    }
}

extension AnyCodable: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch value {
        case let value as CustomDebugStringConvertible:
            return "AnyCodable(\(value.debugDescription))"
        default:
            return "AnyCodable(\(description))"
        }
    }
}

extension AnyCodable: ExpressibleByNilLiteral {}
extension AnyCodable: ExpressibleByBooleanLiteral {}
extension AnyCodable: ExpressibleByIntegerLiteral {}
extension AnyCodable: ExpressibleByFloatLiteral {}
extension AnyCodable: ExpressibleByStringLiteral {}
extension AnyCodable: ExpressibleByStringInterpolation {}
extension AnyCodable: ExpressibleByArrayLiteral {}
extension AnyCodable: ExpressibleByDictionaryLiteral {}

extension AnyCodable: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch value {
        case let value as any Hashable:
            hasher.combine(value)
        default:
            break
        }
    }
}


// =========================================
// MARK: - AnyDecodable
// =========================================

@frozen public struct AnyDecodable: Decodable {
    public let value: Any

    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }
}

@usableFromInline
protocol _AnyDecodable {
    var value: Any { get }
    init<T>(_ value: T?)
}

extension AnyDecodable: _AnyDecodable {}

extension _AnyDecodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.init(NSNull())
        } 
        if let value = AnyDecodableTypes.first(where: { ty in
            return (try? container.decode(ty)) != nil
        }) {
            self.init(try container.decode(value))
            return
        }
        if let array = try? container.decode([AnyDecodable].self) {
            self.init(array.map { $0.value })
        } else if let dictionary = try? container.decode([String: AnyDecodable].self) {
            self.init(dictionary.mapValues { $0.value })
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyDecodable value cannot be decoded")
        }
    }
}

extension AnyDecodable: Equatable {
    public static func == (lhs: AnyDecodable, rhs: AnyDecodable) -> Bool {
        return areAnyNullValuesEqual(lhs: lhs.value, rhs: rhs.value) ? true : areAnyValuesEqual(lhs: lhs, rhs: rhs)
    }
}

extension AnyDecodable: CustomStringConvertible {
    public var description: String {
        switch value {
        case is Void:
            return String(describing: nil as Any?)
        case let value as CustomStringConvertible:
            return value.description
        default:
            return String(describing: value)
        }
    }
}

extension AnyDecodable: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch value {
        case let value as CustomDebugStringConvertible:
            return "AnyDecodable(\(value.debugDescription))"
        default:
            return "AnyDecodable(\(description))"
        }
    }
}

extension AnyDecodable: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch value {
        case let value as any Hashable:
            hasher.combine(value)
        default:
            break
        }
    }
}

let AnyDecodableTypes: [SerialSafeLossStringCodable.Type] = [String.self, Int.self, Float.self, Bool.self, Double.self, Int8.self, Int16.self, Int64.self, UInt.self, UInt8.self, UInt16.self, UInt64.self]

extension AnyDecodable {
    
    func format<T: Decodable>(to type: T.Type) -> T? {
        let sv = String(describing: self.value)
        for ty in AnyDecodableTypes {
            if type == ty.self, let v = ty.init(sv) {
                return v as? T
            }
        }
        return nil
    }
    
    static func format<T: Hashable & Codable, A: Codable>(_ keyType: T.Type, _ valueType: A.Type, from decoder: Decoder) -> [T : A]? {
        if let dict = try? [String: AnyCodable].init(from: decoder), !dict.isEmpty {
            var kt:LosslessStringConvertible.Type?, vT:LosslessStringConvertible.Type?
            if let k = keyType as? any LosslessStringConvertible.Type, let v = valueType as? any LosslessStringConvertible.Type {
                kt = k
                vT = v
            } else {
                return nil
            }
            var list:[(LosslessStringConvertible?, LosslessStringConvertible?)] = []
            for (key, value) in dict {
                if let keyT = kt, let kv = keyT.init(key),
                   let valueT = vT, let vv = valueT.init(String(describing: value)) {
                    list.append((kv, vv))
                }
            }
            var vf:[T: A] = [:]
            for enm in list {
                if let k = enm.0 as? T, let v = enm.1 as? A {
                    vf[k] = v
                }
            }
            return vf
        }
        return nil
    }
    
    static func format<T: RawDefaultCodable>(decoder: Decoder, enumType tp: T.Type) -> T? {
        let dec = JSONDecoder()
        var aValue:SerialSafeLossStringCodable?
        if let _ = AnyDecodableTypes.first(where: { ty in
            aValue = try? ty.init(from: decoder)
            return aValue != nil
        }) {
            let vStr = String(describing: aValue ?? "")
            guard !vStr.isEmpty else { return nil }
            if let dv = type(of: T.defaultValue().rawValue) as? LosslessStringConvertible.Type,
               let vi = dv.init(vStr),
               let data = try? JSONSerialization.data(withJSONObject: ["key": vi], options: []),
                  let en = try? dec.decode([String: T].self, from: data), let v = en["key"]
            {
                return v
            }
        }
        return nil
    }
}



// =========================================
// MARK: - Encodable
// =========================================

@frozen public struct AnyEncodable: Encodable {
    public let value: Any

    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }
}

@usableFromInline
protocol _AnyEncodable {
    var value: Any { get }
    init<T>(_ value: T?)
}

extension AnyEncodable: _AnyEncodable {}

extension _AnyEncodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case is Void:
            try container.encodeNil()
        case let array as [Any?]:
            try container.encode(array.map { AnyEncodable($0) })
        case let dictionary as [String: Any?]:
            try container.encode(dictionary.mapValues { AnyEncodable($0) })
        case let value as Encodable:
            try container.encode(value)
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyEncodable value cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

extension AnyEncodable: Equatable {
    public static func == (lhs: AnyEncodable, rhs: AnyEncodable) -> Bool {
        return areAnyNullValuesEqual(lhs: lhs.value, rhs: rhs.value) ? true : areAnyValuesEqual(lhs: lhs, rhs: rhs)
    }
}

extension AnyEncodable: CustomStringConvertible {
    public var description: String {
        switch value {
        case is Void:
            return String(describing: nil as Any?)
        case let value as CustomStringConvertible:
            return value.description
        default:
            return String(describing: value)
        }
    }
}

extension AnyEncodable: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch value {
        case let value as CustomDebugStringConvertible:
            return "AnyEncodable(\(value.debugDescription))"
        default:
            return "AnyEncodable(\(description))"
        }
    }
}

extension AnyEncodable: ExpressibleByNilLiteral {}
extension AnyEncodable: ExpressibleByBooleanLiteral {}
extension AnyEncodable: ExpressibleByIntegerLiteral {}
extension AnyEncodable: ExpressibleByFloatLiteral {}
extension AnyEncodable: ExpressibleByStringLiteral {}
extension AnyEncodable: ExpressibleByStringInterpolation {}
extension AnyEncodable: ExpressibleByArrayLiteral {}
extension AnyEncodable: ExpressibleByDictionaryLiteral {}

extension _AnyEncodable {
    public init(nilLiteral _: ()) {
        self.init(nil as Any?)
    }

    public init(booleanLiteral value: Bool) {
        self.init(value)
    }

    public init(integerLiteral value: Int) {
        self.init(value)
    }

    public init(floatLiteral value: Double) {
        self.init(value)
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(value)
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(arrayLiteral elements: Any...) {
        self.init(elements)
    }

    public init(dictionaryLiteral elements: (AnyHashable, Any)...) {
        self.init([AnyHashable: Any](elements, uniquingKeysWith: { first, _ in first }))
    }
}

extension AnyEncodable: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch value {
        case let value as any Hashable:
            hasher.combine(value)
        default:
            break
        }
    }
}
