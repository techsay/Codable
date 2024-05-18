# Codable
Swift Codable、 safe Codable 支持空安全、类型自动转化、model、Array、Enum

使用：添加SafeCodable文件夹

Usage：

```swift
//
//  SafeCodableTests.swift
//  SafeCodableTests
//
//  Created by Xiaobo Nie on 2024/5/18.
//

import XCTest

@testable import SafeCodable

final class SafeCodableTests: XCTestCase {
    typealias S = Safety // 非空
    typealias O = Option // 可选
    
    struct TestResponseModel: Codable {
       
        @S.type var code: Int
        @S.type var message: String
        
        // model
        @O.model<TestPersonInfo> var student
        
        // 模型数组
        @S.array<TestPersonInfo> var values
        @O.array<TestPersonInfo> var infos
        
        // Int数组
        @O.array<Int> var ids
        
        // 枚举 String
        @S.enums<Sex> var sex
        // 枚举 Int
        @O.enums<Sex2> var sex2
        
        
        // 字典 对应json 中 dic_a 和 dic_b
        @S.dict<String, AnyCodable> var dicA
        @S.dict<Int, String> var dicB
        
        // 元祖不支持直接解析，使用方法实现
        @O.string var street
        @O.string var city
        func address() -> (street: String?, city: String?) {
            (street, city)
        }
        
    }

    struct TestPersonInfo : Codable {
       
        // 使用统一风格
        @O.type var uid: Int?

        // 使用特定类型
        @O.int var type
        @O.string var country
        @O.bool var close

        // 使用统一风格
        @S.type var suc: Bool

        // 使用特定类型
        @S.string var name
        @S.int var age
        @S.bool var like

        // 设置默认值，对象init构建时生效，解析不生效
        @S.string var weightUnit = "kg"
        @S.float var weight = 55

        // 指定其他key进行解析(uid->id) ，尽量使用原始key，除非涉及关键词
        // 属性编辑完成后，通过方法补全设置CodingKeys， 后续增删都需要对应修改，不在CodingKeys范围内的均不会参与解析
        enum CodingKeys: String, CodingKey {
            case uid = "id"
            case type
            case country
            case close
            case suc
            case name
            case age
            case like
            case weightUnit
            case weight
        }
    }

    enum Sex: String, RawDefaultCodable {
        static func defaultValue() -> Sex {
            .unknown
        }
        case unknown
        case male
        case female
    }
    
    enum Sex2: Int, RawDefaultCodable {
        static func defaultValue() -> Sex2 {
            .unknown
        }
        case unknown = 0
        case male = 1
        case female = 2
    }
    
    var result: TestResponseModel?
    var resultNew: TestResponseModel?
    
    let resDic = """
      {
        "id": 2,
        "code": "200",
        "values": [
            {
                "id": 3.0,
                "type": 4.0,
                "country": "China",
                "suc": true
            },
            {
                "id": "9.0",
                "type": "8",
                "country": "USA",
                "suc": 0
            }
        ],
        "ids": [
            1,
            "2"
        ],
        "dic_a": {
            "id": 1,
            "name": {
                        "id": 1,
                        "name": "std 1"
                    }
        },
        "dic_b": {
            "1": 1,
            "2": "std 1",
            "3": "std 2"
        },
        "students": [
            {
                "id": 2,
                "name": "std 2"
            },
            {
                "id": 3,
                "name": "std 3"
            }
        ],
        "student": {
            "id": 1,
            "name": "std 1"
        },
        "street": "Longyang load.",
        "city": "ShangHai",
        "sex": "male",
        "sex2": "1"
    }
    """
    override func setUpWithError() throws {
        result = nil
    }

    override func tearDownWithError() throws {
        check(result: self.result, tip: "原始json数据解码")
        check(result: self.resultNew, tip: "编码后json数据解码")
        
        func check(result: TestResponseModel?, tip: String) {
            guard let result else {
                XCTFail(tip + " - 解析失败")
                return
            }
            XCTAssertEqual(result.code, 200, "类型不匹配解析失败")
            XCTAssertEqual(result.message, "", "String: key空设置默认值失败")
            XCTAssert(result.values.count > 0, "Array: 列表解析失败")
            // 空Array
            XCTAssertEqual(result.infos?.count, nil, "Array: 可选&空失败")
            XCTAssert(result.values.count == 2, "Array: 列表解析缺失")
            
            for (index, model) in result.values.enumerated() {
                switch index {
                case 0:
                    XCTAssert(model.suc, "Bool: <- true 解析失败")
                    XCTAssertEqual(model.type, 4, "Int <- 4.0  解析失败")
                    XCTAssertEqual(model.country, "China", "String 解析失败")
                    break
                case 1:
                    XCTAssert(!model.suc, "Bool: <- 0 解析失败")
                    XCTAssertEqual(model.type, 8, "Int <- \"8\"  解析失败")
                    break
                default:
                    break
                }
            }
            XCTAssert(result.ids?.count ?? 0 > 0, "ids: 列表解析缺失")
            XCTAssert(result.student != nil, "model: 解析缺失")
            XCTAssert(result.sex == .male, "enum: 解析缺失")
            XCTAssert(result.sex2 == .male, "enum: 解析缺失")
            
            XCTAssert(result.dicA.count > 0, "[String: AnyCodable]: 解析失败")
            XCTAssert(result.dicB.count > 0, "[Int: String]: 解析失败")
        }
    }

    func testExample() throws {
        do {
            let jsonData = resDic.data(using: .utf8)
            if let jsonData {
                
                let decoder = JSONDecoder()
                // 处理驼峰命名法的属性
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                // 原始json to model 解码
                result = try decoder.decode(TestResponseModel.self, from: jsonData)
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                do {
                    let jsonData = try encoder.encode(result)
                    // model to json 编码
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print(jsonString)
                        
                        // 编码后json to model 解码
                        resultNew = try decoder.decode(TestResponseModel.self, from: jsonData)
                        dump(resultNew)
                    }
                } catch {
                    XCTFail("Encoding failed: \(error.localizedDescription)")
                }
            }
        } catch {
            XCTFail("Error decoding JSON: \(error)")
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

```

