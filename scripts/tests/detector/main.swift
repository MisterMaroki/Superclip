// Tests for ContentDetector (colour, phone, email, address and code tagging,
// plus timing checks on inputs that used to freeze the app).
// Run with scripts/tests/run.sh.
import Foundation
var failures = 0
func check(_ name: String, _ cond: Bool) { if !cond { failures += 1; print("FAIL: \(name)") } }
func rgb(_ s: String) -> [Int]? {
  ContentDetector.singleColor(in: s).map { [Int(($0.r * 255).rounded()), Int(($0.g * 255).rounded()), Int(($0.b * 255).rounded())] }
}
check("hex6", rgb("#FF5733") == [255, 87, 51])
check("hex3", rgb("#abc") == [170, 187, 204])
check("hex8", rgb("#FF573380") == [255, 87, 51])
check("hex padded + semicolon", rgb("  #F4F1E8;\n") == [244, 241, 232])
check("rgb commas", rgb("rgb(20, 20, 24)") == [20, 20, 24])
check("rgba", rgb("rgba(255,0,0,0.5)") == [255, 0, 0])
check("rgb spaces", rgb("rgb(20 20 24)") == [20, 20, 24])
check("rgb slash alpha", rgb("rgb(20 20 24 / 50%)") == [20, 20, 24])
check("hsl red", rgb("hsl(0, 100%, 50%)") == [255, 0, 0])
check("hsl blue", rgb("hsl(240, 100%, 50%)") == [0, 0, 255])
check("hsl grey", rgb("hsl(0, 0%, 50%)") == [128, 128, 128])
check("rgb out of range", rgb("rgb(300, 0, 0)") == nil)
check("sentence with hex is not a single colour", rgb("color: #FF5733 is nice") == nil)
check("issue ref not single", rgb("Fixes #123 today") == nil)
check("plain text", rgb("hello") == nil)
check("long css", rgb(String(repeating: "a { color: #fff; } ", count: 10)) == nil)
check("white prefers dark text", ContentDetector.singleColor(in: "#FFFFFF")!.prefersDarkText)
check("black prefers light text", !ContentDetector.singleColor(in: "#000000")!.prefersDarkText)
check("yellow prefers dark text", ContentDetector.singleColor(in: "#FFEB3B")!.prefersDarkText)
check("navy prefers light text", !ContentDetector.singleColor(in: "#1A237E")!.prefersDarkText)

// Tag detection
func hasColor(_ s: String) -> Bool { ContentDetector.detect(text: s).contains(.color) }
check("tag: lone hex", hasColor("#FF5733"))
check("tag: lone #123", hasColor("#123"))
check("tag: issue ref in sentence is not a colour", !hasColor("Fixes #123 in the parser"))
check("tag: PR list is not a colour", !hasColor("see #482 and #991"))
check("tag: hex in css", hasColor("a { color: #fa0; }"))
check("tag: 6-digit in sentence", hasColor("brand is #1A2B3C ok"))
check("tag: html entity", !hasColor("copy &#169; 2024"))
check("tag: anchor glued to word", !hasColor("page.html#abc"))
check("tag: rgb", hasColor("rgb(1, 2, 3)"))

// --- phone ---
func tags(_ s: String) -> Set<ContentTag> { ContentDetector.detect(text: s) }
check("phone: intl", tags("+1 (415) 555-0132").contains(.phone))
check("phone: dashed", tags("415-555-0132").contains(.phone))
check("phone: in sentence", tags("call me on 020 7946 0958 tomorrow").contains(.phone))
check("phone: iso date is not", !tags("2024-01-15").contains(.phone))
check("phone: slash date is not", !tags("01/02/2024").contains(.phone))
check("phone: ipv4 is not", !tags("192.168.1.100").contains(.phone))
check("phone: unix timestamp is not", !tags("1700000000").contains(.phone))
check("phone: decimal is not", !tags("3.14159265").contains(.phone))
check("phone: version id is not", !tags("claude-opus-4-5-20251101").contains(.phone))

// --- email ---
check("email: plain", tags("john.doe+x@example.co.uk").contains(.email))
check("email: in sentence", tags("write to hello@superclip.app please").contains(.email))
check("email: none", !tags("no at sign here").contains(.email))

// --- address ---
check("address: baker", tags("221 Baker Street").contains(.address))
check("address: penn", tags("1600 Pennsylvania Ave NW").contains(.address))
check("address: downing", tags("10 Downing St").contains(.address))
check("address: sentence is not", !tags("5 people found a way").contains(.address))
check("address: prose is not", !tags("we have 3 ways to drive there").contains(.address))

// --- code ---
let prose = "If you want to go for a walk, let me know.\nWe can try the new place.\nIn case it rains we stay in."
check("code: english paragraph is not code", !tags(prose).contains(.code))
let swift = "func greet(_ name: String) -> String {\n    let greeting = \"Hello\"\n    return greeting\n}"
check("code: swift is code", tags(swift).contains(.code))
let py = "def add(a, b):\n    total = a + b\n    return total"
check("code: python is code", tags(py).contains(.code))

// --- performance: inputs that used to backtrack for seconds ---
func timed(_ name: String, limit: Double, _ body: () -> Void) {
  let start = Date(); body(); let t = Date().timeIntervalSince(start)
  check("\(name) took \(String(format: "%.3f", t))s (limit \(limit)s)", t < limit)
}
let column = (1...3000).map { "\($0 * 37)" }.joined(separator: "\n")
timed("perf: 3000-number column", limit: 0.25) { _ = ContentDetector.detect(text: column) }
let tabbed = (1...3000).map { "\($0)" }.joined(separator: "\t")
timed("perf: 3000 tab-separated numbers", limit: 0.25) { _ = ContentDetector.detect(text: tabbed) }
let token = String(repeating: "aGVsbG8td29ybGQ", count: 4000)
timed("perf: 60k unbroken token", limit: 0.25) { _ = ContentDetector.detect(text: token) }
let rows = (1...4000).map { "row\($0) value total amount" }.joined(separator: "\n")
timed("perf: 4000 punctuation-free lines", limit: 0.25) { _ = ContentDetector.detect(text: rows) }
let spaced = (1...4000).map { "\($0) Alpha Beta Gamma Delta" }.joined(separator: " ")
timed("perf: capitalised words after numbers", limit: 0.25) { _ = ContentDetector.detect(text: spaced) }
print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
