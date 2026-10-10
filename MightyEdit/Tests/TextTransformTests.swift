import Foundation

@main struct TransformTests {
    static func main() {
        precondition(TextTransform.markdown.apply(TextTransform.bullet.apply("りんご\nみかん")) == "- りんご\n- みかん")
        for (input, expected) in [
            ("2026年01月07日（水）", "2026年1月7日（水）"),
            ("2026-01-07", "2026-1-7"),
            ("令和8年01月07日", "令和8年1月7日"),
            ("01月07日", "1月7日"), ("01-07", "1-7"),
            ("2026-1-7", "2026-1-7"), ("20260230", "20260230"),
            ("2026年02月30日", "2026年02月30日"), ("20260107", "20260107")
        ] {
            let result = TextTransform.removeDatePadding.apply(input)
            precondition(result == expected)
            precondition(TextTransform.removeDatePadding.apply(result) == result)
        }
        precondition(TextTransform.dateToCompact.apply("2026-1-7(水)") == "20260107")

        for (input, expected) in [
            ("2026年10月7日", "20261007"),
            ("2026-10-07", "20261007"),
            ("令和8年10月7日（水）", "20261007"),
            ("2024-02-29", "20240229"),
            ("2025-02-29", "2025-02-29"),
            ("10月7日", "10月7日"),
            ("20261007", "20261007"),
            ("20261007（水）", "20261007"),
            ("2026年10月7日（水曜日）", "20261007"),
            ("2026-10-07(Wed)", "20261007(Wed)"),
            ("2026-10-07(水曜日)", "20261007"),
            ("20250229（金）", "20250229（金）"),
            ("日程：2026年1月2日 / 2026-12-31", "日程：20260102 / 20261231")
        ] { precondition(TextTransform.dateToCompact.apply(input) == expected) }

        for input in ["", "a", "a\n", "b\na\na\n\n", "a\r\nb\r\n", "👩‍💻\nりんご\n　\n"] {
            let normalized = input.replacingOccurrences(of: "\r\n", with: "\n")
            for _ in 0..<20 {
                let shuffled = TextTransform.randomLines.apply(input)
                precondition(shuffled.components(separatedBy: "\n").sorted() == normalized.components(separatedBy: "\n").sorted())
                precondition(shuffled.hasSuffix("\n") || !normalized.hasSuffix("\n"))
            }
        }
        let dates = "2026年10月06日 / 2024-02-29"
        precondition(TextTransform.toggleDateFormat.apply(TextTransform.toggleDateFormat.apply(dates)) == dates)
        let unsorted = "item10\nitem1\nitem2\n"
        let ascending = TextTransform.sortLines.apply(unsorted)
        let descending = TextTransform.sortLines.apply(ascending)
        precondition(ascending == "item1\nitem2\nitem10\n")
        precondition(descending == "item10\nitem2\nitem1\n")
        precondition(TextTransform.sortLines.apply(descending) == ascending)
        let typography: [(TypographyOption, String, String)] = [
            (.narrowAlphanumerics, "ＡＢ１２", "AB12"),
            (.widenKana, "ﾊﾟﾋﾟﾌﾟﾍﾟﾎﾟ ｢ｶﾅ｣｡､", "パピプペポ ｢カナ｣｡､"),
            (.removeJapaneseSpaces, "日本語 ABC 日本語", "日本語ABC日本語"),
            (.trimBracketSpaces, "（  本 文　） (\ttext \t) 「　例 」｢ 中 ｣", "（本 文） (text) 「例」｢中｣"),
            (.trimBracketSpaces, "[ x ] { y } 【　z　】", "[x] {y} 【z】"),
            (.trimBracketSpaces, "（\n  本文\n）", "（\n  本文\n）"),
            (.timeColon, "9：05 23：59：59 １０：３０", "9:05 23:59:59 １０:３０"),
            (.timeColon, "12:34：56 12：34:56", "12:34:56 12:34:56"),
            (.timeColon, "24：00 9：60 12：30：99 123：45 見出し：本文", "24：00 9：60 12：30：99 123：45 見出し：本文"),
            (.parentheticalPeriod, "本文。（補足）。", "本文（補足）。"),
            (.parentheticalPeriod, "本文。(補足)。", "本文(補足)。"),
            (.parentheticalPeriod, "本文。（補足（内側））。", "本文（補足（内側））。"),
            (.parentheticalPeriod, "本文。（補足） 次の文。", "本文。（補足） 次の文。"),
            (.parentheticalPeriod, "本文。()。\n本文。（未完。", "本文。()。\n本文。（未完。"),
            (.parentheticalPeriod, "本文。（複数\n行）。", "本文。（複数\n行）。"),
            (.correctLongVowel, "カ-カ‐カ‑カ–カ—カ―カ−カｰカ─", "カーカーカーカーカーカーカーカーカー"),
            (.correctLongVowel, "A-B 1-2 あ- 漢- カー", "A-B 1-2 あ- 漢- カー"),
            (.widenPunctuation, "｡､()｢｣ . , 1,234.56", "。、（）「」 . , 1,234.56"),
            (.widenPunctuation, "日本語。（括弧）「引用」", "日本語。（括弧）「引用」")
        ]
        for (option, input, expected) in typography {
            let actual = option.apply(input)
            precondition(actual == expected, "Typography \(option): \(actual) != \(expected)")
        }
        let typographySource = "ＡＢＣ と ﾊﾟｿｺﾝ ( 補足 )\n時刻 １０：３０　コ-ヒ-､｢ 例 ｣｡\n本文。（補足）。"
        let typographyExpected = "ABCと パソコン （補足）\n時刻10:30コーヒー、「例」。\n本文（補足）。"
        precondition(TypographyOption.applyAll(typographySource, options: TypographyOption.allCases) == typographyExpected)
        precondition(TypographyOption.applyAll(typographyExpected, options: TypographyOption.allCases) == typographyExpected)
        precondition(TypographyOption.applyAll(typographySource, options: []) == typographySource)
        precondition(TypographyOption.applyAll("本文｡( 補足 )｡", options: TypographyOption.allCases) == "本文（補足）。")
        print("Passed \(typography.count) typography cases and combined-option checks")
        let dateCases: [(TextTransform, String, String)] = [
            (.dateToISO, "2026年10月6日", "2026-10-06"),
            (.dateToJapanese, "2026-10-06", "2026年10月06日"),
            (.dateToEra, "2019-04-30 2019-05-01", "平成31年04月30日 令和元年05月01日"),
            (.dateToEra, "1989-01-07 1989-01-08", "昭和64年01月07日 平成元年01月08日"),
            (.dateToEra, "1926-12-24 1926-12-25", "大正15年12月24日 昭和元年12月25日"),
            (.dateToEra, "1912-07-29 1912-07-30", "明治45年07月29日 大正元年07月30日"),
            (.dateToGregorian, "令和元年5月1日 平成31年4月30日", "2019年05月01日 2019年04月30日"),
            (.dateToGregorian, "令和元年4月30日 平成31年5月1日", "令和元年4月30日 平成31年5月1日"),
            (.dateToEra, "1873-01-01 1872-12-31", "明治6年01月01日 1872-12-31"),
            (.dateToGregorian, "明治5年12月31日", "明治5年12月31日"),
            (.removeDateYear, "2026年10月6日 2026-10-06 令和8年10月6日", "10月6日 10-06 10月6日"),
            (.removeDateYear, "2026年10月6日（火）", "10月6日（火）"),
            (.addDateYear, "10月6日 10-06 2024年10月6日", "2026年10月06日 2026-10-06 2024年10月6日"),
            (.weekdayShort, "2026年10月6日 令和8年10月6日 10-06", "2026年10月6日（火） 令和8年10月6日（火） 10-06（火）"),
            (.weekdayLong, "2026-10-06（火）", "2026-10-06（火曜日）"),
            (.weekdayShort, "2026-10-06（火曜日）", "2026-10-06（火）"),
            (.weekdayShort, "2026-10-06(月)", "2026-10-06（火）"),
            (.weekdayShort, "2026-10-06（火）", "2026-10-06（火）"),
            (.addDateYear, "10月6日（日曜日）", "2026年10月06日（火曜日）"),
            (.weekdayShort, "2026-02-29 2026年13月1日 2026年2月30日", "2026-02-29 2026年13月1日 2026年2月30日"),
            (.dateToISO, "前2026年10月6日\r\n後2026年10月7日", "前2026-10-06\r\n後2026-10-07"),
            (.addDateYear, "2026-2-3 12345年10月6日", "2026-2-3 12345年10月6日"),
            (.dateToISO, "10月6日", "10月6日")
        ]
        for (operation, input, expected) in dateCases {
            let actual = DateTransform.apply(input, operation: operation, currentYear: 2026)
            precondition(actual == expected, "Date \(operation): \(actual) != \(expected)")
        }
        print("Passed \(dateCases.count) date cases")
        let wraps: [(String, Int, String)] = [
            ("abcdef", 3, "abc\ndef"), ("abc", 3, "abc"),
            ("あいうえお", 2, "あい\nうえ\nお"),
            ("👩‍💻が🇯🇵✅", 2, "👩‍💻が\n🇯🇵✅"),
            ("abc\r\ndef\n\nghi\n", 2, "ab\nc\r\nde\nf\n\ngh\ni\n"),
            ("", 2, ""), ("abc", 0, "abc"), ("abc", 1, "a\nb\nc")
        ]
        for (input, count, expected) in wraps {
            precondition(TextTransform.wrappedText(input, count: count) == expected)
        }
        for style in TextTransform.specialLists {
            let input = "  バナナ\n\nりんご\nパイン\n"
            let output = style.apply(input)
            precondition(style.apply(output) == output, "Special list must be idempotent: \(style)")
            precondition(TextTransform.removeList.apply(output) == input, "Special list must be removable: \(style)")
            precondition(TextTransform.number.apply(output) == TextTransform.number.apply(input))
        }
        let longList = Array(repeating: "果物", count: 4000).joined(separator: "\n")
        precondition(TextTransform.romanUpper.apply(longList).components(separatedBy: "\n")[3998] == "MMMCMXCIX. 果物")
        precondition(TextTransform.romanUpper.apply(longList).components(separatedBy: "\n")[3999] == "(4000) 果物")
        precondition(TextTransform.blackCircled.apply(longList).components(separatedBy: "\n")[20] == "(21) 果物")
        precondition(TextTransform.circledAlphabet.apply(longList).components(separatedBy: "\n")[26] == "(27) 果物")
        precondition(TextTransform.kanji.apply(longList).components(separatedBy: "\n")[100] == "百一、果物")
        let cases: [(TextTransform, String, String)] = [
            (.camelCase, "hello world", "helloWorld"),
            (.camelCase, "Hello World", "helloWorld"),
            (.camelCase, "HELLO WORLD", "helloWorld"),
            (.camelCase, "hello-world_test", "helloWorldTest"),
            (.camelCase, "helloWorld", "helloWorld"),
            (.camelCase, "HelloWorld", "helloWorld"),
            (.camelCase, "XMLHttpRequest", "xmlHttpRequest"),
            (.camelCase, "get HTTP response", "getHttpResponse"),
            (.camelCase, "version 2 number", "version2Number"),
            (.camelCase, "  hello   world  \r\n\tFOO_BAR\n\n", "  helloWorld  \r\n\tfooBar\n\n"),
            (.camelCase, "hello\tworld\u{2028}new title", "helloWorld\u{2028}newTitle"),
            (.camelCase, "日本語 hello world。next item!", "日本語 helloWorld。nextItem!"),
            (.camelCase, "hello, world", "hello, world"),
            (.camelCase, "", ""),
            (.toggleDateFormat, "2026年10月06日", "2026-10-06"),
            (.toggleDateFormat, "2026-10-06", "2026年10月06日"),
            (.toggleDateFormat, "2026年1月2日", "2026-01-02"),
            (.toggleDateFormat, "予定：2026年10月6日（火）\r\n締切2026-12-01。", "予定：2026-10-06（火）\r\n締切2026年12月01日。"),
            (.toggleDateFormat, "2024-02-29 2000年2月29日", "2024年02月29日 2000-02-29"),
            (.toggleDateFormat, "2026-02-29 1900年2月29日 2026-04-31", "2026-02-29 1900年2月29日 2026-04-31"),
            (.toggleDateFormat, "2026-00-01 2026-13-01 2026年1月0日 0000-01-01", "2026-00-01 2026-13-01 2026年1月0日 0000-01-01"),
            (.toggleDateFormat, "12026-01-02 2026-01-023 12026年1月2日", "12026-01-02 2026-01-023 12026年1月2日"),
            (.toggleDateFormat, "0001-01-01 9999年12月31日", "0001年01月01日 9999-12-31"),
            (.toggleDateFormat, "2026/10/06 2026-1-2 ２０２６年１０月６日", "2026/10/06 2026-1-2 ２０２６年１０月６日"),
            (.toggleDateFormat, "", ""),
            (.sortLines, "item10\nitem2\nitem1\n", "item1\nitem2\nitem10\n"),
            (.sortLines, "a\nb\nc", "c\nb\na"),
            (.sortLines, "a\na\nb\n", "b\na\na\n"),
            (.sortLines, "\na\nb\n", "b\na\n\n"),
            (.sortLines, "one\n", "one\n"),
            (.sortLines, "a\r\nb\r\n", "b\na\n"),
            (.sortLines, "b\r\na\r\n", "a\nb\n"),
            (.sortLines, "b\n\na", "\na\nb"),
            (.uniqueLines, "a\nb\na\nb\n", "a\nb\n"),
            (.uniqueLines, "a\n a\nA\na", "a\n a\nA"),
            (.uniqueLines, "a\n\n\nb\n", "a\n\nb\n"),
            (.uniqueLines, "", ""), (.sortLines, "", ""),
            (.joinWestern, "hello\nworld", "hello world"),
            (.joinWestern, "hello  \n  world\n\nnew\nparagraph\n", "hello world\n\nnew paragraph\n"),
            (.joinWestern, "hello\r\nworld", "hello world"),
            (.joinWestern, "\nhello\n \nworld", "\nhello\n \nworld"),
            (.blackCircled, "バナナ\nりんご\nパイン", "❶ バナナ\n❷ りんご\n❸ パイン"),
            (.kanji, "1. バナナ\n2. りんご", "一、バナナ\n二、りんご"),
            (.formalKanji, "一、バナナ\n二、りんご\n三、パイン", "壱 バナナ\n弐 りんご\n参 パイン"),
            (.circledAlphabet, "バナナ\nりんご", "Ⓐ バナナ\nⒷ りんご"),
            (.romanUpper, "a\nb\nc\nd", "I. a\nII. b\nIII. c\nIV. d"),
            (.romanLower, "a\nb\nc", "i. a\nii. b\niii. c"),
            (.checkmark, "□ a", "✓ a"),
            (.emptyBox, "✅ a", "□ a"),
            (.checkedBox, "✓ a", "✅ a"),
            (.taskList, "- [x] a\n- [X] b\n- [ ] c", "- [ ] a\n- [ ] b\n- [ ] c"),
            (.removeList, "一番好き\n壱岐\nIII型\nApple.com", "一番好き\n壱岐\nIII型\nApple.com"),
            (.join, "あ\r\nい\rう\nえ\u{2028}お\u{2029}か", "あいうえおか"),
            (.join, "hello \nworld", "hello world"),
            (.number, "りんご\nみかん\nぶどう", "1. りんご\n2. みかん\n3. ぶどう"),
            (.number, "\nりんご\n  \nみかん\n", "\n1. りんご\n  \n2. みかん\n"),
            (.bullet, "りんご\r\nみかん\n", "・りんご\n・みかん\n"),
            (.bullet, "\n \n", "\n \n"),
            (.number, "👩‍💻 café", "1. 👩‍💻 café"),
            (.number, "9. りんご\n・みかん\n③ぶどう", "1. りんご\n2. みかん\n3. ぶどう"),
            (.bullet, "1. りんご\n2.みかん\n・ぶどう", "・りんご\n・みかん\n・ぶどう"),
            (.number, "１．りんご\n（２）みかん\n(3) ぶどう\n4）なし\n5、もも", "1. りんご\n2. みかん\n3. ぶどう\n4. なし\n5. もも"),
            (.bullet, "●りんご\n• みかん\n- ぶどう\n* なし\n+ もも", "・りんご\n・みかん\n・ぶどう\n・なし\n・もも"),
            (.number, "  7. りんご\n\t・みかん\n　⑳ぶどう", "  1. りんご\n\t2. みかん\n　3. ぶどう"),
            (.bullet, "1. ・2. りんご", "・りんご"),
            (.number, "3.14\n３．１４\n2026年\n-name\n本文・中黒", "1. 3.14\n2. ３．１４\n3. 2026年\n4. -name\n5. 本文・中黒"),
            (.number, "・\n1. \nりんご\n", "\n\n1. りんご\n"),
            (.join, "1. りんご\n・みかん", "1. りんご・みかん"),
            (.join, "", ""), (.number, "", ""), (.bullet, "", ""),
            (.removeList, "1. りんご\n・みかん\n③ぶどう", "りんご\nみかん\nぶどう"),
            (.removeList, "  1. ・りんご\n\t●みかん\n\n　(3)ぶどう\n", "  りんご\n\tみかん\n\n　ぶどう\n"),
            (.removeList, "3.14\n-name\n本文・中黒\n通常の文章", "3.14\n-name\n本文・中黒\n通常の文章"),
            (.removeList, "・\n1. \n \n", "\n\n \n"),
            (.removeList, "１．りんご\r\n- みかん", "りんご\nみかん"),
            (.removeList, "", ""),
            (.markdown, "1. りんご\n・みかん\n- ぶどう", "- りんご\n- みかん\n- ぶどう"),
            (.markdown, "  ①りんご\n\n\t●みかん\n", "  - りんご\n\n\t- みかん\n"),
            (.markdown, "", ""),
            (.markdown, "3.14\n👩‍💻 café", "- 3.14\n- 👩‍💻 café"),
            (.circled, "バナナ\nりんご\nパイナップル", "① バナナ\n② りんご\n③ パイナップル"),
            (.alphabet, "① バナナ\n・りんご\n3. パイナップル", "A. バナナ\nB. りんご\nC. パイナップル"),
            (.circled, "  Z. りんご\n\n\t- みかん\n", "  ① りんご\n\n\t② みかん\n"),
            (.removeList, "A. バナナ\nAA. りんご\nC.\nApple.com", "バナナ\nりんご\n\nApple.com"),
            (.alphabet, "", ""), (.circled, "", ""),
            (.addCommas, "2026年 2026年度 2026-10-06 2026/10/6 西暦：2026 2025〜2026年", "2026年 2026年度 2026-10-06 2026/10/6 西暦：2026 2025〜2026年"),
            (.addCommas, "2026円 2026 1234個\n2026年の売上12345円", "2,026円 2,026 1,234個\n2026年の売上12,345円"),
            (.removeCommas, "2026年 2026-10-06 2,026円 西暦2,026", "2026年 2026-10-06 2026円 西暦2,026"),
            (.addCommas, "1234-56-78 2026/13/06", "1,234-56-78 2,026/13/06"),
            (.addCommas, "1234567.89", "1,234,567.89"),
            (.removeCommas, "1,234,567.89", "1234567.89"),
            (.addCommas, "金額：-1234567円、+98765.4321円\r\n残り 999", "金額：-1,234,567円、+98,765.4321円\r\n残り 999"),
            (.addCommas, "1,234,567.89\n0\n001234\n1234.0000", "1,234,567.89\n0\n001,234\n1,234.0000"),
            (.addCommas, "123456789012345678901234567890", "123,456,789,012,345,678,901,234,567,890"),
            (.removeCommas, "Hello, world! 1,234円 / -2,345.600", "Hello, world! 1234円 / -2345.600"),
            (.addCommas, "1,2,3 1,234,56 1000,2000", "1,2,3 1,234,56 1000,2000"),
            (.removeCommas, "1,2,3 1,234,56 1000,2000", "1,2,3 1,234,56 1000,2000"),
            (.addCommas, "ID12345 12345abc 1e1234 192.168.100.100", "ID12345 12345abc 1e1234 192.168.100.100"),
            (.addCommas, "12345, 67890. １２３４５", "12,345, 67,890. １２３４５"),
            (.addCommas, "", ""), (.removeCommas, "", ""),
            (.removeBlankLines, "\nりんご\n \n\t\n　\n  みかん\n\n", "りんご\n  みかん\n"),
            (.spaceLines, "りんご\nみかん\nぶどう", "りんご\n\nみかん\n\nぶどう"),
            (.spaceLines, "\nりんご\n\n\n  みかん\n", "りんご\n\n  みかん\n"),
            (.spaceLines, "\n \t\n", ""),
            (.removeBlankLines, "a\r\n\r\nb\r\n", "a\nb\n"),
            (.removeBlankLines, "", ""), (.spaceLines, "", ""),
            (.addPeriod, "文章\n既存。\n  本文  \n\t\n", "文章。\n既存。\n  本文。  \n\t\n"),
            (.removePeriod, "文中。文章。\n末尾。。  \n空白なし\n", "文中。文章\n末尾  \n空白なし\n"),
            (.addPeriod, "", ""), (.removePeriod, "", ""),
            (.bracketNumber, "1. バナナ\n・りんご\nC. パイン", "［1］ バナナ\n［2］ りんご\n［3］ パイン"),
            (.bracketAlphabet, "［1］ バナナ\n② りんご", "［A］ バナナ\n［B］ りんご"),
            (.number, "［1］ バナナ\n［B］ りんご", "1. バナナ\n2. りんご"),
            (.removeList, "［1］ バナナ\n［AA］ りんご", "バナナ\nりんご"),
            (.minify, "<div>\r\n\t<p>りんご   みかん</p>\n</div>", "<div><p>りんご みかん</div>"),
            (.minify, "a\u{000B}b\u{000C}c\u{2028}d\u{2029}e\rf", "a\u{000B}b c\u{2028}d\u{2029}e f"),
            (.minify, "<p class=\"item\">A &amp; B</p>", "<p class=item>A &amp; B</p>"),
            (.minify, "   a \t  b   ", " a b "),
            (.minify, "全角　　スペース &nbsp;&nbsp; 👩‍💻", "全角　　スペース &nbsp;&nbsp; 👩‍💻"),
            (.minify, "", ""),
            (.minify, "<p>A<br>\n\tB<br />  C</p>", "<p>A<br> B<br /> C</p>"),
            (.join, "A\nB\n\nC\nD", "AB\n\nCD"),
            (.join, "A\nB\n \nC\nD", "AB\n \nCD"),
            (.join, "\nA\nB\n\nC\n", "\nAB\n\nC\n"),
            (.joinAll, "A\nB\n\nC\nD", "ABCD"),
            (.joinAll, "A\r\n\r\nB\u{2028}C", "ABC"),
            (.joinAll, "", ""),
            (.narrowAlphanumerics, "ＡＢＣｘｙｚ０１２３　！？ ［１］ ｶﾅ", "ABCxyz0123　！？ ［1］ ｶﾅ"),
            (.narrowAlphanumerics, "日本語 Ａ1\r\n👩‍💻", "日本語 A1\r\n👩‍💻"),
            (.widenKana, "ｶﾞｯﾂﾎﾟｰｽﾞ ｳﾞｨｰﾅｽ", "ガッツポーズ ヴィーナス"),
            (.widenKana, "ABC 123 ＡＢＣ １２３ ｢ﾃｽﾄ｣｡､･\r\n", "ABC 123 ＡＢＣ １２３ 「テスト」。、・\r\n"),
            (.removeJapaneseSpaces, "日本語 ABC 123 と Adobe Illustrator を使う", "日本語ABC 123とAdobe Illustratorを使う"),
            (.removeJapaneseSpaces, "日本語　　ABC 日本 語\n日本\tABC", "日本語ABC日本 語\n日本\tABC"),
            (.addJapaneseSpaces, "日本語ABC123とAdobe Illustratorを使う", "日本語 ABC123 と Adobe Illustrator を使う"),
            (.addJapaneseSpaces, "日本語　 ABC  123日本語", "日本語 ABC  123 日本語"),
            (.addJapaneseSpaces, "かなAカナ2漢字々B\r\n", "かな A カナ 2 漢字々 B\r\n"),
            (.addJapaneseSpaces, "日本「ABC」日本\tABC 日本\nABC", "日本「ABC」日本\tABC 日本\nABC"),
            (.narrowAlphanumerics, "", ""), (.widenKana, "", ""),
            (.removeJapaneseSpaces, "", ""), (.addJapaneseSpaces, "", ""),
            (.sum, "バナナ 100円\nりんご 200円", "バナナ 100円\nりんご 200円\n\n合計：300"),
            (.sum, "1,234.50 -34.5 +100", "1,234.50 -34.5 +100\n\n合計：1,300"),
            (.sum, "0.1 0.2", "0.1 0.2\n\n合計：0.3"),
            (.sum, "１２３．５円 −２３．５円", "１２３．５円 −２３．５円\n\n合計：100"),
            (.sum, "100\r\n200\r\n", "100\r\n200\r\n\r\n合計：300"),
            (.sum, "100\n\n", "100\n\n合計：100"),
            (.sum, ".5 -.25", ".5 -.25\n\n合計：0.25"),
            (.sum, "-10 2", "-10 2\n\n合計：-8"),
            (.sum, "0 -0", "0 -0\n\n合計：0"),
            (.sum, "項目番号1と数量3と単価100", "項目番号1と数量3と単価100\n\n合計：104"),
            (.fullwidthWestern, "Abc 123!? ｶﾅ 日本語\r\n\t", "Ａｂｃ　１２３！？ ｶﾅ 日本語\r\n\t".replacingOccurrences(of: " ", with: "　")),
            (.halfwidthWestern, "Ａｂｃ　１２３！？ カナ ｶﾅ\n", "Abc 123!? カナ ｶﾅ\n"),
            (.capitalizeWords, "the art of design", "The Art Of Design"),
            (.titleCase, "the art of design", "The Art of Design"),
            (.capitalizeWords, "DON'T stop: it's a TEST", "Don't Stop: It's A Test"),
            (.titleCase, "war AND peace: the art of living", "War and Peace: The Art of Living"),
            (.titleCase, "a tale of\r\nthe lord of the rings\n", "A Tale Of\r\nThe Lord of the Rings\n"),
            (.titleCase, "state-of-the-art design — a new approach", "State-of-the-Art Design — A New Approach"),
            (.capitalizeWords, "日本語  hello\tWORLD 👩‍💻", "日本語  Hello\tWorld 👩‍💻"),
            (.titleCase, "NASA and HTML", "Nasa and Html"),
            (.fullwidthWestern, "", ""), (.halfwidthWestern, "", ""),
            (.capitalizeWords, "", ""), (.titleCase, "", "")
        ]
        for (operation, input, expected) in cases {
            let actual = operation.apply(input)
            precondition(actual == expected, "\(operation): \(actual.debugDescription) != \(expected.debugDescription)")
        }
        let mixed = "  9. りんご\n\n・みかん\n③ぶどう\n"
        for operation in [TextTransform.number, .bullet, .removeList, .markdown, .circled, .alphabet, .bracketNumber, .bracketAlphabet, .removeBlankLines, .spaceLines, .addPeriod, .removePeriod] {
            let once = operation.apply(mixed)
            precondition(operation.apply(once) == once, "Repeated application must not duplicate prefixes")
        }
        let many = Array(repeating: "項目", count: 52).joined(separator: "\n")
        let alphabet = TextTransform.alphabet.apply(many).components(separatedBy: "\n")
        precondition(alphabet[25] == "Z. 項目" && alphabet[26] == "AA. 項目" && alphabet[51] == "AZ. 項目")
        let circled = TextTransform.circled.apply(many).components(separatedBy: "\n")
        precondition(circled[19] == "⑳ 項目" && circled[20] == "㉑ 項目" && circled[49] == "㊿ 項目" && circled[50] == "(51) 項目")
        precondition(TextTransform.removeList.apply(circled.joined(separator: "\n")) == many)
        let numeric = "-1234567890.12300\n12345円\r\n0.000123\n001234"
        let grouped = TextTransform.addCommas.apply(numeric)
        precondition(TextTransform.addCommas.apply(grouped) == grouped)
        precondition(TextTransform.removeCommas.apply(grouped) == numeric)
        for operation in [TextTransform.narrowAlphanumerics, .widenKana, .removeJapaneseSpaces, .addJapaneseSpaces] {
            let once = operation.apply("ＡＢＣ ｶﾞｯﾂ 日本語ABC 日本語  ABC")
            precondition(operation.apply(once) == once)
        }
        let ascii = String((32...126).map { Character(UnicodeScalar($0)!) })
        precondition(TextTransform.halfwidthWestern.apply(TextTransform.fullwidthWestern.apply(ascii)) == ascii)
        for operation in [TextTransform.fullwidthWestern, .halfwidthWestern, .capitalizeWords, .titleCase] {
            let once = operation.apply("the art of DESIGN Ａｂｃ　１２３")
            precondition(operation.apply(once) == once)
        }
        for invalid in ["数字なし", "", String(repeating: "9", count: 39), "0." + String(repeating: "0", count: 150) + "1", "10000000000000000000000000000000000000 0.001"] {
            do {
                _ = try TextTransform.summedText(invalid)
                preconditionFailure("Expected missing-number/precision error")
            } catch { }
        }
        print("Passed \(cases.count) transformation cases")
    }
}
