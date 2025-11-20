// BMPImage
//
// Copyright (c) 2021 Leszek S
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import XCTest
@testable import BMPTest

final class BMPTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testImages() throws {
        let files = """
        a24.bmp
        a32.bmp
        g24c1.bmp
        g24c2.bmp
        g32c1.bmp
        g32c2.bmp
        g32c3.bmp
        g32c4.bmp
        g32c5.bmp
        g32c6.bmp
        pr24.bmp
        pr32.bmp
        w24.bmp
        """
        let allFiles = files.components(separatedBy: "\n")
        for file in allFiles {
            if let url = Bundle.main.url(forResource: file, withExtension: "") {
                if let data = try? Data(contentsOf: url) {
                    if let image = BMPImage(bmpData: data) {
                        print("Loaded \(file)")
                        checkBMPImage(image, test24FileName: "ref_test24_" + file, test32FileName: "ref_test32_" + file)
                    } else {
                        print("Not loaded \(file)")
                        XCTFail()
                    }
                }
            }
        }
    }
    
    func checkBMPImage(_ image: BMPImage, test24FileName: String, test32FileName: String) {
        XCTAssertEqual(image.width * image.height * 4, image.rgba.count)
        
        let currentDirectoryUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let test24FileUrl = currentDirectoryUrl.appendingPathComponent(test24FileName)
        let test32FileUrl = currentDirectoryUrl.appendingPathComponent(test32FileName)
        
        print("Generating BMP24 data")
        let bmp24 = image.bmp24Data()
        print("Saving BMP24 file: \(test24FileUrl)")
        try? bmp24.write(to: test24FileUrl)
        print("Reading BMP24 file: \(test24FileUrl)")
        guard let file24Data = try? Data(contentsOf: test24FileUrl) else {
            XCTFail()
            return
        }
        let image24 = BMPImage(bmpData: file24Data)
        XCTAssertNotNil(image24)
        
        print("Generating BMP32 data")
        let bmp32 = image.bmp32Data()
        print("Saving BMP32 file: \(test32FileUrl)")
        try? bmp32.write(to: test32FileUrl)
        print("Reading BMP32 file: \(test32FileUrl)")
        guard let file32Data = try? Data(contentsOf: test32FileUrl) else {
            XCTFail()
            return
        }
        let image32 = BMPImage(bmpData: file32Data)
        XCTAssertNotNil(image32)
    }
    
    func testSolidColorBitmap() throws {
        print("Generating solid color bitmap")
        guard let image = BMPImage(width: 200, height: 200, color: .init(r: 100, g: 150, b: 255, a: 100)) else {
            XCTFail()
            return
        }
        checkBMPImage(image, test24FileName: "testSolidColor24.bmp", test32FileName: "testSolidColor32.bmp")
    }
    
    func testGradientBitmap() throws {
        print("Generating gradient bitmap")
        guard let image = BMPImage(width: 1000, height: 1000, startColor: .init(r: 255, g: 255, b: 0, a: 200), endColor: .init(r: 255, g: 0, b: 255, a: 200), startPoint: .init(x: 0, y: 0), endPoint: .init(x: 1000, y: 1000)) else {
            XCTFail()
            return
        }
        checkBMPImage(image, test24FileName: "testSolidColor24.bmp", test32FileName: "testSolidColor32.bmp")
    }
    
    func testLargeBitmap() throws {
        print("Generating large bitmap")
        guard let image = BMPImage(width: 4096, height: 4096, color: .init(r: 50, g: 100, b: 150, a: 200)) else {
            XCTFail()
            return
        }
        checkBMPImage(image, test24FileName: "testLarge24.bmp", test32FileName: "testLarge32.bmp")
    }
    
    func testVariousOperations() throws {
        let currentDirectoryUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let test32FileUrl = currentDirectoryUrl.appendingPathComponent("testVariousOperations32.bmp")
        let test24FileUrl = currentDirectoryUrl.appendingPathComponent("testVariousOperations24.bmp")

        print("Generating rgba data")

        var gradient = [UInt8](repeating: 0, count: 100 * 100 * 4)
        for y in 0 ..< 100 {
            let rowOffset = y * 100 * 4
            let alpha = UInt8(255 * y / 100)
            for x in 0 ..< 100 {
                let offset = rowOffset + x * 4
                gradient[offset] = 255 // R
                gradient[offset + 1] = 0 // G
                gradient[offset + 2] = 0 // B
                gradient[offset + 3] = alpha // A
            }
        }
        let image = BMPImage(width: 100, height: 100, rgba: gradient)
        let bmp32 = image?.bmp32Data()
        XCTAssertNotNil(bmp32)
        
        print("Saving BMP32 file: \(test32FileUrl)")
        try? bmp32?.write(to: test32FileUrl)

        print("Reading BMP32 file: \(test32FileUrl)")
        guard let file32Data = try? Data(contentsOf: test32FileUrl) else {
            XCTFail()
            return
        }

        let imageFromFile32 = BMPImage(bmpData: file32Data)
        XCTAssertNotNil(imageFromFile32)
        let bmp24 = imageFromFile32?.bmp24Data()
        XCTAssertNotNil(bmp24)

        print("Saving BMP24 file: \(test24FileUrl)")
        try? bmp24?.write(to: test24FileUrl)
        
        print("Reading BMP24 file: \(test24FileUrl)")
        guard let file24Data = try? Data(contentsOf: test24FileUrl) else {
            XCTFail()
            return
        }

        let imageFromFile24 = BMPImage(bmpData: file24Data)
        XCTAssertNotNil(imageFromFile24)
    }
    
    func testCorruptedBitmap32DoNotCrash() throws {
        let bmp = BMPImage(width: 10, height: 10, color: .init(r: 0, g: 255, b: 0, a: 255))
        let bmpData = bmp?.bmp32Data()
        let bmpDataArray = [UInt8](bmpData ?? Data())
        for b in 0 ..< 255 {
            for i in 0 ..< bmpDataArray.count {
                var corruptedBmpDataArray = bmpDataArray
                corruptedBmpDataArray[i] = UInt8(b)
                let corruptedData = Data(corruptedBmpDataArray)
                let corruptedBMP = BMPImage(bmpData: corruptedData)
                if let corruptedBMP = corruptedBMP {
                    XCTAssertEqual(corruptedBMP.width * corruptedBMP.height * 4, corruptedBMP.rgba.count)
                }
            }
        }
    }
    
    func testCorruptedBitmap24DoNotCrash() throws {
        let bmp = BMPImage(width: 10, height: 10, color: .init(r: 255, g: 0, b: 255, a: 255))
        let bmpData = bmp?.bmp24Data()
        let bmpDataArray = [UInt8](bmpData ?? Data())
        for b in 0 ..< 255 {
            for i in 0 ..< bmpDataArray.count {
                var corruptedBmpDataArray = bmpDataArray
                corruptedBmpDataArray[i] = UInt8(b)
                let corruptedData = Data(corruptedBmpDataArray)
                let corruptedBMP = BMPImage(bmpData: corruptedData)
                if let corruptedBMP = corruptedBMP {
                    XCTAssertEqual(corruptedBMP.width * corruptedBMP.height * 4, corruptedBMP.rgba.count)
                }
            }
        }
    }

    func testSolidColorInitPerformance() throws {
        print("Generating solid color bitmap")
        measure {
            let image = BMPImage(width: 2000, height: 2000, color: .init(r: 100, g: 150, b: 200, a: 250))
            XCTAssertNotNil(image)
        }
    }
    
    func testGradientInitPerformance() throws {
        measure {
            print("Generating gradient bitmap")
            let image = BMPImage(width: 2000, height: 2000, startColor: .init(r: 255, g: 255, b: 0, a: 255), endColor: .init(r: 255, g: 0, b: 255, a: 255), startPoint: .init(x: 0, y: 0), endPoint: .init(x: 2000, y: 2000))
            XCTAssertNotNil(image)
        }
    }
}
