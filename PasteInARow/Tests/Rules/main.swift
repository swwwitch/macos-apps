// LineRules: the KM macro's sample text and edge cases.
let sample = "イチゴ\n桃\nりんご\n\n・イチゴ\n・桃\n・りんご\n\n- イチゴ\n- 桃\n- りんご\n"
let fruits = ["イチゴ", "桃", "りんご"]
precondition(LineRules.lines(from: sample, trimIndent: true, stripMarkers: true) == fruits + fruits + fruits)
precondition(LineRules.lines(from: "1. a\n2.b\n10. c\n① d\n②e\n* f\n*g", trimIndent: true, stripMarkers: true) == ["a", "b", "c", "d", "e", "f", "*g"])
// Leading tabs, spaces and ideographic spaces; whitespace-only lines vanish.
precondition(LineRules.lines(from: "\t  a\n　b\n \t \n\n   \nc  ", trimIndent: true, stripMarkers: true) == ["a", "b", "c  "])
// CRLF and CR.
precondition(LineRules.lines(from: "a\r\nb\rc\r\n", trimIndent: true, stripMarkers: true) == ["a", "b", "c"])
// Options off: indent and markers stay, blank lines are still skipped.
precondition(LineRules.lines(from: "  - a\n\n・b", trimIndent: false, stripMarkers: false) == ["  - a", "・b"])
precondition(LineRules.lines(from: "  - a\n・b", trimIndent: false, stripMarkers: true) == ["  - a", "b"])
// Indented bullets: the indent goes first, then the marker (macro order).
precondition(LineRules.lines(from: "  - a\n    ・b", trimIndent: true, stripMarkers: true) == ["a", "b"])
// Only one marker per line, as the macro does; a hyphen without a space is kept.
precondition(LineRules.lines(from: "-a\n- - b", trimIndent: true, stripMarkers: true) == ["-a", "- b"])
precondition(LineRules.lines(from: "", trimIndent: true, stripMarkers: true).isEmpty)
precondition(LineRules.lines(from: "\n \n", trimIndent: true, stripMarkers: true).isEmpty)
precondition(LineRules.lines(from: "single", trimIndent: true, stripMarkers: true) == ["single"])
print("PASS: line cleanup matches the macro (sample, bullets, numbers, circled numbers, indent, CRLF/CR, options)")
