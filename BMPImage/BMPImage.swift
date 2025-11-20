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
// BMPImage v1.1.0
// This single file cross platform pure swift library is an implementation
// of reading and writing most common uncompressed 24-bit and 32-bit BMP
// image files.

import Foundation

/// Represents a BMP image.
public class BMPImage {
    /// Width of the image (value > 0).
    public private(set) var width: Int
    /// Height of the image (value > 0).
    public private(set) var height: Int
    /// RGBA array. Each pixel here is always represented by 4 bytes RGBA (bytes order is: R G B A R G B A ... and array size is always width * height * 4).
    public private(set) var rgba: [UInt8]
    
    /// Init with BMP file data.
    /// - Parameter bmpData: BMP file data.
    public init?(bmpData: Data) {
        guard let fileHeader = BitmapFileHeader(bmpData: bmpData),
              let infoHeader = BitmapInfoHeader(bmpData: bmpData),
              bmpData.count > fileHeader.bfOffBits
        else {
            return nil
        }
        
        let width = Int(infoHeader.biWidth)
        let heightAbs = Int(abs(infoHeader.biHeight))
        let topDown = infoHeader.biHeight < 0
        
        guard width > 0, heightAbs > 0, width <= Constants.maxDimension, heightAbs <= Constants.maxDimension else {
            return nil
        }
        
        let pixelDataRaw = bmpData.subdata(in: Int(fileHeader.bfOffBits) ..< bmpData.count)
        
        var rgba = [UInt8](repeating: 0, count: width * heightAbs * 4)
        
        if infoHeader.biBitCount == 24 {
            // 24-bit BGR with row padding -> RGBA
            let rowBytes = width * 3
            let paddedRowBytes = ((rowBytes + 3) / 4) * 4
            
            guard pixelDataRaw.count >= paddedRowBytes * heightAbs else {
                return nil
            }
            
            for y in 0 ..< heightAbs {
                let srcY = topDown ? y : (heightAbs - 1 - y)
                let srcOffset = srcY * paddedRowBytes
                let dstOffset = y * width * 4
                
                for x in 0 ..< width {
                    let srcBase = srcOffset + x * 3
                    let dstBase = dstOffset + x * 4
                    
                    let b = pixelDataRaw[srcBase]
                    let g = pixelDataRaw[srcBase + 1]
                    let r = pixelDataRaw[srcBase + 2]
                    
                    rgba[dstBase] = r
                    rgba[dstBase + 1] = g
                    rgba[dstBase + 2] = b
                    rgba[dstBase + 3] = 255
                }
            }
            
        } else if infoHeader.biBitCount == 32 {
            // 32-bit BGRA / BITFIELDS -> RGBA
            guard pixelDataRaw.count >= width * heightAbs * 4 else {
                return nil
            }
            
            let hasMasks = infoHeader.biCompression == BC.BI_BITFIELDS
            
            let redMask = infoHeader.biRedMask
            let greenMask = infoHeader.biGreenMask
            let blueMask = infoHeader.biBlueMask
            let alphaMask = infoHeader.biAlphaMask
            
            let rShift = UInt8(redMask.trailingZeroBitCount)
            let gShift = UInt8(greenMask.trailingZeroBitCount)
            let bShift = UInt8(blueMask.trailingZeroBitCount)
            let aShift = UInt8(alphaMask.trailingZeroBitCount)
            
            let rMax = redMask >> rShift
            let gMax = greenMask >> gShift
            let bMax = blueMask >> bShift
            let aMax = alphaMask >> aShift
            
            guard rMax <= 255, gMax <= 255, bMax <= 255, aMax <= 255 else {
                return nil
            }
            
            for y in 0 ..< heightAbs {
                let srcY = topDown ? y : (heightAbs - 1 - y)
                let srcOffset = srcY * width * 4
                let dstOffset = y * width * 4
                
                for x in 0 ..< width {
                    let base = srcOffset + x * 4
                    
                    let b = pixelDataRaw[base]
                    let g = pixelDataRaw[base + 1]
                    let r = pixelDataRaw[base + 2]
                    let a = pixelDataRaw[base + 3]
                    
                    if !hasMasks {
                        rgba[dstOffset + x * 4] = r
                        rgba[dstOffset + x * 4 + 1] = g
                        rgba[dstOffset + x * 4 + 2] = b
                        rgba[dstOffset + x * 4 + 3] = 255
                    } else {
                        let c = UInt32(b) | (UInt32(g) << 8) | (UInt32(r) << 16) | (UInt32(a) << 24)
                        rgba[dstOffset + x * 4] = UInt8(clamping: (c & redMask) >> rShift)
                        rgba[dstOffset + x * 4 + 1] = UInt8(clamping: (c & greenMask) >> gShift)
                        rgba[dstOffset + x * 4 + 2] = UInt8(clamping: (c & blueMask) >> bShift)
                        rgba[dstOffset + x * 4 + 3] = alphaMask != 0 ? UInt8(clamping: (c & alphaMask) >> aShift) : 255
                    }
                }
            }
        } else {
            // Invalid or unsupported BMP file
            return nil
        }
        
        self.width = width
        self.height = heightAbs
        self.rgba = rgba
    }
    
    /// Init with given width, height, RGBA pixels array.
    /// - Parameters:
    ///   - width: Image width.
    ///   - height: Image height.
    ///   - rgba: RGBA pixels array. Size of this array must be equal to width * height * 4.
    public init?(width: Int, height: Int, rgba: [UInt8]) {
        guard width > 0, height > 0, width <= Constants.maxDimension, height <= Constants.maxDimension, width * height * 4 == rgba.count else {
            return nil
        }
        self.width = width
        self.height = height
        self.rgba = rgba
    }
    
    public struct RGBA {
        public var r: UInt8
        public var g: UInt8
        public var b: UInt8
        public var a: UInt8
    }
    
    /// Init with given width, height, and color for creating a bitmap filled with color.
    /// - Parameters:
    ///   - width: Image width.
    ///   - height: Image height.
    ///   - color: Color to fill the bitmap.
    public init?(width: Int, height: Int, color: RGBA) {
        guard width > 0, height > 0, width <= Constants.maxDimension, height <= Constants.maxDimension else {
            return nil
        }
        self.width = width
        self.height = height
        
        let pixel: [UInt8] = [color.r, color.g, color.b, color.a]
        var row = [UInt8]()
        for _ in 0 ..< width {
            row.append(contentsOf: pixel)
        }
        var data = [UInt8]()
        for _ in 0 ..< height {
            data.append(contentsOf: row)
        }
        self.rgba = data
    }
    
    public struct Point {
        var x: Double
        var y: Double
    }
    
    /// Init with given width, height, colors, and points for creating a bitmap with gradient.
    /// - Parameters:
    ///   - width: Image width.
    ///   - height: Image height.
    ///   - startColor: Gradient start color.
    ///   - endColor: Gradient end color.
    ///   - startPoint: Gradient start point.
    ///   - endPoint: Gradient end point.
    public init?(width: Int, height: Int, startColor: RGBA, endColor: RGBA, startPoint: Point, endPoint: Point) {
        guard width > 0, height > 0, width <= Constants.maxDimension, height <= Constants.maxDimension else {
            return nil
        }
        
        self.width = width
        self.height = height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        
        let dx = Double(endPoint.x - startPoint.x)
        let dy = Double(endPoint.y - startPoint.y)
        let lengthSquared = dx * dx + dy * dy
        
        let sR = Double(startColor.r)
        let sG = Double(startColor.g)
        let sB = Double(startColor.b)
        let sA = Double(startColor.a)
        
        let eR = Double(endColor.r)
        let eG = Double(endColor.g)
        let eB = Double(endColor.b)
        let eA = Double(endColor.a)
        
        for y in 0 ..< height {
            let rowOffset = y * width * 4
            for x in 0 ..< width {
                let offset = rowOffset + x * 4
                
                let px = Double(x) - startPoint.x
                let py = Double(y) - startPoint.y
                var t = lengthSquared > 0 ? (px * dx + py * dy) / lengthSquared : 0
                t = max(0, min(1, t))
                
                let r = UInt8(sR * (1 - t) + eR * t)
                let g = UInt8(sG * (1 - t) + eG * t)
                let b = UInt8(sB * (1 - t) + eB * t)
                let a = UInt8(sA * (1 - t) + eA * t)
                data[offset] = r
                data[offset + 1] = g
                data[offset + 2] = b
                data[offset + 3] = a
            }
        }
        self.rgba = data
    }
    
    /// Returns 32-bit BMP image file data (with alpha).
    /// - Returns: 32-bit BMP file data.
    public func bmp32Data() -> Data {
        let pixelDataSize = width * height * 4
        let fileHeader = BitmapFileHeader.bmp32Header(pixelDataSize: UInt32(pixelDataSize))
        let infoHeader = BitmapInfoHeader.bmp32Header(width: Int32(width), height: Int32(-height), imageSize: UInt32(pixelDataSize))
        var bgra = [UInt8](repeating: 0, count: pixelDataSize)
        
        let width = self.width
        let height = self.height
        
        // RGBA -> BGRA
        for y in 0 ..< height {
            let srcRow = y * width * 4
            let dstRow = y * width * 4
            
            for x in 0 ..< width {
                let srcBase = srcRow + x * 4
                let dstBase = dstRow + x * 4
                
                let r = rgba[srcBase]
                let g = rgba[srcBase + 1]
                let b = rgba[srcBase + 2]
                let a = rgba[srcBase + 3]
                
                bgra[dstBase] = b
                bgra[dstBase + 1] = g
                bgra[dstBase + 2] = r
                bgra[dstBase + 3] = a
            }
        }
        var data = Data()
        data.append(fileHeader.headerData())
        data.append(infoHeader.headerData())
        data.append(contentsOf: bgra)
        return data
    }
    
    /// Returns 24-bit BMP image file data (without alpha).
    /// - Returns: 24-bit BMP file data.
    public func bmp24Data() -> Data {
        let rowBytes = width * 3
        let paddedRowBytes = ((rowBytes + 3) / 4) * 4
        let pixelArraySize = paddedRowBytes * height

        let fileHeader = BitmapFileHeader.bmp24Header(pixelDataSize: UInt32(pixelArraySize))
        let infoHeader = BitmapInfoHeader.bmp24Header(width: Int32(width), height: Int32(-height), imageSize: UInt32(pixelArraySize))

        var bgr = [UInt8](repeating: 0, count: pixelArraySize)

        let w = width
        let h = height
        
        // RGBA -> BGR with row padding
        for y in 0 ..< h {
            let inRow = y * w * 4
            let outRow = y * paddedRowBytes
            var inIndex = inRow
            var outIndex = outRow
            
            for _ in 0 ..< w {
                let r = rgba[inIndex]
                let g = rgba[inIndex + 1]
                let b = rgba[inIndex + 2]
                bgr[outIndex] = b
                bgr[outIndex + 1] = g
                bgr[outIndex + 2] = r
                inIndex += 4
                outIndex += 3
            }
        }
        
        var data = Data()
        data.append(fileHeader.headerData())
        data.append(infoHeader.headerData())
        data.append(contentsOf: bgr)
        return data
    }
    
}

private struct Constants {
    static let maxDimension = 8192
}

private struct BC {
    static let BITMAPFILEHEADER_SIZE: UInt32 = 14
    static let BITMAPINFOHEADER_SIZE: UInt32 = 40
    static let BITMAPV2INFOHEADER_SIZE: UInt32 = 52
    static let BITMAPV3INFOHEADER_SIZE: UInt32 = 56
    static let BITMAPTYPE_BM: UInt16 = 0x4D42
    static let BI_RGB: UInt32 = 0
    static let BI_BITFIELDS: UInt32 = 3
}

private struct BitmapFileHeader {
    var bfType: UInt16
    var bfSize: UInt32
    var bfReserved1: UInt16
    var bfReserved2: UInt16
    var bfOffBits: UInt32
}

private extension BitmapFileHeader {
    static func bmp24Header(pixelDataSize: UInt32) -> BitmapFileHeader {
        BitmapFileHeader(bfType: BC.BITMAPTYPE_BM, bfSize: BC.BITMAPFILEHEADER_SIZE + BC.BITMAPINFOHEADER_SIZE + pixelDataSize, bfReserved1: 0, bfReserved2: 0, bfOffBits: BC.BITMAPFILEHEADER_SIZE + BC.BITMAPINFOHEADER_SIZE)
    }
    
    static func bmp32Header(pixelDataSize: UInt32) -> BitmapFileHeader {
        BitmapFileHeader(bfType: BC.BITMAPTYPE_BM, bfSize: BC.BITMAPFILEHEADER_SIZE + BC.BITMAPV3INFOHEADER_SIZE + pixelDataSize, bfReserved1: 0, bfReserved2: 0, bfOffBits: BC.BITMAPFILEHEADER_SIZE + BC.BITMAPV3INFOHEADER_SIZE)
    }
    
    init?(bmpData: Data) {
        guard bmpData.count >= BC.BITMAPFILEHEADER_SIZE,
            let bfType = UInt16(littleEndianData: bmpData.subdata(in: 0 ..< 2)),
            let bfSize = UInt32(littleEndianData: bmpData.subdata(in: 2 ..< 6)),
            let bfReserved1 = UInt16(littleEndianData: bmpData.subdata(in: 6 ..< 8)),
            let bfReserved2 = UInt16(littleEndianData: bmpData.subdata(in: 8 ..< 10)),
            let bfOffBits = UInt32(littleEndianData: bmpData.subdata(in: 10 ..< 14)),
            bfType == BC.BITMAPTYPE_BM,
            bfOffBits >= BC.BITMAPFILEHEADER_SIZE + BC.BITMAPINFOHEADER_SIZE,
            bfOffBits < bmpData.count
        else {
            // Invalid or unsupported BMP file
            return nil
        }
        self.bfType = bfType
        self.bfSize = bfSize
        self.bfReserved1 = bfReserved1
        self.bfReserved2 = bfReserved2
        self.bfOffBits = bfOffBits
    }
    
    func headerData() -> Data {
        var data = Data()
        data.append(bfType.littleEndianData())
        data.append(bfSize.littleEndianData())
        data.append(bfReserved1.littleEndianData())
        data.append(bfReserved2.littleEndianData())
        data.append(bfOffBits.littleEndianData())
        return data
    }
}

private struct BitmapInfoHeader {
    var biSize: UInt32
    var biWidth: Int32
    var biHeight: Int32
    var biPlanes: UInt16
    var biBitCount: UInt16
    var biCompression: UInt32
    var biSizeImage: UInt32
    var biXPelsPerMeter: Int32
    var biYPelsPerMeter: Int32
    var biClrUsed: UInt32
    var biClrImportant: UInt32
    
    var biRedMask: UInt32
    var biGreenMask: UInt32
    var biBlueMask: UInt32
    var biAlphaMask: UInt32
}

private extension BitmapInfoHeader {
    static func bmp24Header(width: Int32, height: Int32, imageSize: UInt32) -> BitmapInfoHeader {
        BitmapInfoHeader(biSize: BC.BITMAPINFOHEADER_SIZE, biWidth: width, biHeight: height, biPlanes: 1, biBitCount: 24, biCompression: BC.BI_RGB, biSizeImage: imageSize, biXPelsPerMeter: 0, biYPelsPerMeter: 0, biClrUsed: 0, biClrImportant: 0, biRedMask: 0, biGreenMask: 0, biBlueMask: 0, biAlphaMask: 0)
    }
    
    static func bmp32Header(width: Int32, height: Int32, imageSize: UInt32) -> BitmapInfoHeader {
        BitmapInfoHeader(biSize: BC.BITMAPV3INFOHEADER_SIZE, biWidth: width, biHeight: height, biPlanes: 1, biBitCount: 32, biCompression: BC.BI_BITFIELDS, biSizeImage: imageSize, biXPelsPerMeter: 0, biYPelsPerMeter: 0, biClrUsed: 0, biClrImportant: 0, biRedMask: 0x00FF0000, biGreenMask: 0x0000FF00, biBlueMask: 0x000000FF, biAlphaMask: 0xFF000000)
    }
    
    init?(bmpData: Data) {
        guard bmpData.count >= BC.BITMAPFILEHEADER_SIZE + BC.BITMAPINFOHEADER_SIZE,
            let biSize = UInt32(littleEndianData: bmpData.subdata(in: 14 ..< 18)),
            let biWidth = Int32(littleEndianData: bmpData.subdata(in: 18 ..< 22)),
            let biHeight = Int32(littleEndianData: bmpData.subdata(in: 22 ..< 26)),
            let biPlanes = UInt16(littleEndianData: bmpData.subdata(in: 26 ..< 28)),
            let biBitCount = UInt16(littleEndianData: bmpData.subdata(in: 28 ..< 30)),
            let biCompression = UInt32(littleEndianData: bmpData.subdata(in: 30 ..< 34)),
            let biSizeImage = UInt32(littleEndianData: bmpData.subdata(in: 34 ..< 38)),
            let biXPelsPerMeter = Int32(littleEndianData: bmpData.subdata(in: 38 ..< 42)),
            let biYPelsPerMeter = Int32(littleEndianData: bmpData.subdata(in: 42 ..< 46)),
            let biClrUsed = UInt32(littleEndianData: bmpData.subdata(in: 46 ..< 50)),
            let biClrImportant = UInt32(littleEndianData: bmpData.subdata(in: 50 ..< 54)),
            biSize >= BC.BITMAPINFOHEADER_SIZE,
            biWidth > 0,
            biHeight != 0,
            biWidth <= Constants.maxDimension,
            abs(biHeight) <= Constants.maxDimension,
            biBitCount == 32 || biBitCount == 24,
            biCompression == BC.BI_RGB || biCompression == BC.BI_BITFIELDS
        else {
            // Invalid or unsupported BMP file
            return nil
        }
        
        self.biSize = biSize
        self.biWidth = biWidth
        self.biHeight = biHeight
        self.biPlanes = biPlanes
        self.biBitCount = biBitCount
        self.biCompression = biCompression
        self.biSizeImage = biSizeImage
        self.biXPelsPerMeter = biXPelsPerMeter
        self.biYPelsPerMeter = biYPelsPerMeter
        self.biClrUsed = biClrUsed
        self.biClrImportant = biClrImportant
        self.biRedMask = 0
        self.biGreenMask = 0
        self.biBlueMask = 0
        self.biAlphaMask = 0
        
        if biCompression == BC.BI_BITFIELDS && bmpData.count >= BC.BITMAPFILEHEADER_SIZE + BC.BITMAPV2INFOHEADER_SIZE {
            guard let biRedMask = UInt32(littleEndianData: bmpData.subdata(in: 54 ..< 58)),
                let biGreenMask = UInt32(littleEndianData: bmpData.subdata(in: 58 ..< 62)),
                let biBlueMask = UInt32(littleEndianData: bmpData.subdata(in: 62 ..< 66))
            else {
                // Invalid or unsupported BMP file
                return nil
            }
            self.biRedMask = biRedMask
            self.biGreenMask = biGreenMask
            self.biBlueMask = biBlueMask
        }
        
        if biCompression == BC.BI_BITFIELDS && biSize >= BC.BITMAPV3INFOHEADER_SIZE && bmpData.count >= BC.BITMAPFILEHEADER_SIZE + BC.BITMAPV3INFOHEADER_SIZE {
            guard let biAlphaMask = UInt32(littleEndianData: bmpData.subdata(in: 66 ..< 70))
            else {
                // Invalid or unsupported BMP file
                return nil
            }
            self.biAlphaMask = biAlphaMask
        }
    }
    
    func headerData() -> Data {
        var data = Data()
        data.append(biSize.littleEndianData())
        data.append(biWidth.littleEndianData())
        data.append(biHeight.littleEndianData())
        data.append(biPlanes.littleEndianData())
        data.append(biBitCount.littleEndianData())
        data.append(biCompression.littleEndianData())
        data.append(biSizeImage.littleEndianData())
        data.append(biXPelsPerMeter.littleEndianData())
        data.append(biYPelsPerMeter.littleEndianData())
        data.append(biClrUsed.littleEndianData())
        data.append(biClrImportant.littleEndianData())
        if biSize > BC.BITMAPINFOHEADER_SIZE {
            data.append(biRedMask.littleEndianData())
            data.append(biGreenMask.littleEndianData())
            data.append(biBlueMask.littleEndianData())
            data.append(biAlphaMask.littleEndianData())
        }
        return data
    }
}

private extension UInt32 {
    func littleEndianData() -> Data {
        return Data([UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 24) & 0xFF)])
    }
    init?(littleEndianData data: Data) {
        guard data.count == 4 else { return nil }
        self = (UInt32(data[3]) << 24) | (UInt32(data[2]) << 16) | (UInt32(data[1]) << 8) | UInt32(data[0])
    }
}

private extension UInt16 {
    func littleEndianData() -> Data {
        return Data([UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF)])
    }
    init?(littleEndianData data: Data) {
        guard data.count == 2 else { return nil }
        self = (UInt16(data[1]) << 8) | UInt16(data[0])
    }
}

private extension Int32 {
    func littleEndianData() -> Data {
        let bits = UInt32(bitPattern: self)
        return Data([UInt8(bits & 0xFF), UInt8((bits >> 8) & 0xFF), UInt8((bits >> 16) & 0xFF), UInt8((bits >> 24) & 0xFF)])
    }
    init?(littleEndianData data: Data) {
        guard data.count == 4 else { return nil }
        let bits = (UInt32(data[3]) << 24) | (UInt32(data[2]) << 16) | (UInt32(data[1]) << 8) | UInt32(data[0])
        self = Int32(bitPattern: bits)
    }
}

#if canImport(CoreGraphics)
import CoreGraphics

extension BMPImage {
    /// Init from CGImage.
    /// - Parameter cgImage: CGImage to convert.
    public convenience init?(cgImage: CGImage) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var data = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: &data, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8, bytesPerRow: 4 * cgImage.width, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        Self.unpremultiplyRGBA(&data)
        self.init(width: cgImage.width, height: cgImage.height, rgba: data)
    }
    
    /// Converts to CGImage.
    /// - Returns: Converted CGImage.
    public func cgImage() -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var data = rgba
        Self.premultiplyRGBA(&data)
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4 * width, space: colorSpace, bitmapInfo: bitmapInfo)
        return context?.makeImage()
    }
    
    private static func premultiplyRGBA(_ data: inout [UInt8]) {
        let count = data.count / 4
        for i in 0 ..< count {
            let base = i * 4
            let a = data[base + 3]
            let alpha = Double(a) / 255.0
            data[base + 0] = UInt8(Double(data[base + 0]) * alpha)
            data[base + 1] = UInt8(Double(data[base + 1]) * alpha)
            data[base + 2] = UInt8(Double(data[base + 2]) * alpha)
        }
    }
    
    private static func unpremultiplyRGBA(_ data: inout [UInt8]) {
        let count = data.count / 4
        for i in 0 ..< count {
            let base = i * 4
            let a = data[base + 3]
            let alpha = Double(a) / 255.0
            data[base + 0] = a == 0 ? 0 : UInt8(min(255, Double(data[base + 0]) / alpha))
            data[base + 1] = a == 0 ? 0 : UInt8(min(255, Double(data[base + 1]) / alpha))
            data[base + 2] = a == 0 ? 0 : UInt8(min(255, Double(data[base + 2]) / alpha))
        }
    }
}
#endif
