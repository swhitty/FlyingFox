//
//  HTTPRequestParameter.swift
//  FlyingFox
//
//  Created by Simon Whitty on 11/07/2024.
//  Copyright © 2024 Simon Whitty. All rights reserved.
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/FlyingFox
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

public protocol HTTPRequestParameter {
    init?(parameter: some StringProtocol)
}

extension String: HTTPRequestParameter {
    public init?(parameter: some StringProtocol) {
        self.init(parameter)
    }
}

extension Int: HTTPRequestParameter {
    public init?(parameter: some StringProtocol) {
        self.init(parameter)
    }
}

#if compiler(>=5.9)
extension HTTPRequest {

    func extractParameters<each P: HTTPRequestParameter>(
        for route: HTTPRoute,
        type: (repeat each P).Type = (repeat each P).self
    ) throws -> (repeat each P) {

        let indices = route.path.enumerated().compactMap { idx, comp in
            switch comp {
            case .parameter:
                return idx
            case .wildcard, .caseInsensitive:
                return nil
            }
        }

        var idx = 0
        return try (repeat getParameter(at: &idx, parameterIndices: indices, type: (each P).self))
    }

    private func getParameter<P: HTTPRequestParameter>(at index: inout Int, parameterIndices: [Int], type: P.Type) throws -> P {
        defer { index += 1 }

        guard parameterIndices.indices.contains(index) else {
            throw CancellationError()
        }

        let idx = parameterIndices[index]
        let nodes = path.split(separator: "/", omittingEmptySubsequences: true)
        guard nodes.indices.contains(idx),
              let param = P(parameter: nodes[idx]) else {
            throw CancellationError()
        }
        return param
    }
}
#endif
