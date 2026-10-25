import SwiftUI
func L(_ text: String) -> String { text }
@MainActor final class SettingsWindow {static let shared=SettingsWindow();func show(){}}
struct SettingsSection<Content:View>:View {
 let content:Content
 init(_ title:String,@ViewBuilder content:()->Content){self.content=content()}
 var body:some View{content}
}
@main struct Tests {
 static func main() {
  precondition(FontServices.defaults.count == 13)
  precondition(Set(FontServices.defaults.map(\.url)).count == 13)
  precondition(FontServices.defaults.filter{$0.category == "vendors"}.count == 9)
  precondition(FontServices.defaults.filter{$0.category == "examples"}.count == 1)
  precondition(FontServices.defaults.filter{$0.category == "identify"}.count == 3)
  precondition(FontServices.links("").isEmpty)
  precondition(FontServices.links("[]").isEmpty)
  let id=UUID()
  let old=[FontServiceLink(name:"Adobe Fonts",url:"https://fonts.adobe.com/fonts"),FontServiceLink(name:"モリサワ",url:"https://morisawafonts.com/fonts/search/"),FontServiceLink(id:id,name:"My custom",url:"https://example.com")]
  let raw=String(decoding:try! JSONEncoder().encode(old),as:UTF8.self)
  let migrated=FontServices.links(raw)
  precondition(migrated.count == 1 && migrated[0].id == id)
  precondition(FontServices.links(FontServices.encode(migrated)).map(\.url)==["https://example.com"])
  let custom=[FontServiceLink(name:"Adobe Fonts",url:"https://fonts.adobe.com/fonts")]
  precondition(FontServices.links(FontServices.encode(custom)).count == 1)
  precondition(FontServices.links(FontServices.encode([])).isEmpty)
  print("PASS 13 links, 9/1/3 categories, old defaults migrate, custom IDs/URLs preserved, custom additions and deletions persist")
 }
}
