-- Shared Keynote automation (PDF2Keynote, PandocDesk). Each build.sh compiles it to Keynote.scpt.
-- create <width> <height> [<theme name>]           -> document id
-- add <doc id> <first slide index> (<pdf> <x> <y> <w> <h>)...
-- addm <doc id> <first slide index> (<pdf> <x> <y> <w> <h> <master name or "">)...
-- save <doc id> <path>
-- close <doc id>  /  discard <doc id>  (both close without saving again)
-- themes                                           -> theme names, one per line
-- masters <theme name>                             -> master slide names, one per line

on run argv
	set command to item 1 of argv
	with timeout of 600 seconds
		if command is "create" then
			set themeName to ""
			if (count of argv) ≥ 4 then set themeName to item 4 of argv
			return my createDocument((item 2 of argv) as integer, (item 3 of argv) as integer, themeName)
		else if command is "add" then
			my addPages(item 2 of argv, (item 3 of argv) as integer, items 4 thru -1 of argv, 5)
		else if command is "addm" then
			my addPages(item 2 of argv, (item 3 of argv) as integer, items 4 thru -1 of argv, 6)
		else if command is "save" then
			my saveDocument(item 2 of argv, item 3 of argv)
		else if command is "close" or command is "discard" then
			my closeDocument(item 2 of argv)
		else if command is "themes" then
			tell application id "com.apple.Keynote" to set themeNames to name of every theme
			return my joinLines(themeNames)
		else if command is "masters" then
			return my joinLines(my masterNames(item 2 of argv))
		else
			error "Unknown command: " & command
		end if
	end timeout
	return "ok"
end run

on createDocument(slideWidth, slideHeight, themeName)
	tell application id "com.apple.Keynote"
		if themeName is "" then
			set newDocument to make new document with properties {width:slideWidth, height:slideHeight}
		else
			set newDocument to make new document with properties {document theme:(first theme whose name is themeName), width:slideWidth, height:slideHeight}
		end if
		return id of newDocument
	end tell
end createDocument

on addPages(documentID, slideIndex, values, fieldCount)
	tell application id "com.apple.Keynote"
		set targetDocument to first document whose id is documentID
		tell targetDocument
			set knownMasters to name of every master slide
			repeat with i from 1 to (count of values) by fieldCount
				set masterName to ""
				if fieldCount = 6 then set masterName to item (i + 5) of values
				if masterName is not "" and knownMasters does not contain masterName then set masterName to ""
				if slideIndex = 1 then
					set targetSlide to slide 1
					if masterName is not "" then set base slide of targetSlide to master slide masterName
				else if masterName is not "" then
					set targetSlide to make new slide at end of slides with properties {base slide:master slide masterName}
				else
					set targetSlide to make new slide at end of slides
				end if
				set title showing of targetSlide to false
				set body showing of targetSlide to false
				delete every iWork item of targetSlide
				set pageFile to POSIX file (item i of values)
				set pagePosition to {(item (i + 1) of values) as integer, (item (i + 2) of values) as integer}
				tell targetSlide to make new image with properties {file:pageFile, position:pagePosition, width:(item (i + 3) of values) as integer, height:(item (i + 4) of values) as integer}
				set slideIndex to slideIndex + 1
			end repeat
		end tell
	end tell
end addPages

on masterNames(themeName)
	tell application id "com.apple.Keynote"
		set scratch to make new document with properties {document theme:(first theme whose name is themeName)}
		set names to name of every master slide of scratch
		close scratch saving no
	end tell
	return names
end masterNames

on joinLines(names)
	set saved to AppleScript's text item delimiters
	set AppleScript's text item delimiters to linefeed
	set joined to names as text
	set AppleScript's text item delimiters to saved
	return joined
end joinLines

on saveDocument(documentID, outputPath)
	tell application id "com.apple.Keynote"
		save (first document whose id is documentID) in POSIX file outputPath
	end tell
end saveDocument

on closeDocument(documentID)
	tell application id "com.apple.Keynote"
		close (first document whose id is documentID) saving no
	end tell
end closeDocument
