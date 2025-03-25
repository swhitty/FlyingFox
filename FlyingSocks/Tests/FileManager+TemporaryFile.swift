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
    func makeTemporaryFile() -> URL? {
        let dirPath = temporaryDirectory.appendingPathComponent("FlyingSocks.XXXXXX")
        return dirPath.withUnsafeFileSystemRepresentation { maybePath in
            guard let path = maybePath else { return nil }

            #if canImport(WinSDK)
            let pathMax = Int(MAX_PATH)
            #else
            let pathMax = Int(PATH_MAX)
            #endif

            var mutablePath = Array(repeating: Int8(0), count: pathMax)
            mutablePath.withUnsafeMutableBytes { mutablePathBufferPtr in
                mutablePathBufferPtr.baseAddress!.copyMemory(
                    from: path, byteCount: Int(strlen(path)) + 1)
            }
            guard mktemp(&mutablePath) != nil else { return nil }
            return URL(
                fileURLWithFileSystemRepresentation: mutablePath, isDirectory: false,
                relativeTo: nil)
        }
    }
}

func withTemporaryFile(f: (URL) -> ()) throws {
    guard let tmp = FileManager.default.makeTemporaryFile() else {
        throw SocketError.makeFailed("MakeTemporaryFile")
    }
    defer { try? FileManager.default.removeItem(atPath: tmp.path) }
    f(tmp)
}
