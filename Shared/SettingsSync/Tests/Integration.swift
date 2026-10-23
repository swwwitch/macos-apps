import AppKit

func require(_ condition: Bool, _ name: String) { precondition(condition, name) }

@main struct IntegrationTests {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let journal = root.appendingPathComponent("App-Settings.sync")
        let initial: NSDictionary = ["one":1,"two":2,"encoded":"initial"]
        _ = try SettingsSyncJournal.synchronize(directory:journal,app:"App",device:"seed",baseline:initial,current:initial,seed:initial)
        let sync = SettingsSync()
        let defaults = sync.defaults
        let suite = defaults.volatileDomainNames // Ensure the test uses only the injected suite.
        _ = suite
        defaults.set(root.path, forKey:"settingsSyncFolder")
        for (key,value) in initial { defaults.set(value,forKey:key as! String) }
        var imports=0
        sync.onImport = {
            imports += 1
            if defaults.string(forKey:"encoded") == "raw" { defaults.set("normalized",forKey:"encoded") }
        }
        func pump(_ until: () -> Bool, _ label: String) {
            let deadline=Date().addingTimeInterval(8)
            while !until() && Date()<deadline { RunLoop.current.run(until:Date().addingTimeInterval(0.02)) }
            require(until(),label)
        }
        func idle() { pump({ !sync.synchronizing },"background sync completes") }
        sync.start(.init(keys:["one","two","encoded"],note:"",perMac:""));idle()
        let originalCount = try FileManager.default.contentsOfDirectory(atPath:journal.path).count
        defaults.set(10,forKey:"one");sync.check();idle()
        let sent = try SettingsSyncJournal.read(journal,app:"App")
        require(sent.values["one"] as? Int == 10,"local edit is written")
        _ = try SettingsSyncJournal.synchronize(directory:journal,app:"App",device:"B",baseline:initial,
             current:["one":1,"two":20,"encoded":"raw"],seed:initial)
        sync.check();idle()
        require(defaults.integer(forKey:"one")==10 && defaults.integer(forKey:"two")==20,"remote independent edit combines")
        require(defaults.string(forKey:"encoded")=="normalized","onImport normalizes once")
        let afterImport = try FileManager.default.contentsOfDirectory(atPath:journal.path).count
        let importCount=imports
        for _ in 0..<5 { sync.check();idle() }
        require(try FileManager.default.contentsOfDirectory(atPath:journal.path).count == afterImport,"normalization does not echo")
        require(imports==importCount,"unchanged remote snapshot does not reload UI")
        require(afterImport > originalCount,"local edits create immutable records")
        let bad=journal.appendingPathComponent("partial.plist");try Data("partial".utf8).write(to:bad)
        defaults.set(99,forKey:"one");sync.check();idle()
        require(sync.statusIsError && defaults.integer(forKey:"one")==99,"read failure retains unsent local edit")
        try FileManager.default.removeItem(at:bad);sync.check();idle()
        require(try !sync.statusIsError && (SettingsSyncJournal.read(journal,app:"App").values["one"] as? Int)==99,"failed edit retries successfully")
        // Restart against the same per-Mac defaults: an edit since the last observation survives.
        sync.stop();NotificationCenter.default.removeObserver(sync);defaults.set(root.path,forKey:"settingsSyncFolder");defaults.set(123,forKey:"one")
        let restarted=SettingsSync();restarted.defaults=defaults
        restarted.start(.init(keys:["one","two","encoded"],note:"",perMac:""))
        pump({!restarted.synchronizing},"restart finishes")
        require((try SettingsSyncJournal.read(journal,app:"App").values["one"] as? Int)==123,"restart keeps offline local change")
        // A queued old result cannot replace settings after Stop.
        _ = try SettingsSyncJournal.synchronize(directory:journal,app:"App",device:"C",baseline:nil,current:["one":500],seed:initial)
        restarted.check();restarted.stop()
        pump({!restarted.synchronizing},"stopped request finishes")
        require(defaults.integer(forKey:"one")==123,"stop rejects stale result")
        defaults.removePersistentDomain(forName:defaultsSuiteName)
        print("PASS: real sync controller, receive normalization/no echo, unchanged UI, failed read retry, restart/offline edit, stop cancels stale result")
    }
}
