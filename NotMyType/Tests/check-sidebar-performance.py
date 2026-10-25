"""Compile actual navigation methods from both editions in an isolated observable-store harness."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
for app, target in [('NotMyType', 'NotMyType'), ('NotMyType Lite', 'NotMyTypeLite')]:
    source = (root / app / 'Sources' / target / 'LibraryStore.swift').read_text()
    sidebar = next(line for line in source.splitlines() if '@Published var sidebar:' in line)
    search = next(line for line in source.splitlines() if '@Published var searchText =' in line)
    start = source.index('    func selectSidebar(')
    end = source.index('\n    @Published var searchText', start)
    method = source[start:end]
    harness = '''import AppKit
import Combine
@MainActor final class Store {
 enum SidebarItem: Equatable { case all, project, smart }
 var shownCache: Int? = 1
 var faceCountCache: Int? = 1
 var filterCache: Int? = 1
 var listVersion = 0
 @Published var selection: Set<String> = ["selected-font"]
''' + sidebar + '\n' + search + '\n' + method + '''
}
@main struct Tests {
 @MainActor static func main() {
  let s = Store()
  s.searchText = "query"
  let version = s.listVersion
  for _ in 0..<1000 { s.selectSidebar(.all, keepingSearch: false) }
  precondition(s.listVersion == version && s.selection == ["selected-font"] && s.searchText == "query")
  s.sidebar = .all; s.searchText = "query"
  precondition(s.listVersion == version)
  s.selectSidebar(.project, keepingSearch: true)
  precondition(s.searchText == "query" && s.selection.isEmpty && s.listVersion == version + 1)
  s.selectSidebar(.smart, keepingSearch: false)
  precondition(s.searchText.isEmpty && s.listVersion == version + 3)
  let emptyVersion = s.listVersion
  s.selectSidebar(.all, keepingSearch: false)
  precondition(s.listVersion == emptyVersion + 1)
  print("PASS same category: 1000 selections, 0 invalidations; selection/search preserved; Option and normal navigation correct")
 }
}
'''
    with tempfile.TemporaryDirectory(prefix='nmt-sidebar-') as folder:
        path = Path(folder) / 'Test.swift'
        path.write_text(harness)
        binary = Path(folder) / 'test'
        subprocess.run(['swiftc', '-parse-as-library', str(path), '-o', str(binary)], check=True)
        print(app, flush=True)
        subprocess.run([str(binary)], check=True)
