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

import SwiftUI

@main
struct BMPTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 200, minHeight: 100)
        }
    }
}

struct ContentView: View {
    @State private var image1: NSImage?
    @State private var image2: NSImage?
    
    var xImage = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil) ?? NSImage(size: .zero)
    
    var body: some View {
        HStack {
            Image(nsImage: image1 ?? xImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(.black, width: 2)
                .background(Checkerboard().opacity(0.2))
                .clipped()
            Image(nsImage: image2 ?? xImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(.black, width: 2)
                .background(Checkerboard().opacity(0.2))
                .clipped()
        }
        .padding()
        .dropDestination(for: Data.self, action: { items, location in
            if let data = items.first {
                let bmp = BMPImage(bmpData: data)
                image1 = bmp?.cgImage().map({ NSImage(cgImage: $0, size: .zero) })
                image2 = NSImage(data: data)
            }
            return true
        })
    }
}

struct Checkerboard: Shape {
    func path(in rect: CGRect) -> Path {
        let size = 10.0
        let rows = Int(ceil(Double(rect.height) / size))
        let columns = Int(ceil(Double(rect.width) / size))
        var path = Path()
        
        for r in 0 ..< rows {
            for c in 0 ..< columns {
                if (r + c) % 2 == 0 {
                    path.addRect(CGRect(x: size * Double(c), y: size * Double(r), width: size, height: size))
                }
            }
        }

        return path
    }
}
