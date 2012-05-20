' JSONDecoder, A Roku JSON parser. Version 1.1, May 20, 2012
'
' Copyright (c) 2012, belltown. All rights reserved.
'
' Redistribution and use in source and binary forms, with or without
' modification, are permitted provided that the following conditions are met:
'	* Redistributions of source code must retain the above copyright
'		notice, this list of conditions and the following disclaimer.
'	* Redistributions in binary form must reproduce the above copyright
'		notice, this list of conditions and the following disclaimer in the
'		documentation and/or other materials provided with the distribution.
'	* Neither the name of the copyright holder nor the names the contributors may be used to endorse or promote products
'		derived from this software without specific prior written permission.
'
' THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
' ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
' WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
' DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY
' DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
' (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
' LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
' ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
' (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
' SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

'*************************************************************************************************************************
' Return a JSONDecoder object that can be used to parse a JSON-formatted string.
'*************************************************************************************************************************
' Usage:
'	decoderObject = JSONDecoder ()
'	json = decoderObject.decodeJSON ("<json formatted string>")
'	if json <> invalid
'		' Handle the json object ...
'	else
'		print decoderObject.errorString ()
'	endif				
'
' A single JSONDecoder object may be used for multiple calls to decodeJSON ()
' Unicode characters less than \u0080 (128) are converted to ASCII
' Unicode characters of \u0080 (128) and higher are converted to "." characters
' Characters with ASCII values of 128 and higher are converted to "." characters
' The JSON 'null' value is converted to 'invalid'
' Numbers are converted to integers unless they are too large or contain a fraction or exponent, otherwise a float is used
' For performance reasons, all valid JSON text should be handled correctly, but not all invalid JSON will be detected
' If the input string is not valid JSON, the code should not crash, although it is not defined what will be returned
' Rudimentary error diagnostics are provided by calling errorString () if parseInput () returns 'invalid'
'*************************************************************************************************************************

function JSONDecoder () as object
	parser = CreateObject ("roAssociativeArray")	' Create parser object
	parser.byt = CreateObject ("roByteArray")	' Store input string as a byte array
	parser.max = 0					' Total number of chars in the input string
	parser.inx = 0					' Index into the input byte array
	parser.err = false				' Set to true if parse error encountered
	parser.errStr = ""				' Error message if parsing failed
	parser.errInx = 0				' Input character position where error occurred

	' Whitespace characters: TAB (9), LF (10), CR (13), Space (32)
	parser.wsp = [	false, false, false, false, false, false, false, false, false, true, true, false, false, true, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false ]

	' Allowable characters in a number: (43) => "+", (45) => "-", (46) => ".", (48-57) => "0" to "9", (69) => "E", (101) => "e"
	parser.num = [	false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, true, false, true, true, false, true, true, true, true,
			true, true, true, true, true, true, false, false, false, false, false, false, false, false, false, false, false, true,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, false, false, false	]

	' Escaped characters: [34=" : 34], [47=/ : 47], [92=\ : 92], [98=b : 8=BS], [f=102 : 12=FF], [110=n : 10=LF], [114=r : 13=CR[, [116=t : 9=TAB]
	parser.esc = [	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 34, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 47, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92,	0, 0, 0, 0, 0, 8, 0, 0, 0, 12, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 13, 0, 9, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	]

	' Main JSON parsing function. Takes a JSON-encoded string as input and returns a BrightScript roAssociativeArray or roArray
	parser.decodeJSON = function (strInput as string) as object
		m.byt.FromAsciiString (strInput + StringI (5, 1))	' Convert input to bytes; pad with invalid chars
		m.max = Len (strInput)			' Total number of valid chars in the input byte array
		m.inx = 0				' Index into input byte array
		m.err = false				' Set if parser encounters an error
		m.errStr = ""				' Set to error reason if an error encountered
		m.errInx = 0				' Input character position where error occurred

		' Skip to first '{' or '[' character. Any extra chars prior to object definition will be ignored
		while m.inx < m.max and m.byt [m.inx] <> 123 and m.byt [m.inx] <> 91
			m.inx = m.inx + 1
		end while

		' A JSON object may be either an object '{...}' or array '[...]'
		if m.inx < m.max
			item = m.processValue ()
		else
			m.handleError ("Failed in decodeJSON. Expecting object or array but none found")
		endif

		' If parsing succeeded, return the JSON object or array
		if m.err
			item = invalid
		endif
		return item
	end function

	' Called by the user to display parsing error information
	parser.errorString = function () as string
		if m.err
			retStr = m.errStr + " at char position: " + m.errInx.ToStr ()
		else
			retStr = ""
		endif
		return retStr
	end function

	' Record the error that just occurred so the user can retrieve it through errorString ()
	parser.handleError = function (errStr as string) as void
		if not m.err				' Only record the first error
			m.err = true
			m.errStr = errStr
			m.errInx = m.inx
			m.inx = m.max
		endif
	end function

	' A value may be an object, array, string, number, true, false or null
	parser.processValue = function () as dynamic
		ch = m.byt [m.inx]
		if ch = 34					' "
			value = m.processString ()
		else if ch = 123				' {
			value = m.processObject ()
		else if m.num [ch]				' number char
			value = m.processNumber ()
		else if ch = 91					' [
			value = m.processArray ()
		else if ch = 116				' t
			value = m.processTrue ()
		else if ch = 102				' f
			value = m.processFalse ()
		else if ch = 110				' n
			value = m.processNull ()
		else
			value = invalid
			m.handleError ("Failed in processValue. Value expected but none found")
		endif
		return value
	end function

	' An object consists of a comma-separated list of name-value pairs enclosed in braces: {}
	parser.processObject = function () as object
		obj = {}
		m.inx = m.inx + 1			' Skip past the { character
		m.processWhitespace ()
		if m.byt [m.inx] <> 125			' }
			m.processNameValuePair (obj)
			m.processWhitespace ()
			while m.inx < m.max and m.byt [m.inx] <> 125	' }
				if m.byt [m.inx] = 44	' comma
					m.inx = m.inx + 1
					m.processWhitespace ()
					m.processNameValuePair (obj)
					m.processWhitespace ()
				else
					m.handleError ("Failed in processObject. Expecting comma but none found")
				endif
			end while
		endif
		if m.byt [m.inx] = 125		' }
			m.inx = m.inx + 1
		else
			m.handleError ("Failed in processObject. Expecting } but none found")
		endif
		return obj
	end function

	' An array consists of a comma-separated list of values enclosed in brackets: []
	parser.processArray = function () as object
		arr = []
		m.inx = m.inx + 1		' Skip past the [ character
		m.processWhitespace ()
		if m.byt [m.inx] <> 93	' ]
			arr.Push (m.processValue ())
			m.processWhitespace ()
			while m.inx < m.max and m.byt [m.inx] <> 93		' ]
				if m.byt [m.inx] = 44		' comma
					m.inx = m.inx + 1
					m.processWhitespace ()
					arr.Push (m.processValue ())
					m.processWhitespace ()
				else
					m.handleError ("Failed in processArray. Expecting comma but none found")
				endif
			end while
		endif
		if m.byt [m.inx] = 93								' ]
			m.inx = m.inx + 1
		else
			m.handleError ("Failed in processArray. Expecting ] but none found")
		endif
		return arr
	end function

	' A name-value pair consists of a name (quoted-string) and a value, separated by a colon
	parser.processNameValuePair = function (obj as object) as void
		if m.byt [m.inx] = 34		' Quote char
			key = m.processString ()
			m.processWhitespace ()
			if m.byt [m.inx] = 58	' Colon char
				m.inx = m.inx + 1
				m.processWhitespace ()
				value = m.processValue ()
				obj [key] = value
			else
				m.handleError ("Failed in processNameValuePair. Expecting colon but none found")
			endif
		else
			m.handleError ("Failed in processNameValuePair. Expecting opening quote but none found")
		endif
	end function

	' True is simply the JSON value: true
	parser.processTrue = function () as boolean
		if m.byt [m.inx + 1] <> 114 or m.byt [m.inx + 2] <> 117 or m.byt [m.inx + 3] <> 101
			m.handleError ("Failed in processTrue. Expecting true keyword but none found")
		endif
		m.inx = m.inx + 4
		return true
	end function

	' False is simply the JSON value: false
	parser.processFalse = function () as boolean
		if m.byt [m.inx + 1] <> 97 or m.byt [m.inx + 2] <> 108 or m.byt [m.inx + 3] <> 115 or m.byt [m.inx + 4] <> 101
			m.handleError ("Failed in processFalse. Expecting false keyword but none found")
		endif
		m.inx = m.inx + 5
		return false
	end function

	' The JSON 'null' value is converted to the BrightScript 'invalid' value
	parser.processNull = function () as dynamic
		if m.byt [m.inx + 1] <> 117 or m.byt [m.inx + 2] <> 108 or m.byt [m.inx + 3] <> 108
			m.handleError ("Failed in processNull. Expecting null keyword but none found")
		endif
		m.inx = m.inx + 4
		return invalid		' No null-equivalent
	end function

	' A number (integer or floating-point) may contain digits as well as the characters: "+", "-",  "E", "e", "."
	parser.processNumber = function () as dynamic
		isFlt = false		' Set to true if the number is a float (contains ".", "E", or "e")
		num = Chr (m.byt [m.inx])
		m.inx = m.inx + 1
		ch = m.byt [m.inx]
		while m.inx < m.max and m.num [ch]
			if ch = 46 or ch = 69 or ch = 101 then isFlt = true
			num = num + Chr (ch)
			m.inx = m.inx + 1
			ch = m.byt [m.inx]
		end while
		if isFlt
			retVal = Val (num)
		else 
			numInt = num.ToInt ()
			' If a string converted to an integer exceeds the max allowable value, then BrightScript converts to max value
			if numInt >= 2147483646 or numInt <= -2147483647
				retVal = Val (num)
			else
				retVal = numInt
			endif
		endif
		return retVal
	end function

	' A string is a sequence of ASCII characters. Escaped characters are preceded by a backslash
	parser.processString = function () as string
		ba = CreateObject ("roByteArray")	' For now, store the return string as a byte array; convert to ASCII when returned
		m.inx = m.inx + 1			' Skip past the " character
		ch = m.byt [m.inx]			' Should already be pointing to first character after the opening quote
		while m.inx < m.max and ch <> 34	' Stop when we reach an unescaped quote character
			if ch = 92			' \ (Escaped character)
				m.inx = m.inx + 1	' Skip to the escape character
				ch = m.byt [m.inx]	' Extract the escape character
				m.inx = m.inx + 1	' Point to character after the escape character
				if ch = 117		' u - UNICODE - convert UNICODE values < 128 into ASCII ...
					hex = 0
					for i = 0 to 3
						c = m.byt [m.inx + i]
						if c >= 48 and c <= 57		' 0-9
							h = c - 48
						else if c >= 65 and c <= 70	' A-F
							h = c - 55
						else if c >= 97 and c <= 102	' a-f
							h = c - 87
						else
							h = 128
						endif
						hex = hex * 16 + h
					end for
					' 0-127 => VALID ascii
					if hex < 128
						ba.Push (hex)	' Valid ASCII unicode character
					else
						ba.Push (46)	' Non-ASCII unicode character; replace with "."
					endif
					m.inx = m.inx + 4	' Skip the hex character sequence
				else				' Escaped (non-UNICODE) character
					esc = m.esc [ch]
					if esc <> 0
						ba.Push (esc)	' Escape character found in lookup table
					else
						ba.Push (ch)	' No escape character found; use actual character
					endif
				endif
			else if ch < 128			' Only return valid ASCII characters
				ba.Push (ch)
				m.inx = m.inx + 1
			else
				ba.Push (46)			' Replace invalid ASCII characters with "." characters
				m.inx = m.inx + 1
			endif
			ch = m.byt [m.inx]
		end while
		if m.inx = m.max
			m.handleError ("Failed in processString. Expecting ending quote but none found")
		else
			m.inx = m.inx + 1			' Skip past the ending quote
		endif
		return ba.ToAsciiString ()
	end function

	' Ignore any whitespace characters
	parser.processWhitespace = function () as void
		while m.inx < m.max and m.wsp [m.byt [m.inx]]	' Whitespace char
			m.inx = m.inx + 1
		end while
	end function

	return parser

end function