import AppKit
let args=CommandLine.arguments
let mode=args[1], path=args[2]
let url=URL(fileURLWithPath:path).standardizedFileURL
let bundle=Bundle(url:url)!
let bid=bundle.bundleIdentifier!
func matching() -> [NSRunningApplication] { NSRunningApplication.runningApplications(withBundleIdentifier:bid) }
if mode == "quit" {
 let apps=matching()
 if apps.isEmpty { print("NOT_RUNNING");exit(0) }
 for app in apps { guard app.terminate() else { print("TERMINATION_REFUSED \(app.processIdentifier)");exit(2) } }
 let deadline=Date().addingTimeInterval(15)
 while Date()<deadline {
  if apps.allSatisfy({$0.isTerminated}) { print("TERMINATED_GRACEFULLY");exit(0) }
  RunLoop.current.run(until:Date().addingTimeInterval(0.1))
 }
 print("STILL_RUNNING_NO_FORCE_QUIT");exit(3)
} else {
 let config=NSWorkspace.OpenConfiguration(); config.activates=false
 var finished=false, failed=false
 NSWorkspace.shared.openApplication(at:url,configuration:config) { app,error in
  if let error=error { print("LAUNCH_FAILED \(error)");failed=true }
  else if app?.bundleURL?.standardizedFileURL != url { print("WRONG_LAUNCH_PATH \(String(describing:app?.bundleURL))");failed=true }
  else { print("LAUNCHED \(app!.processIdentifier) \(url.path)") }
  finished=true
 }
 let deadline=Date().addingTimeInterval(20)
 while !finished && Date()<deadline { RunLoop.current.run(until:Date().addingTimeInterval(0.1)) }
 guard finished && !failed else {exit(4)}
 RunLoop.current.run(until:Date().addingTimeInterval(2))
 guard matching().contains(where:{$0.bundleURL?.standardizedFileURL == url && !$0.isTerminated}) else {print("EXITED_AFTER_LAUNCH");exit(5)}
 print("RUNNING_CONFIRMED")
}
