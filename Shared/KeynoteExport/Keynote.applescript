-- Shared Keynote automation (PDF2Keynote, PandocDesk). Each build.sh compiles it to Keynote.scpt.
-- create <width> <height>                         -> document id
-- add <doc id> <first slide index> (<pdf> <x> <y> <w> <h>)...
-- save <doc id> <path>
-- close <doc id>  /  discard <doc id>  (both close without saving again)

on run argv
	set command to item 1 of argv
	with timeout of 600 seconds
		if command is "create" then
			return my createDocument((item 2 of argv) as integer, (item 3 of argv) as integer)
		else if command is "add" then
			my addPages(item 2 of argv, (item 3 of argv) as integer, items 4 thru -1 of argv)
		else if command is "save" then
			my saveDocument(item 2 of argv, item 3 of argv)
		else if command is "close" or command is "discard" then
			my closeDocument(item 2 of argv)
		else
			error "Unknown command: " & command
		end if
	end timeout
	return "ok"
end run

on createDocument(slideWidth, slideHeight)
	tell application id "com.apple.Keynote"
		set newDocument to make new document with properties {width:slideWidth, height:slideHeight}
		return id of newDocument
	end tell
end createDocument

on addPages(documentID, slideIndex, values)
	tell application id "com.apple.Keynote"
		set targetDocument to first document whose id is documentID
		tell targetDocument
			repeat with i from 1 to (count of values) by 5
				if slideIndex = 1 then
					set targetSlide to slide 1
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
