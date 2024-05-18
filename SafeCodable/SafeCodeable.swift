//
//  SerializationSafeDefault.swift
//  SafeCodeable
//
//  Created by 聂小波 on 2024/4/16.
//

import Foundation
import UIKit

//MARK: SerializationSafeDefault typealias

public
struct Safety {
    public typealias type<A: LosslessStringConvertible & Equatable & Codable> = SerializationSafeDefault<SerialSafeEmpty<A>>
    public typealias array = SerialSafeArray
    public typealias string = SerializationSafeDefault<SerialSafeEmpty<String>>
    public typealias int = SerializationSafeDefault<SerialSafeEmpty<Int>>
    public typealias float = SerializationSafeDefault<SerialSafeEmpty<Float>>
    public typealias double = SerializationSafeDefault<SerialSafeEmpty<Double>>
    public typealias int32 = SerializationSafeDefault<SerialSafeEmpty<Int32>>
    public typealias int64 = SerializationSafeDefault<SerialSafeEmpty<Int64>>
    public typealias bool = SerializationSafeDefault<SerialSafeEmpty<Bool>>
    public typealias enums = SerialSafeDefaultEnum
    public typealias dict = SerialSafeDefaultDictionary
}

public
struct Option {
    public typealias type<A: LosslessStringConvertible & Equatable & Codable> = SerialOptionSafeValue<SerialOptionSafeEmpty<A>>
    public typealias array = SerialOptionSafeArray
    public typealias model = SerialOptionSafeModel
    public typealias string = SerialOptionSafeValue<SerialOptionSafeEmpty<String>>
    public typealias int = SerialOptionSafeValue<SerialOptionSafeEmpty<Int>>
    public typealias float = SerialOptionSafeValue<SerialOptionSafeEmpty<Float>>
    public typealias double = SerialOptionSafeValue<SerialOptionSafeEmpty<Double>>
    public typealias int32 = SerialOptionSafeValue<SerialOptionSafeEmpty<Int32>>
    public typealias int64 = SerialOptionSafeValue<SerialOptionSafeEmpty<Int64>>
    public typealias bool = SerialOptionSafeValue<SerialOptionSafeEmpty<Bool>>
    public typealias enums = SerialOptionSafeDefaultEnum
    public typealias dict = SerialOptionSafeDictionary
}

//MARK: SerializationSafeDefault
public typealias SerialSafeLossStringCodable = LosslessStringConvertible & Codable
public protocol SerialSafeDefaultValueProvider {
    associatedtype Value: LosslessStringConvertible & Equatable & Codable
    static var losslessDecodableTypes: [(Decoder) -> SerialSafeLossStringCodable?] { get }
    static var `default`: Value { get }
}

@propertyWrapper
public struct SerializationSafeDefault<Provider: SerialSafeDefaultValueProvider>: Codable {
    public var wrappedValue: Provider.Value
    
    public init() {
        wrappedValue = Provider.default
    }

    public init(wrappedValue: Provider.Value) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            wrappedValue = Provider.default
            return
        }
        do {
            wrappedValue = try Provider.Value.init(from: decoder)
        } catch let error {
            debugLog(error)
            if let rawValue = Provider.losslessDecodableTypes.lazy.compactMap({ $0(decoder) }).first {
                if let value = Provider.Value.init("\(rawValue)") {
                    wrappedValue = value
                    return
                }
            }
            wrappedValue = Provider.default
        }
    }
}

extension SerializationSafeDefault: Equatable where Provider.Value: Equatable {}


//MARK: SerialSafeArray

@propertyWrapper
public struct SerialSafeArray<T: Codable> {
    public var wrappedValue: [T]

    public init(wrappedValue: [T] = []) {
        self.wrappedValue = wrappedValue
    }
}

extension SerialSafeArray: Decodable where T: Decodable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        var elements: [T] = []
        while !container.isAtEnd {
            do {
                let value = try container.decode(T.self)
                elements.append(value)
            } catch {
                if let v = try? container.decode(AnyDecodable.self), let fv = v.format(to: T.self) {
                    elements.append(fv)
                }
                debugLog(error)
            }
        }
        self.wrappedValue = elements
    }
}

extension SerialSafeArray: Encodable where T: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension SerialSafeArray: Equatable where T: Equatable { }
extension SerialSafeArray: Hashable where T: Hashable { }

//MARK: SerialOptionSafeValue
public protocol SerialOptionSafeDefaultValueProvider {
    associatedtype Value: LosslessStringConvertible & Equatable & Codable
    static var losslessDecodableTypes: [(Decoder) -> SerialSafeLossStringCodable?] { get }
    static var `default`: Value? { get }
}

@propertyWrapper
public struct SerialOptionSafeValue<Provider: SerialOptionSafeDefaultValueProvider>: Codable {
    public var wrappedValue: Provider.Value?

    public init() {
        wrappedValue = Provider.default
    }

    public init(wrappedValue: Provider.Value? = nil) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            wrappedValue = Provider.default
            return
        }
        do {
            wrappedValue = try Provider.Value.init(from: decoder)
        } catch let error {
            debugLog(error)
            if let rawValue = Provider.losslessDecodableTypes.lazy.compactMap({ $0(decoder) }).first,
               let value = Provider.Value.init("\(rawValue)") {
                wrappedValue = value
            } else {
                wrappedValue = Provider.default
            }
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension SerialOptionSafeValue: Equatable where Provider.Value: Equatable {}


//MARK: SerialOptionSafeModel
@propertyWrapper
public struct SerialOptionSafeModel<T: Codable>: Codable {
    public var wrappedValue: T?
    
    public init(wrappedValue: T? = nil) {
        self.wrappedValue = wrappedValue
    }
}

extension SerialOptionSafeModel {
    private struct AnyDecodableValue: Decodable {}

    public init(from decoder: Decoder) throws {
        wrappedValue = nil
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            wrappedValue = nil
            return
        }
        do {
            wrappedValue = try T.init(from: decoder)
        } catch {
            wrappedValue = nil
        }
    }
}

extension SerialOptionSafeModel {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension SerialOptionSafeModel: Equatable where T: Equatable { }
extension SerialOptionSafeModel: Hashable where T: Hashable { }

//MARK: SerialOptionSafeArray

@propertyWrapper
public struct SerialOptionSafeArray<T: Codable> {
    public var wrappedValue: [T]?

    public init(wrappedValue: [T]? = nil) {
        self.wrappedValue = wrappedValue
    }
}

extension SerialOptionSafeArray: Decodable where T: Decodable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [T] = []
        while !container.isAtEnd {
            do {
                let value = try container.decode(T.self)
                elements.append(value)
            } catch {
                if let v = try? container.decode(AnyDecodable.self), let fv = v.format(to: T.self) {
                    elements.append(fv)
                }
            }
        }
        self.wrappedValue = elements
    }
}

extension SerialOptionSafeArray: Encodable where T: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension SerialOptionSafeArray: Equatable where T: Equatable { }
extension SerialOptionSafeArray: Hashable where T: Hashable { }

//MARK: Safe Enum
public protocol RawDefaultCodable: RawRepresentable, Codable {
    static func defaultValue() -> Self
}

@propertyWrapper
public struct SerialSafeDefaultEnum<T: RawDefaultCodable>: Codable {
    public var wrappedValue: T
    public init(wrappedValue: T = T.defaultValue()) {
        self.wrappedValue = wrappedValue
    }
    
    public init(from decoder: Decoder) throws {
        do {
            wrappedValue = try T.init(from: decoder)
        } catch {
            if let v = AnyDecodable.format(decoder: decoder, enumType: T.self) {
                self.wrappedValue = v
                return
            }
            debugLog(error)
            self.wrappedValue = .defaultValue()
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

@propertyWrapper
public struct SerialOptionSafeDefaultEnum<T: RawDefaultCodable>: Codable {
    public var wrappedValue: T?
    public init(wrappedValue: T? = nil) {
        self.wrappedValue = wrappedValue
    }
    
    public init(from decoder: Decoder) throws {
        do {
            wrappedValue = try T.init(from: decoder)
        } catch {
            if let v = AnyDecodable.format(decoder: decoder, enumType: T.self) {
                self.wrappedValue = v
                return
            }
            debugLog(error)
            self.wrappedValue = nil
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

//MARK: Safe Dict
@propertyWrapper
public struct SerialSafeDefaultDictionary<T: Hashable & Codable, A: Codable>: Codable {
    public var wrappedValue: [T:A]
    public init(wrappedValue: [T:A] = [:]) {
        self.wrappedValue = wrappedValue
    }
    
    public init(from decoder: Decoder) throws {
        do {
            wrappedValue = try [T:A].init(from: decoder)
        } catch {
            if let vf = AnyDecodable.format(T.self, A.self, from: decoder) {
                self.wrappedValue = vf
                return
            }
            debugLog(error)
            self.wrappedValue = [:]
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

@propertyWrapper
public struct SerialOptionSafeDictionary<T: Hashable & Codable, A: Codable>: Codable {
    public var wrappedValue: [T:A]?
    public init(wrappedValue: [T:A]? = nil) {
        self.wrappedValue = wrappedValue
    }
    
    public init(from decoder: Decoder) throws {
        do {
            wrappedValue = try [T:A].init(from: decoder)
        } catch {
            if let vf = AnyDecodable.format(T.self, A.self, from: decoder) {
                self.wrappedValue = vf
                return
            }
            debugLog(error)
            self.wrappedValue = nil
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

//MARK: Key Decoding
extension KeyedDecodingContainer {
    func decode<P>(_: SerialOptionSafeValue<P>.Type, forKey key: Key) throws -> SerialOptionSafeValue<P> {
        if let value = try? decodeIfPresent(SerialOptionSafeValue<P>.self, forKey: key) {
            return value
        }
        return SerialOptionSafeValue()
    }
    
    func decode<P>(_: SerialOptionSafeModel<P>.Type, forKey key: Key) throws -> SerialOptionSafeModel<P> {
        if let value = try? decodeIfPresent(SerialOptionSafeModel<P>.self, forKey: key) {
            return value
        }
        return SerialOptionSafeModel(wrappedValue: nil)
    }
    func decode<P>(_: SerialOptionSafeArray<P>.Type, forKey key: Key) throws -> SerialOptionSafeArray<P> {
        if let value = try? decodeIfPresent(SerialOptionSafeArray<P>.self, forKey: key) {
            return value
        } 
        return SerialOptionSafeArray(wrappedValue: nil)
    }
    func decode<P>(_: SerialOptionSafeDefaultEnum<P>.Type, forKey key: Key) throws -> SerialOptionSafeDefaultEnum<P> {
        if let value = try? decodeIfPresent(SerialOptionSafeDefaultEnum<P>.self, forKey: key) {
            return value
        } 
        return SerialOptionSafeDefaultEnum(wrappedValue: nil)
    }
    
    func decode<P,V>(_: SerialOptionSafeDictionary<P,V>.Type, forKey key: Key) throws -> SerialOptionSafeDictionary<P,V> {
        if let value = try? decodeIfPresent(SerialOptionSafeDictionary<P,V>.self, forKey: key) {
            return value
        }
        return SerialOptionSafeDictionary(wrappedValue: nil)
    }
    
}

//MARK: Key Decoding
extension KeyedDecodingContainer {
    func decode<P: SerialSafeDefaultValueProvider>(_: SerializationSafeDefault<P>.Type, forKey key: Key) throws -> SerializationSafeDefault<P> {
        if let value = try? decodeIfPresent(SerializationSafeDefault<P>.self, forKey: key) {
            return value
        } 
        return SerializationSafeDefault()
    }
    
    func decode<P>(_: SerialSafeArray<P>.Type, forKey key: Key) throws -> SerialSafeArray<P> {
        if let value = try? decodeIfPresent(SerialSafeArray<P>.self, forKey: key) {
            return value
        }
        return SerialSafeArray(wrappedValue: [])
    }
    
    func decode<P>(_: SerialSafeDefaultEnum<P>.Type, forKey key: Key) throws -> SerialSafeDefaultEnum<P> {
        if let value = try? decodeIfPresent(SerialSafeDefaultEnum<P>.self, forKey: key) {
            return value
        } 
        return SerialSafeDefaultEnum(wrappedValue: P.defaultValue())
    }
    func decode<P,V>(_: SerialSafeDefaultDictionary<P,V>.Type, forKey key: Key) throws -> SerialSafeDefaultDictionary<P,V> {
        if let value = try? decodeIfPresent(SerialSafeDefaultDictionary<P,V>.self, forKey: key) {
            return value
        } 
        return SerialSafeDefaultDictionary(wrappedValue: [:])
    }
}

//MARK: Key Encoding
extension KeyedEncodingContainer {
    mutating func encode<P>(_ value: SerializationSafeDefault<P>, forKey key: Key) throws {
        guard value.wrappedValue != P.default else { return }
        try encode(value.wrappedValue, forKey: key)
    }
}


//MARK: Option Type
func OptionSafeDecodeBoolValue() -> (Decoder) -> SerialSafeLossStringCodable? {
    return {
        if let info = try? Float.init(from: $0), (0...1).contains(info) {
            return info == 1
        }
        if let info = try? String.init(from: $0) {
            if ["true", "yes", "1"].contains(info.lowercased()) {
                return true
            }
            if ["false", "no", "0"].contains(info.lowercased()) {
                return false
            }
        }
        return nil
    }
}

//MARK: Safe Type

@inline(__always)
private func SafeFormatDecode<T: SerialSafeLossStringCodable>(_: T.Type) -> (Decoder) -> SerialSafeLossStringCodable? {
    return { try? T.init(from: $0) }
}

private func SafeDecodeBoolFromValue(_ defaultValue: Bool) -> (Decoder) -> SerialSafeLossStringCodable? {
    return {
        if let info = try? Float.init(from: $0) {
            if defaultValue {
                return info != 0
            }
            return info == 1
        }
        if let info = try? String.init(from: $0) {
            if defaultValue {// 默认真
                return !["false", "no", "0"].contains(info.lowercased())
            }
            return ["true", "yes", "1"].contains(info.lowercased())
        }
        return defaultValue
    }
}

let SafeDecodeTypes: [SerialSafeLossStringCodable.Type] = [String.self, Int.self, Float.self, Bool.self, Double.self, Int8.self, Int16.self, Int64.self, UInt.self, UInt8.self, UInt16.self, UInt64.self]

var SafeFormatList: [(Decoder) -> SerialSafeLossStringCodable?] {
    return SafeDecodeTypes.map { SafeFormatDecode($0) }
}

private func SafeNilDefaultValue<A: LosslessStringConvertible & Equatable & Codable>(_ type: A.Type) -> A {
    if A.self == String.self { return "" as! A }
    if A.self == Bool.self { return false as! A }
    for type in SafeDecodeTypes {
        if type == A.self, let value = type.init("0") {
            return value as! A
        }
    }
    if let result = A("") { return result }
    fatalError("Failed to decode Unsupported object for type \(A.self)")
}

public
enum SerialSafeEmpty<A>: SerialSafeDefaultValueProvider where A: Codable, A: Equatable, A: LosslessStringConvertible  {
    public typealias Value = A
    public static var `default` : A {
        SafeNilDefaultValue(A.self)
    }
    public static var losslessDecodableTypes: [(Decoder) -> SerialSafeLossStringCodable?] {
        if A.self == Bool.self {
            return [
                SafeDecodeBoolFromValue(false)
            ]
        }
        return SafeFormatList
    }
}

public
enum SerialOptionSafeEmpty<A>: SerialOptionSafeDefaultValueProvider where A: Codable, A: Equatable, A: LosslessStringConvertible {
    public typealias Value = A
    public static var `default`: A? {return nil}
    public static var losslessDecodableTypes: [(Decoder) -> SerialSafeLossStringCodable?] {
        if A.self == Bool.self {
            return [
                OptionSafeDecodeBoolValue()
            ]
        }
        return SafeFormatList
    }
}

/// Log
public func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    debugPrint("Warring 数据类型不匹配：")
    debugPrint(items,separator,terminator)
}
