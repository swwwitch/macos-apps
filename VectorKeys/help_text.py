# coding: utf-8
# Canonical current help. Do not append historical instructions to the generated help.
HELP = {
"ja": """## 2つの編集画面
上部で「コンポーネント」と「アクション」を切り替えます。コンポーネントはスクリプトファイル（.jsx、.js、.jsxbin）または直接記入したExtendScriptコードです。同じコンポーネントを複数のアクションで共有できます。アクションは1つ以上のコンポーネントを順に実行し、キーボードショートカットを持ちます。コンポーネントを分類するものはカテゴリ、アクションを分類してパネル化するものはグループです。

## コンポーネント：4カラム
左からグループ、カテゴリ、アイテム、詳細です。グループはその中のアクションが使うコンポーネントを、カテゴリはコンポーネント自体の分類を絞り込みます。「すべて」で絞り込みを解除します。検索は名前とファイルパスを対象にします。列の境界をドラッグして幅を調整でき、アクション画面とは別にこのMacへ保存します。
- 左のグループ列の＋でグループを作成、右クリックで改名・削除できます。グループ削除はアクションを未分類へ移し、コンポーネントと原本ファイルを保持します。
- カテゴリ列の＋でコンポーネントのカテゴリを作成できます。カテゴリの削除もコンポーネントを消さず未分類へ移します。
- アイテム列の＋、ファイルメニュー、またはファイルのドロップで登録します。直接コードは「JavaScriptコードを追加」で登録します。コードは保存するだけでは実行しません。
- ⌘クリック・⇧クリックで複数選択し、右クリックまたは詳細からグループへ登録・カテゴリ一括変更・削除を行えます。グループへのドラッグでも各コンポーネントの単一アクションを登録し、同じ参照とグループの既存アクションは重複させません。
- アクションが参照しているコンポーネントは削除できません。混在した複数選択も一部だけ削除せず、使用中の項目を選択から外す必要があります。削除で原本ファイルを消すことはありません。
- 右詳細のタイトル直下にファイル名とコピーできるパスを表示します。Quick Look、Finder、関連付けアプリでソースを開く、ファイルの選び直しに対応します。バイナリのソース編集はできません。情報は常時表示し、概要だけ必要時に開きます。名前・カテゴリ・タグ・色・メモを編集できます。コードやファイル参照の変更は、それを使う全アクションに反映されます。

## スクリプトに渡す値
SW_で始まるユーザー変数は自動認識します。各行の候補メニューに変数名と初期値を表示し、選ぶとその行に名前と初期値を入れます。保存済み設定を自動では上書きしません。ファイルとコードに対応し、元コード変更時に候補を更新します。外部エディタで変更したファイルは「候補を再読み込み」で更新できます。対象は実行時差し替えが可能な単純var宣言のみで、コメント・文字列・複雑な式・同名の複数宣言は候補に含めません。
各欄は「変数名（省略可）」と値の組です。変数名を入れると、単独行の var 変数名 = 初期値; を実行用コードで差し替えます。元ファイルは変更しません。元の型に合わせ、数値は数値、文字列は入力した文字、真偽値はtrue／falseとして扱います。文字列の入力に引用符は不要です。不存在・同名の複数宣言・式の初期値・複数変数の同時宣言などは実行前エラーになります。ファイルはUTF-8テキストのみ対応し、#include・$.fileName・$.evalFileを使うファイルは対象外です。たとえばSTEP_SIGNに-1、STEP_MULTIPLIERに10を指定できます。変数名を空欄にした欄は従来の位置引数です。名前付きの欄を混ぜても位置を詰めません。
アクション内の各コンポーネントに「値 1」「値 2」「値 3」を設定できます。ファイル参照・直接コードの両方で、arguments[0]、arguments[1]、arguments[2]として文字列を受け取ります。同じコンポーネントでもアクションや呼出し位置ごとに異なる値を保持します。数値が必要なコードではNumber(arguments[0])などで変換します。途中の空欄は詰めず、全欄が空なら従来の引数なし実行です。

## アクション：3カラム
行の文字・余白をクリックして選択します。ドラッグは行末の三本線ハンドルから始めて、並べ替え先やグループへ落とします。⌘クリック・⇧クリックの複数選択にも対応します。
右クリックの「複製」で、選択したアクションを元の直後・同じグループへ複製します。複数選択も可能です。構成・順序・変数名・値を引き継ぎ、ホットキーと使用履歴、Keyboard Maestroとの連動は初期化します。共有コンポーネントは増やさず、元のアクションを保持します。⌘Zで取り消せます。
グループ、アクション一覧、詳細です。＋の「アクションを追加」から作成し、詳細の「登録済みコンポーネントから追加」で構成します。構成行のメニューから上へ・下へ・取り外し・コンポーネントを編集を選べます。取り外しても定義は残ります。実行は上から順番で、欠落・未対応・エラーがあれば停止し、残りだけを勝手に実行しません。
ホットキー欄をクリックしてキーを押し、Escで記録を取り消します。1回押し／2回押しと解除を設定でき、重複や登録失敗を表示します。アイテムのホットキーはIllustratorが前面のときに働きます。全体の一時停止は「ホットキーを使う」で操作します。［実行］はIllustratorを前面へ移して実行します。
一覧の「手動」で検索していないとき、行へドロップするとその行の前へ、一覧末尾の余白へ落とすと末尾へ並べ替えます。右クリックの上へ／下へも利用できます。グループへのドロップは所属変更です。複数選択の名前・回数・ホットキーのソート、区切りの追加、削除もできます。バージョン・回数・ファイル名の追加表示は表示設定から選び、初期値はOFFです。⌘Deleteは一覧の選択を削除し、テキスト編集中は文字入力を優先します。⌘Z／⇧⌘Zで一覧操作を取り消し・やり直します。

## パネルと最近使ったスクリプト
アクション画面でグループを選ぶと、右側でパネル有効化・表示ホットキー・動作を設定できます。動作は「開閉してアイテムのホットキーも使用」「開閉してアイテムのホットキーを無効」「開いて実行を受け付けたら閉じる」の3種類です。無効モードはパネルを閉じている間も対象グループに適用します。パネルはIllustratorが前面のときだけ表示し、ほかのアプリでは隠れます。パネル上部に検索と「ファイル名を追加」があります。最近使ったスクリプトは成功したアクションを最新順に最大10件表示し、同じアクションは重複しません。

## 監視・情報・統計
設定のウォッチフォルダーで指定フォルダーとサブフォルダーを15秒ごとに読み込み、コンポーネントを登録します。各階層名をタグに追加し、カテゴリ自動作成は任意です。除外名は1行1つ、初期値はsingle-functionとbackupです。隠し項目・シンボリックリンクは読みません。原本の移動や削除で登録を自動削除しません。登録コンポーネントを削除すると監視から再登録せず、Undoはこの除外も戻します。アクションだけの削除は監視へ影響しません。
ツールの情報更新は現在の画面の選択項目・絞り込んだグループ／カテゴリ・全件を対象にします。進行状況を表示し、手動で付けた名前を保持します。自動名はSCRIPT_DESCRIPTION_JAがあれば参照します。名前置換とKM番号削除も現在の画面の選択だけを対象にします。統計はアクションの使用回数・日時・名前・グループ・スクリプト名・パス・キーを表示し、列の表示切替と見出しのソートができます。行を開くとアクション画面へ移ります。

Keyboard Maestroの.kmmacrosファイルはファイルメニューから読み込めます。対応するファイル・コードの手順をアクションとコンポーネントへ取り込み、未対応のメニュー手順は実行しません。元のマクロは削除しません。元マクロの有効／無効はアクションを選択してツールから操作し、コンポーネント画面では操作しません。

## 設定・権限・終了
⌘,で設定を開き、起動・常駐・ログイン起動・アプリ呼び出しのキーなどを設定します。呼び出しキーは常駐中のアプリを表示するためのもので、未起動のアプリを起動するキーではありません。手動起動はメイン画面を表示し、ログイン起動は表示しません。Dockを隠す設定でもメイン・設定画面がある間は通常表示します。常駐中はウインドウを閉じてもアプリを終了せず、⌘Qで終了します。設定ウインドウは⌘Wで閉じられます。
Illustrator操作のオートメーション許可が必要な場合は、システム設定のプライバシーとセキュリティでVectorKeysのIllustrator操作を許可してください。ホットキー重複・原本不在・空コード・実行エラーはアプリ内で確認できます。最近の実行結果は終了すると消えますが、アクションの回数と最終成功日時は保存します。設定共有は一覧やファイルパス・個別キーを共有せず、表示など対象の設定だけを共有します。旧データ移行前のScripts.pre-components.json／Scripts.pre-workspaces.jsonは保全します。アップデート確認とヘルプはアプリメニューから利用できます。
""",
"en": """Click an action name or row space to select it. Start dragging from the three-line handle at the row end to reorder or move to a group. Command-click and Shift-click retain multiple selection.

Right-click Duplicate to copy selected actions immediately after their originals in the same groups. Component references, order and per-invocation names and values are retained. Hotkeys, usage history and Keyboard Maestro links are reset. Shared components and original actions are preserved. Undo is supported.

SW_ user variables are detected automatically. Each row has a menu showing names and defaults; choosing one fills that row only. Saved settings are never automatically overwritten. Files and inline code are supported. Use Reload Candidates after editing a file externally. Only supported simple var declarations appear; comments, strings, complex expressions and duplicate declarations are excluded.

Each row has an optional variable name and a value. A name replaces a standalone var name = literal; default in execution-only code; the original file is unchanged. Supported defaults are numbers, strings and booleans. Enter strings without quotes and booleans as true/false. Missing, ambiguous or complex declarations stop before execution. Named file overrides require UTF-8 text without #include, $.fileName or $.evalFile. Empty names keep positional arguments; mixed named slots do not shift positions.

Values Passed to Script: Each component invocation has Value 1, Value 2 and Value 3. Both files and inline code receive strings as arguments[0], arguments[1] and arguments[2]. Values belong to each invocation, not the shared component. Empty positions are preserved; all empty fields keep execution without arguments. Convert numeric values with Number() in your script.

## Components and actions
Switch workspaces at the top. A component is a .jsx, .js or .jsxbin file, or saved ExtendScript code. Components can be reused. An action runs one or more components in order and owns a hotkey. Categories organize components; groups organize actions and can become palettes.

## Four component columns
The columns are Groups, Categories, Items and Details. A group filters components referenced by its actions; a category filters the component's own classification. Select All to remove a filter. Search matches names and paths. Drag column boundaries to resize; component and action widths are stored separately on this Mac.
Use the group column plus button to create a group and its context menu to rename or delete it. Deleting a group keeps actions as ungrouped. Component categories have their own add, rename and delete controls. Files and code are registered from the item plus button, File menu or file drop. Saving code does not run it.
Command-click or Shift-click to select multiple items. Right-click or use Details to register them in a group, change their category or delete them. Dropping components onto a group creates a separate single-component action for each item, reusing identical references already in that group. Components keep their categories. Referenced components cannot be deleted; a mixed batch is rejected rather than partially deleted. Original files are never deleted by unregistering a component.
Details show the file name and selectable path below the title, Quick Look, Finder, opening with the associated source editor and relinking. Binary source editing is unavailable. Script information stays expanded; the overview can be opened separately. Edit names, categories, tags, colors, notes and code here. Editing a shared definition affects every referencing action.

## Three action columns
Groups, actions and details form the action workspace. Add an action, then choose registered components. Component-row menus move a step up/down, remove its reference or open the component editor. Definitions survive detaching. Runs follow the listed order and stop on missing, unsupported or failed steps; the app never silently runs only a remaining subset.
Click the hotkey field and press keys; Escape cancels recording. Assign one-press or two-press keys or clear them. Duplicate and failed registrations are shown. Item hotkeys work while Illustrator is frontmost. The main hotkey switch pauses them. Run brings Illustrator forward before execution.
With Manual order and an empty search, drop an action onto another row to place it before that row, or into the trailing gap to move it to the end. Up/Down context commands are also available. Dropping onto a group changes membership. Multi-selection supports sorting by name, usage and key letter. Add dividers or remove actions without deleting component definitions. Extra version, usage and filename display starts off and can be enabled in display options. Command-Delete removes selected list items while text editing keeps its normal behavior. Command-Z and Shift-Command-Z undo and redo list operations.

## Palettes and recent actions
In the action workspace, select a group to configure its palette, opening hotkey and behavior: toggle while keeping item keys, toggle with item keys blocked, or open and close after a run is accepted. Blocking applies even while the palette is closed. Palettes appear only when Illustrator is frontmost and hide in other apps. Palette search and Include Filenames are at the top. Recently Used Scripts lists up to ten distinct successfully executed actions, newest first.

## Watch folders, information and statistics
Watch folders scan every 15 seconds, including subfolders, and register components. Folder names become tags; automatic categories are optional. Excluded folder names are entered one per line, initially single-function and backup. Hidden files and symlinks are skipped. Missing originals are retained. Deleting a watched component suppresses automatic re-registration, and Undo restores suppression too. Deleting an action does not affect folder monitoring.
Information refresh targets selected items, the filtered classification or all items in the current workspace and shows progress. Manual names are retained. Automatic names use SCRIPT_DESCRIPTION_JA when present. Name replacement and KM numbering removal also target only the current workspace selection. Statistics show action usage, last success, names, groups, script names, paths and keys, with sortable optional columns. Opening a statistics row switches to the corresponding action.

Import Keyboard Maestro .kmmacros exports from File. Supported file/code steps become actions and components; unsupported menu steps are not executed. Original macros are retained. Tools can enable or disable the originals for selected actions; these controls are disabled in the component workspace.

## Settings, permissions and quitting
Command-comma opens Settings. Configure login launch, residency, Dock visibility and the app recall hotkey. The recall key works while VectorKeys is running; it is not a cold-launch shortcut. Manual launch shows the main window; login launch does not. Dock hiding keeps normal Dock behavior while a main or settings window exists. Closing a window can keep a resident app running; Command-Q quits. Command-W closes Settings.
If macOS requests Automation permission, allow VectorKeys to control Illustrator in Privacy & Security settings. Missing files, empty code, key conflicts and execution errors remain visible in the app. Recent result messages are not retained after quitting, but action counts and last-success times are saved. Settings sharing excludes the library, paths and individual item keys. Pre-migration Scripts.pre-components.json and Scripts.pre-workspaces.json backups are preserved. Help and update checks are available from the menus.
""",
"zh-Hans": """点击动作名称或行内空白以选择。从行末三条线手柄开始拖动以排序或移到组。支持Command和Shift多选。

右键选择复制，可将所选动作复制到原动作之后并保留所属组。保留组件引用、顺序以及每次调用的变量名和值，清除快捷键、使用记录和Keyboard Maestro关联。不复制共享组件，支持撤销。

自动识别SW_用户变量。各行的候选菜单显示名称和初始值，选择后仅填写该行，不自动覆盖已保存设置。支持文件和直接代码；外部编辑后可重新载入候选。仅显示支持的简单var声明，排除注释、字符串、复杂表达式和同名多次声明。

每行可输入变量名和值。填写名称时仅在执行代码中替换独立行 var 名称 = 字面值;，不修改原文件。支持数值、字符串与布尔值。字符串无需引号，布尔值请输入true/false。缺失、重名或复杂声明会在执行前停止。文件须为UTF-8文本且不依赖#include、$.fileName或$.evalFile。名称留空时仍作为位置参数传递，混合使用不改变位置。

传给脚本的值：每次组件调用可设置值 1、值 2、值 3。文件与直接代码均通过 arguments[0]、arguments[1]、arguments[2] 接收字符串。值属于各次调用，不修改共享组件。保留中间空值；全部为空时不传参数。数字请在脚本内用 Number() 转换。

## 组件与动作
顶部切换编辑界面。组件是.jsx、.js、.jsxbin文件或保存的ExtendScript代码，可以在多个动作中复用。动作按顺序执行一个或多个组件并设置快捷键。类别整理组件，组整理动作并可显示为面板。

## 组件的四列界面
从左到右是组、类别、项目、详情。组筛选该组动作引用的组件，类别筛选组件本身的分类，选择全部解除相应筛选。搜索匹配名称和路径。拖动列边界调整宽度，组件和动作界面的宽度分别保存在本机。
组列的加号用于新建组，右键可改名或删除。删除组保留动作并移至未分组。类别也可新建、改名和删除，删除类别保留组件。项目加号、文件菜单或文件拖入可注册文件；也可添加直接代码，保存代码不会执行。
按⌘或⇧多选，通过右键或详情批量注册到组、更改类别或删除。拖入组会为每个组件创建单独动作，同一组中已有相同引用时复用，不移动原类别。正在被动作引用的组件不能删除；混合批次不会只删除一部分，需要取消选择被引用的项目。删除注册不会删除原始文件。
详情在标题下显示文件名和可复制路径，可快速查看、在Finder显示、使用关联编辑器打开或重新选择文件。二进制代码不可编辑。脚本信息保持展开，概述可独立折叠。在此编辑名称、类别、标签、颜色、备注和代码；共享定义的修改影响所有引用动作。

## 动作的三列界面
左侧组、中间动作、右侧详情。先添加动作，再添加已注册组件。组件行菜单可上移、下移、移除引用或打开组件编辑器。移除引用保留定义。执行按顺序进行，遇到缺失、不支持或错误时停止，不会仅执行剩余部分。
点快捷键字段后按键，Esc取消记录，可设置单次或两次按键或清除。重复或注册失败会显示。项目快捷键仅在Illustrator前台时生效，主开关可暂停。执行按钮先将Illustrator切至前台。
选择手动排序并清空搜索后，将动作拖到另一行会放到该行之前，拖到末尾空白会移至末尾，也可用右键上移、下移。拖到组可改变所属。多选支持名称、次数、按键字母排序。可添加分隔线和删除动作，保留组件定义。额外的版本、次数、文件名显示默认关闭，可从显示选项开启。⌘Delete删除列表选择，文本编辑保持正常行为。⌘Z与⇧⌘Z撤销或重做。

## 面板与最近使用
在动作界面选择组后，配置面板、打开快捷键和行为：开关并允许项目快捷键、开关并禁用项目快捷键、打开后在接受执行时关闭。禁用模式在面板关闭时也适用。面板仅在Illustrator前台时显示，切到其他应用自动隐藏，顶部提供搜索和添加文件名。最近使用显示最多十个不同的成功执行动作，最新在前。

## 监视、信息与统计
每15秒读取监视文件夹和子文件夹并注册组件，目录名作为标签，可选自动创建类别。排除名每行一个，初始为single-function和backup。跳过隐藏文件和符号链接；原始文件丢失不会自动删除注册。删除监视组件会阻止重新注册，撤销同时恢复排除状态。删除动作不影响监视。
信息更新针对当前界面的所选项目、筛选分类或全部，并显示进度。手动名称保持，自动名称可读取SCRIPT_DESCRIPTION_JA。名称替换和删除KM编号只作用于当前界面的选择。统计显示动作的次数、最后成功时间、名称、组、脚本名、路径、快捷键，支持列开关和表头排序，打开一行会切到对应动作。

文件菜单可导入Keyboard Maestro的.kmmacros导出，支持的文件和代码步骤转为动作和组件，不执行不支持的菜单步骤。保留原始宏。选择动作后可从工具启用或禁用原始宏，组件界面禁用这些操作。

## 设置、权限与退出
⌘逗号打开设置，可配置登录启动、常驻、Dock显示及呼出快捷键。呼出键只在应用运行时有效，不负责冷启动。手动启动显示主窗口，登录启动不显示。即使隐藏Dock，存在主窗口或设置窗口时仍正常显示。关闭窗口可继续常驻，⌘Q退出，⌘W关闭设置。
需要自动化权限时，在系统设置的隐私与安全性中允许VectorKeys控制Illustrator。缺失文件、空代码、按键冲突及错误可在应用内查看。最近结果退出后清空，动作次数与最后成功时间保留。设置共享不包含列表、文件路径和项目快捷键，迁移前的Scripts.pre-components.json与Scripts.pre-workspaces.json备份会保留。可从菜单打开帮助和检查更新。
""",
"ko": """액션 이름이나 행의 빈 공간을 클릭해 선택합니다. 행 끝의 세 줄 핸들에서 드래그하여 순서를 바꾸거나 그룹으로 이동합니다. Command와 Shift 다중 선택을 유지합니다.

우클릭 복제로 선택한 액션을 원본 바로 뒤의 같은 그룹에 복제합니다. 컴포넌트 참조, 순서, 호출별 변수 이름과 값은 유지하며 단축키, 사용 기록, Keyboard Maestro 연결은 초기화합니다. 공유 컴포넌트와 원본은 유지하며 실행 취소를 지원합니다.

SW_ 사용자 변수를 자동 인식합니다. 각 행의 메뉴에 이름과 초기값을 표시하며 선택한 행만 채웁니다. 저장된 설정은 자동으로 덮어쓰지 않습니다. 파일과 직접 코드를 지원하며 외부 편집 후 후보 다시 불러오기를 사용할 수 있습니다. 지원되는 단순 var 선언만 표시하고 주석, 문자열, 복잡한 식, 중복 선언은 제외합니다.

각 행에는 선택적인 변수 이름과 값이 있습니다. 이름을 입력하면 실행용 코드에서 별도 줄의 var 이름 = 리터럴; 초기값만 바꾸며 원본은 변경하지 않습니다. 숫자, 문자열, 불리언을 지원합니다. 문자열은 따옴표 없이, 불리언은 true/false로 입력합니다. 없거나 중복되거나 복잡한 선언은 실행 전에 중단합니다. 파일은 #include, $.fileName, $.evalFile에 의존하지 않는 UTF-8 텍스트여야 합니다. 이름을 비우면 위치 인수이며 혼합해도 위치를 당기지 않습니다.

스크립트에 전달할 값: 각 컴포넌트 호출에 값 1, 값 2, 값 3을 설정합니다. 파일과 직접 코드 모두 arguments[0], arguments[1], arguments[2]로 문자열을 받습니다. 값은 공유 컴포넌트가 아닌 각 호출에 저장합니다. 중간의 빈 값은 유지하며 모두 비어 있으면 인수 없이 실행합니다. 숫자는 스크립트에서 Number()로 변환합니다.

## 컴포넌트와 액션
상단에서 편집 화면을 전환합니다. 컴포넌트는 .jsx, .js, .jsxbin 파일 또는 저장한 ExtendScript 코드이며 여러 액션에서 재사용할 수 있습니다. 액션은 하나 이상의 컴포넌트를 순서대로 실행하고 단축키를 가집니다. 카테고리는 컴포넌트를, 그룹은 액션을 분류합니다. 그룹은 팔레트로 표시할 수 있습니다.

## 컴포넌트의 네 열
왼쪽부터 그룹, 카테고리, 항목, 상세입니다. 그룹은 해당 그룹 액션이 참조하는 컴포넌트를, 카테고리는 컴포넌트 자체의 분류를 필터링합니다. 모두를 선택하면 필터가 해제됩니다. 검색은 이름과 경로를 대상으로 합니다. 경계를 드래그하여 열 너비를 조절하며 액션 화면과 별도로 이 Mac에 저장합니다.
그룹 열의 더하기로 그룹을 만들고 우클릭으로 이름 변경과 삭제를 합니다. 그룹을 삭제해도 액션은 남아 미분류로 이동합니다. 카테고리도 추가·이름 변경·삭제할 수 있으며 삭제해도 컴포넌트는 유지합니다. 항목 더하기, 파일 메뉴 또는 파일 드롭으로 등록하고 직접 코드를 추가할 수도 있습니다. 코드 저장만으로 실행하지 않습니다.
⌘ 또는 ⇧ 클릭으로 여러 항목을 선택한 후 우클릭이나 상세에서 그룹 등록, 카테고리 일괄 변경 또는 삭제를 합니다. 그룹으로 드래그하면 각 컴포넌트의 단일 액션을 만들며 같은 그룹의 같은 참조는 재사용합니다. 원래 카테고리는 바뀌지 않습니다. 참조 중인 컴포넌트는 삭제할 수 없고 혼합 선택은 일부만 삭제하지 않으므로 사용 중인 항목의 선택을 해제해야 합니다. 등록 삭제로 원본 파일은 지우지 않습니다.
제목 아래 파일 이름과 복사 가능한 경로를 표시합니다. Quick Look, Finder, 연결된 편집기로 소스 열기와 파일 다시 선택을 제공합니다. 바이너리 소스는 편집할 수 없습니다. 스크립트 정보는 펼쳐 두고 개요는 따로 열 수 있습니다. 이름·카테고리·태그·색·메모·코드를 여기서 편집하며 공유 정의의 변경은 모든 참조 액션에 반영됩니다.

## 액션의 세 열
그룹, 액션 목록, 상세로 구성됩니다. 액션을 만든 후 등록된 컴포넌트를 추가합니다. 구성 행 메뉴에서 위로·아래로·참조 제거·컴포넌트 편집을 선택합니다. 참조를 제거해도 정의는 남습니다. 순서대로 실행하고 누락·미지원·오류가 있으면 중지하며 남은 일부만 실행하지 않습니다.
단축키 필드를 클릭하고 키를 누릅니다. Esc로 기록을 취소하고 한 번·두 번 누르기 또는 해제를 설정합니다. 중복과 등록 실패를 표시합니다. 항목 단축키는 Illustrator가 앞에 있을 때 동작하며 전체 스위치로 일시 중지합니다. 실행 버튼은 Illustrator를 앞으로 가져옵니다.
수동 정렬과 빈 검색에서 다른 행으로 드롭하면 그 행 앞으로, 끝의 빈 공간에 드롭하면 맨 뒤로 이동합니다. 우클릭의 위로·아래로도 사용합니다. 그룹으로 드롭하면 소속을 바꿉니다. 다중 선택은 이름·횟수·키 문자 정렬을 지원합니다. 구분선과 액션 삭제도 가능하며 컴포넌트 정의는 유지합니다. 추가 버전·횟수·파일 이름은 기본 꺼짐이며 표시 옵션에서 켭니다. ⌘Delete는 목록 선택을 삭제하고 텍스트 편집은 일반 동작을 유지합니다. ⌘Z와 ⇧⌘Z로 취소·다시 실행합니다.

## 팔레트와 최근 사용
액션 화면에서 그룹을 선택하여 팔레트, 열기 단축키와 동작을 설정합니다. 항목 키를 허용하며 열고 닫기, 항목 키를 막으며 열고 닫기, 실행 접수 후 닫기 중 선택합니다. 차단 모드는 팔레트가 닫혀 있어도 적용됩니다. Illustrator가 앞에 있을 때만 표시하고 다른 앱에서는 숨깁니다. 위쪽에 검색과 파일 이름 추가가 있습니다. 최근 사용은 성공한 서로 다른 액션 최대 열 개를 최신순으로 표시합니다.

## 감시·정보·통계
감시 폴더와 하위 폴더를 15초마다 읽어 컴포넌트를 등록합니다. 폴더 이름은 태그가 되며 자동 카테고리는 선택 사항입니다. 제외 이름은 한 줄에 하나로 처음에는 single-function과 backup입니다. 숨김 파일과 심볼릭 링크는 제외하고 원본 누락으로 등록을 자동 삭제하지 않습니다. 감시 컴포넌트를 삭제하면 자동 재등록을 막고 Undo는 이 제외도 복원합니다. 액션 삭제는 감시에 영향을 주지 않습니다.
정보 갱신은 현재 화면의 선택, 필터 분류 또는 전체를 대상으로 진행률을 표시합니다. 수동 이름을 유지하고 자동 이름은 SCRIPT_DESCRIPTION_JA를 읽습니다. 이름 바꾸기와 KM 번호 제거도 현재 화면의 선택만 대상으로 합니다. 통계는 액션 횟수·마지막 성공·이름·그룹·스크립트 이름·경로·키를 표시하며 열 표시와 정렬을 지원합니다. 행을 열면 해당 액션 화면으로 이동합니다.

파일 메뉴에서 Keyboard Maestro .kmmacros 내보내기를 가져옵니다. 지원 파일과 코드 단계는 액션과 컴포넌트로 가져오고 미지원 메뉴 단계는 실행하지 않습니다. 원래 매크로는 유지합니다. 액션을 선택하고 도구에서 원래 매크로를 켜거나 끌 수 있으며 컴포넌트 화면에서는 비활성입니다.

## 설정·권한·종료
⌘쉼표로 설정을 열어 로그인 시작·상주·Dock 표시·앱 호출 키를 설정합니다. 호출 키는 실행 중인 앱에만 적용되며 종료된 앱을 시작하지 않습니다. 수동 시작은 주 창을 표시하고 로그인 시작은 표시하지 않습니다. Dock 숨김에서도 주 창이나 설정 창이 있으면 보통 앱처럼 표시합니다. 창을 닫아도 상주할 수 있고 ⌘Q로 종료하며 ⌘W로 설정을 닫습니다.
자동화 권한이 필요하면 시스템 설정의 개인정보 보호 및 보안에서 VectorKeys의 Illustrator 제어를 허용하세요. 누락 파일·빈 코드·키 충돌·실행 오류는 앱에서 확인합니다. 최근 결과는 종료하면 지워지지만 액션 횟수와 마지막 성공은 저장합니다. 설정 공유는 목록·경로·개별 키를 제외합니다. 이전 전 Scripts.pre-components.json과 Scripts.pre-workspaces.json 백업을 유지합니다. 메뉴에서 도움말과 업데이트 확인을 사용할 수 있습니다.
"""
}
