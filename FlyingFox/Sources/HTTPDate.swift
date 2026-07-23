//
//  HTTPDate.swift
//  FlyingFox
//
//  Created by Ian Gordon on 22.07.26.
//

import Foundation

// Single source of truth for HTTP date formatting: IMF-fixdate per
// RFC 9110 §5.6.7, e.g. "Sun, 06 Nov 1994 08:49:37 GMT". The day of
// month is always two digits, the zone is the literal "GMT", and
// en_US_POSIX pins the English day/month names regardless of the
// system locale.
enum HTTPDate {

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
}
