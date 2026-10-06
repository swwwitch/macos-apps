import Foundation
let fm = FileManager.default
let root = fm.temporaryDirectory.appendingPathComponent("FolderMover-tests-" + UUID().uuidString)
try fm.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: root) }
var assertions = 0
func check(_ v: @autoclosure () -> Bool, _ message: String) { assertions += 1; if !v() { fatalError(message) } }
func folder(_ name: String) throws -> URL { let u=root.appendingPathComponent(name);try fm.createDirectory(at:u,withIntermediateDirectories:true);return u }
func write(_ folder: URL,_ name: String,_ text: String = "payload") throws { try Data(text.utf8).write(to:folder.appendingPathComponent(name)) }
let s=try folder("source"), d=try folder("destination"), logs=try folder("logs")
for name in ["a.txt","日本語 空白.txt","-option","quote'\"file","line\nname","$(touch never)",".hidden"] { try write(s,name) }
try write(s,"conflict","source");try write(d,"conflict","destination")
let sub=s.appendingPathComponent("sub");try fm.createDirectory(at:sub,withIntermediateDirectories:true);try write(sub,"nested")
let collision=s.appendingPathComponent("collision");try fm.createDirectory(at:collision,withIntermediateDirectories:true);try write(collision,"original")
try fm.createDirectory(at:d.appendingPathComponent("collision"),withIntermediateDirectories:true)
try fm.createSymbolicLink(atPath:s.appendingPathComponent("broken").path,withDestinationPath:"/no/such/target")
var token=Cancellation()
let p=try MoveEngine.plan(source:s,destination:d,includeHidden:false,includeFolders:true,cancel:token)
check(p.items.count==10,"expected items including symlink")
let r=MoveEngine.run(p,cancel:token,journalDirectory:logs) { _ in }
check(r.moved==8 && r.skipped==2 && r.failed==0,"counts \(r)")
check(MoveEngine.exists(s.appendingPathComponent(".hidden")),"hidden retained")
let conflictText = try String(contentsOf:d.appendingPathComponent("conflict"),encoding:.utf8); check(conflictText=="destination","no clobber")
check(MoveEngine.exists(d.appendingPathComponent("sub/nested")),"folder moved whole")
check(!MoveEngine.exists(d.appendingPathComponent("collision/collision")),"no nesting")
check(MoveEngine.exists(s.appendingPathComponent("collision/original")),"source collision retained")
check(MoveEngine.exists(d.appendingPathComponent("broken")),"broken symlink preserved")
let child=try folder("source/child")
for dest in [s,child] { do { _ = try MoveEngine.plan(source:s,destination:dest,includeHidden:true,includeFolders:true,cancel:token); fatalError("must reject nested") } catch { assertions += 1 } }
let bulk=try folder("bulk"), output=try folder("out")
for i in 0..<2000 { try write(bulk,"file-\(i)") }
let bulkPlan=try MoveEngine.plan(source:bulk,destination:output,includeHidden:true,includeFolders:false,cancel:token)
var callbacks=0
let br=MoveEngine.run(bulkPlan,cancel:token,journalDirectory:logs) { _ in callbacks += 1 }
check(br.moved==2000 && br.failed==0 && br.processed==2000,"bulk")
check(callbacks<=18,"bounded process batches")
let cancelSource=try folder("cancel"), cancelDest=try folder("cancelOut")
for i in 0..<300 { try write(cancelSource,"f\(i)") }
token=Cancellation()
let cp=try MoveEngine.plan(source:cancelSource,destination:cancelDest,includeHidden:true,includeFolders:true,cancel:token)
let cr=MoveEngine.run(cp,cancel:token,journalDirectory:logs) { update in if update.moved>0 { token.cancel() } }
check(cr.cancelled && cr.moved==128,"safe batch cancellation")
let remaining = try fm.contentsOfDirectory(atPath:cancelSource.path); check(remaining.count==172,"remaining preserved")
let raceS=try folder("race"), raceD=try folder("raceOut")
try write(raceS,"changed")
let rp=try MoveEngine.plan(source:raceS,destination:raceD,includeHidden:true,includeFolders:true,cancel:Cancellation())
try fm.moveItem(at:raceS.appendingPathComponent("changed"),to:raceS.appendingPathComponent("old"));try write(raceS,"changed","replacement")
let rr=MoveEngine.run(rp,cancel:Cancellation(),journalDirectory:logs) { _ in }
check(rr.failed==1 && rr.moved==0,"replacement rejected")
let dirS=try folder("dirRace"), dirD=try folder("dirRaceOut")
try write(dirS,"file")
let dp=try MoveEngine.plan(source:dirS,destination:dirD,includeHidden:true,includeFolders:true,cancel:Cancellation())
try fm.moveItem(at:dirD,to:root.appendingPathComponent("oldDest"));try fm.createDirectory(at:dirD,withIntermediateDirectories:true)
let dr=MoveEngine.run(dp,cancel:Cancellation(),journalDirectory:logs) { _ in }
check(dr.error != nil && dr.moved==0,"destination identity")
let journalData=try Data(contentsOf:r.journal!)
check(String(decoding:journalData,as:UTF8.self).contains("finish"),"journal completed")
print("PASS: \(assertions) assertions, 2,000-item bulk move, conflicts, Unicode/quotes/newlines, symlinks, cancellation, source/destination replacement")
