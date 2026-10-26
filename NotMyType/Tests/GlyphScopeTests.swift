import Foundation
func L(_ s:String)->String {s}
@main struct Probe {
 static func main() {
  let cases:[(GlyphScope,String)]=[(.hiragana,"あ"),(.katakana,"アｱㇰ"),(.emoji,"😀"),(.enclosed,"①㋐"),(.bullets,"•★"),(.brackets,"「」()“”"),(.kanji,"漢𠀀"),(.punctuation,"。、"),(.pictographs,"☀😀"),(.math,"+∑"),(.numbers,"1Ⅲ①"),(.currency,"¥€＄"),(.kana,"あアｱ"),(.signs,"⚠🚸"),(.letterlike,"℗℉"),(.arrows,"→⟶")]
  for (scope,text) in cases { for scalar in text.unicodeScalars { precondition(scope.includes(scalar),"\(scope): \(scalar)") } }
  precondition(!GlyphScope.hiragana.includes("ア"))
  precondition(!GlyphScope.katakana.includes("あ"))
  precondition(!GlyphScope.emoji.includes("1"))
  precondition(!GlyphScope.kanji.includes("あ"))
  precondition(GlyphScope.allCases.count==19)
  print("PASS 16 categories, overlaps, supplementary plane and exclusion checks")
 }
}
