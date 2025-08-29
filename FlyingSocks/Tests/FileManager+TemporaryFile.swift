// Copyright 2019 The TensorFlow Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import FlyingSocks
import Foundation


extension FileManager {

#if canImport(WinSDK)
    func makeTemporaryDirectory(template: String = "FlyingSocks.XXXXXX") throws -> URL {
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)
        let url = temporaryDirectory.appendingPathComponent("FlyingSocks.\(suffix)", isDirectory: true)
        try createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }
    #else
    func makeTemporaryDirectory(template: String = "FlyingSocks.XXXXXX") throws -> URL {
        let base = temporaryDirectory.path
        let needsSlash = base.hasSuffix("/") ? "" : "/"
        var tmpl = Array((base + needsSlash + template).utf8CString)

        let url = tmpl.withUnsafeMutableBufferPointer { buf -> URL? in
            guard let p = buf.baseAddress, mkdtemp(p) != nil else { return nil }
            let path = String(cString: p)
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        guard let url = url else {
            throw SocketError.makeFailed("makeTemporaryDirectory()")
        }
        return url
    }
#endif
}

