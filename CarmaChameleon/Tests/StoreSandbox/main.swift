import Foundation
import PDFKit
func L(_ key: String) -> String { key }
func check(_ ok: Bool, _ text: String) { guard ok else { fatalError(text) }; print("PASS: " + text) }
let fm = FileManager.default
let root = fm.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("StoreSmoke-"+UUID().uuidString)
try fm.createDirectory(at:root,withIntermediateDirectories:true)
defer { try? fm.removeItem(at:root) }
check(root.path.contains("/Containers/"), "parent running inside app container")
check(!StoreFolderAccess.isUserDocumentDestination(root), "container export destination rejected")
check(StoreFolderAccess.isUserDocumentDestination(URL(fileURLWithPath:"/Users/Shared/CarmaDocuments")), "external document destination accepted")
let bin = Bundle.main.resourceURL!.appendingPathComponent("bin")
func run(_ tool: String, _ args: [String]) throws {
 let p=Process();p.executableURL=bin.appendingPathComponent(tool);p.arguments=args;p.currentDirectoryURL=root
 let pipe=Pipe();p.standardError=pipe;p.standardOutput=FileHandle.nullDevice
 try p.run();let data=pipe.fileHandleForReading.readDataToEndOfFile();p.waitUntilExit()
 check(p.terminationStatus == 0, tool + " " + args.joined(separator:" ") + " " + (String(data:data,encoding:.utf8) ?? ""))
}
let input=root.appendingPathComponent("日本語.md")
let source="# 日本語タイトル\n\nHello **world**.\n\n![画像](sample.svg)\n"
try "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"120\" height=\"60\"><rect width=\"120\" height=\"60\" fill=\"#d8a530\"/></svg>".write(to:root.appendingPathComponent("sample.svg"),atomically:true,encoding:.utf8)
try source.write(to:input,atomically:true,encoding:.utf8)
try run("pandoc",["--version"]);try run("typst",["--version"])
for format in ["html5","docx","epub"] {
 let out=root.appendingPathComponent("result."+format)
 try run("pandoc",[input.path,"-t",format,"-o",out.path])
 check((try Data(contentsOf:out)).count > 0, "nonempty " + format)
}
let pdf=root.appendingPathComponent("result.pdf")
try run("pandoc",[input.path,"--pdf-engine",bin.appendingPathComponent("typst").path,"--pdf-engine-opt=--root=/","-V","mainfont=Hiragino Sans","-o",pdf.path])
check((PDFDocument(url:pdf)?.pageCount ?? 0)>0,"PDF contains pages")
check(try String(contentsOf:input,encoding:.utf8)==source,"source preserved")
