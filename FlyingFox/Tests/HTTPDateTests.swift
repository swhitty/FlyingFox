//
//  HTTPDateTests.swift
//  FlyingFox
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/FlyingFox
//

@testable import FlyingFox
import Foundation
import Testing

struct HTTPDateTests {

    @Test
    func stringFromDate_isIMFFixdate() {
        // Example dates from RFC 9110 §5.6.7 and §6.6.1
        #expect(
            HTTPDate.string(from: Date(timeIntervalSince1970: 784111777)) == "Sun, 06 Nov 1994 08:49:37 GMT"
        )
        #expect(
            HTTPDate.string(from: Date(timeIntervalSince1970: 784887151)) == "Tue, 15 Nov 1994 08:12:31 GMT"
        )
    }

    @Test
    func stringFromDate_zeroPadsDayOfMonth() {
        #expect(
            HTTPDate.string(from: Date(timeIntervalSince1970: 1767323045)) == "Fri, 02 Jan 2026 03:04:05 GMT"
        )
    }

    @Test
    func stringFromDate_roundTripsThroughIMFFixdateParser() {
        let date = Date(timeIntervalSince1970: 784111777)
        let parser = DateFormatter()
        parser.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.locale = Locale(identifier: "en_US_POSIX")
        #expect(
            parser.date(from: HTTPDate.string(from: date)) == date
        )
    }
}
