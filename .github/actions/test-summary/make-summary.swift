#!/usr/bin/swift

import Foundation

let junit = CommandLine.arguments.count > 1 ? URL(filePath: CommandLine.arguments[1]) : nil
let coverage = CommandLine.arguments.count > 2 ? URL(filePath: CommandLine.arguments[2]) : nil

guard let junit else {
    print("usage: ./failed-tests <junit.xml>")
    exit(70)
}

let document = try XMLDocument(contentsOf: junit)
let testCases = try document.nodes(forXPath: "//testcase")
let failures = try document.nodes(forXPath: "//failure/..")

let table = makeTable(
  total: testCases.count,
  failed: failures.count,
  passed: testCases.count - failures.count
)
print(table)

for node in failures {
    guard let element = node as? XMLElement,
          let testClass = element.attribute(forName: "classname")?.stringValue,
          let testName = element.attribute(forName: "name")?.stringValue else {
        continue
    }

    print("::warning ::Failed Test: \(testClass).\(testName)()")
    let messages = element
        .elements(forName: "failure")
        .compactMap { $0.attribute(forName: "message")?.stringValue }

    print(messages.joined(separator: ". "))
}

if let coverage {
	let table = try makeTable(
	   name: coverage.lastPathComponent, 
	   coverage: JSONDecoder().decode(Coverage.self, from: Data(contentsOf: coverage))
	)
	print(table)	
}

func makeTable(
	total: Int,
	failed: Int,
	passed: Int,
	skipped: Int = 0
) -> String {
	"""
	<table>
	<tr><td></td><td><b>Tests</b></td><td><b>Passed</b> ✅</td><td><b>Skipped</b> ⏭️</td><td><b>Failed</b> ❌</td></tr>
	<tr><td>\(junit.lastPathComponent)</td><td>\(total) ran</td><td>\(passed) passed</td><td>\(skipped) skipped</td><td>\(failed) failed</td></tr>
	</table>
	"""
}

func makeTable(
	name: String,
	coverage: Coverage
) -> String {
	"""
	<table>
	<tr><td></td><td><b>Covered</b></td><td><b>Total</b></td><td><b>Coverage</b></td></tr>
	<tr><td>\(name)</td><td>\(coverage.covered)</td><td>\(coverage.count)</td><td>\(coverage.percentString)</td></tr>
	</table>
	"""
}

struct Coverage: Decodable {
	var count: Int
	var covered: Int
	var percent: Double

	init(from decoder: any Decoder) throws {
        var unkeyed = try decoder
		   .container(keyedBy: CodingKeys.self)
		   .nestedUnkeyedContainer(forKey: .data)
        let container = try unkeyed
		   .nestedContainer(keyedBy: CodingKeys.self)
		   .nestedContainer(keyedBy: CodingKeys.self, forKey: .totals)
           .nestedContainer(keyedBy: CodingKeys.self, forKey: .lines)

        self.count = try container.decode(Int.self, forKey: .count)
        self.covered = try container.decode(Int.self, forKey: .covered)
        self.percent = try container.decode(Double.self, forKey: .percent)
    }

    enum CodingKeys: String, CodingKey {
        case data
        case totals
		case lines
        case count
        case covered
        case percent
    }

	var percentString: String {
		let formatter = NumberFormatter()
		formatter.numberStyle = .percent
		formatter.maximumFractionDigits = 2
		return formatter.string(from: (percent / 100) as NSNumber) ?? "asdf"
	}
}
