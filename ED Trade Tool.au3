#include <GUIConstants.au3>
#include <Array.au3>
#include <File.au3>
#include <GuiEdit.au3>
#include "JSONHelper.au3"

;;GUI STUFF
$hGUI = guicreate("ED Trade Route Scraper", 600, 400)

GUICtrlCreateLabel("Max Distance To Station (ls):", 5, 5, 110, 35)
$hMaxStationInput = GUICtrlCreateInput("500", 120, 8, 75, 20)
GUICtrlCreateLabel("Max Distance Between Systems (ly):", 5, 45, 110, 35)
$hMaxSystemInput = GUICtrlCreateInput("50", 120, 48, 75, 20)

GUICtrlCreateLabel("Min. Profit:", 287, 75)
$hMinProfit = GUICtrlCreateInput("2500", 350, 75)

$hOutputEdit = GUICtrlCreateEdit("", 5, 100, 580, 240)
$hStartButton = GUICtrlCreateButton("START", 225, 375)
$hPauseButton = GUICtrlCreateButton("PAUSE", 300, 375)

GUICtrlCreateLabel("Current Best Route:", 175, 350)
$hCurrentBestLabel = GUICtrlCreateLabel("N/A", 300, 350, 280)

GUICtrlCreateLabel("Search Range (ly):", 250, 5)
GUIStartGroup()
$hSearchRadio1 = GUICtrlCreateRadio("0", 350, 5)
$hSearchRadio2 = GUICtrlCreateRadio("20", 390, 5)
$hSearchRadio3 = GUICtrlCreateRadio("30", 430, 5)
$hSearchRadio4 = GUICtrlCreateRadio("40", 470, 5)
$hSearchRadio5 = GUICtrlCreateRadio("60", 510, 5)

GUICtrlCreateLabel("Ship Size:", 290, 40)
GUIStartGroup()
$hSizeRadio1 = GUICtrlCreateRadio("S", 350, 40)
$hSizeRadio2 = GUICtrlCreateRadio("M", 390, 40)
$hSizeRadio3 = GUICtrlCreateRadio("L", 430, 40)

guisetstate(@SW_SHOW)

;;Reading all the System names from the file, and setting the size, and throwing them all into an array
$sysListSize = _FileCountLines("SystemNames.txt")
Global $sysNames[$sysListSize]
_FileReadToArray("SystemNames.txt", $sysNames, 0) ;;reads it into a 0-based array - this is optional, we can remove the '0' param entirely, and have the 0th element be the array count
													  ;;NOTE: structure of SystemNames.txt is important! -> first line is the array index of the current system we're searching (ie, so if we stop program at 10,000th system
Global $currSearchIndex = $sysNames[0]
If $sysNames[0] <> 1 Then
	gOut("Starting from where we left off last time! (System index "&$sysNames[0]&")")
EndIf

;;our request will be a global variable so i can fuck with it in other functions because bad programming is bad
Global $REQUEST = ObjCreate ("WinHttp.WinHttpRequest.5.1");;TO-DO: Surround in a try-catch

Global $continueSearch = False

Global $bestTradeProfit = 0
Global $bestSystemName = ""

while True
	$msg = guigetmsg()
	if $msg = $GUI_EVENT_CLOSE Then
		_FileWriteToLine("SystemNames.txt", 1, $currSearchIndex, 1)
		Exit
	ElseIf $msg = $hStartButton Then
		Global $searchRange = GetSearchRange();
		Global $padSize = GetShipSize();
		Global $maxStationDistance = GUICtrlRead($hMaxStationInput)
		Global $maxSystemDistance = GUICtrlRead($hMaxSystemInput)
		Global $minProfit = GUICtrlRead($hMinProfit)
		$continueSearch = True
	ElseIf $msg = $hPauseButton Then
		$continueSearch = False
		_FileWriteToLine("SystemNames.txt", 1, $currSearchIndex, 1)
	EndIf

	If $continueSearch == True Then
		If $currSearchIndex < $sysListSize Then
			SearchTradeRoutes($sysNames[$currSearchIndex])
			$currSearchIndex += 1
		ElseIf $currSearchIndex == $sysListSize Then
			gOut("SEARCH COMPLETE, CMDR")
			gOut("Best Trade Route: "&$bestSystemName&"("&$bestTradeProfit&"cr/hr)")
			_FileWriteToLine("SystemNames.txt", 1, "1", 1)
			FileWriteLine("SearchResults.txt", "Best Trade Route: "&$bestSystemName&"("&$bestTradeProfit&"cr/hr)")
			;;reset the variables!
			$continueSearch = False
			$currSearchIndex = 1
			_GUICtrlEdit_LineScroll($hOutputEdit, 0, _GuiCtrlEdit_GetLineCount($hOutputEdit)) ;scroll to bottom after finishing and analyzing a request
		EndIf
	EndIf
WEnd

Func gOut($tMsg)
	if StringLen(GUICtrlRead($hOutputEdit)) > 250000 Then
		GUICtrlSetData($hOutputEdit, "reset output window")
	EndIf
	GUICtrlSetData($hOutputEdit, GUICtrlRead($hOutputEdit) & @CRLF & $tMsg)
EndFunc


;;Searches the trade routes of the specified system.
;; Creates a POST Request (via PostRequest(..) function) to query the server.
;; The server recieves the request, queries its database internally, returns a JSON string consisting of a List of the different trade routes found by the search parameters.
;;We must parse this JSON string (using a wonderful JSON parser I found on the autoit forums),
;;and then we can simply use $json = _JSONDecode(..) and _JSONGet($json, "List.4.TotalProfit") (to recieve the 5th return trade route's total profit, for example).
;;After parsing the JSON string, we can now analyze the data, and see if any of the returned trade route's TotalProfit attributes exceed our profit threshold.
;;Furthermore, we are able to (easily) interact with any of the data returned by the server (ie, "List.3.OutgoingCommodityName")
;;    params - $systemName: name of the system to query in our Post request.
Func SearchTradeRoutes($systemName)
	If $searchRange == -1 Then
		MsgBox(0, "Error", "Please fill everything out before starting")
		Exit
	EndIf
	If $padSize == "" Then
		MsgBox(0, "Error", "Please fill everything out before starting")
		Exit
	EndIf

	;;the request we are going to send
	$postData = '{"SearchRange":"'&$searchRange&'", "SystemName":"'&$systemName&'", "PadSize":"'&$padSize&'", "MaxDistanceFromJumpIn":"'&$maxStationDistance&'", "MaxDistanceBetweenSystems":"'&$maxSystemDistance&'"}'
	;;TO-DO: GO TO THE POST REQUEST FUNCTION AND SURROUND ITS MEATY INSIDES WITH A TRY CATCH
	PostRequest($REQUEST, $postData) ;;Sends POST Request, and allows us to retrieve POST response via $REQUEST.ResponseText
	Local $json = _JSONDecode($REQUEST.ResponseText) ;; the JSON parse

	;;Analyzing the json results to see if there's any routes that meet our min profit demand
	Local $result = "" ;;the results of searching for specific keys will be stored into this
	Local $x=0
	$profitableCount = 0
	$unprofitableCount = 0
	While _JSONIsNull($result) <> True ;;cycles 1 past limit, and retrieves the value "DEFAULT" which appears to be from the JSON parser; TO-DO: fix loop that adds the "Default" return value
		$result = _JSONGet($json, "List."&$x&".TotalProfit")
		If StringCompare($result, "Default") == 0 Then ;;cause there's always one DEFAULT for somereason, probably the array null terminator (since autoit doesnt have null)
			;;do nada
		ElseIf Int($result) >= Int($minProfit) Then
			$profitableCount += 1
		ElseIf Int($result) < Int($minProfit) Then
			$unprofitableCount += 1
		EndIf

		$x += 1
	WEnd

	;;Retrieving information for display purposes (and ultimately, the $displayStr we will write to file if this system contained profitable trade routes.
	Local $jsonRequest = _JSONDecode($postData)
	$highestRoute = _JSONGet($json, "List.0.TotalProfit") ;;total profit sorted, so 0th Total Profit will be highest
	$displayStr = $systemName&": "&$profitableCount&" profitable route(s). "&$unprofitableCount&" unprofitable route(s) within "&$searchRange&"ly."

	;;At the end of every star system search, check its highest trade route, and compare that against our global best. this way we can give updates on pause, or show the highest trade routes even if none passed the user specified min threshold
	If StringCompare($highestRoute, "Default") <> 0 Then
		If Int($highestRoute) > $bestTradeProfit Then
			$bestTradeProfit = Int($highestRoute)
			$bestSystemName = $systemName
			GUICtrlSetData($hCurrentBestLabel, $bestSystemName&"("&$bestTradeProfit&"cr/hr)")
		EndIf
	EndIf

	;;Logging system name in results.txt so the user can explore these later on the website (because it's infinitely prettier)
	If $profitableCount > 0 Then
		$displayStr &= " MOST PROFITABLE ROUTE: "&$highestRoute&"cr/t"
		FileWriteLine("SearchResults.txt", $displayStr)
	EndIf

	gOut($displayStr)
	_GUICtrlEdit_LineScroll($hOutputEdit, 0, _GuiCtrlEdit_GetLineCount($hOutputEdit)) ;scroll to bottom after finishing and analyzing a request
EndFunc

;;The meat of the interwebs stuff. Sends a POST request to the site containing the JSON string that represents the search we wish to carry out.
;;NOTE: We are passing our REQUEST ByRef, meaning we can and do affect the global $REQUEST in this function.
;; After this function completes, we are free to use $REQUEST.ResponseText to retrieve the JSON response from the server containing the search results
;;	params - ByRef $Obj - (something to this effect $obj = ObjCreate ("WinHttp.WinHttpRequest.5.1"), because we are creating our request. NOTE: ByRef!
;;		   - $jsonToPOST - The JSON representation of the search we wish to send in our POST Request
Func PostRequest(ByRef $obj, $jsonToPOST)
	$reqURL = "http://elitetradingtool.co.uk/api/EliteTradingTool/FindTrades"

	$obj.Open("POST", $reqURL, false)
	$obj.SetRequestHeader("Content-Type", "application/json")
	$obj.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.152 Safari/537.36")
	$obj.Send($jsonToPOST)

	$oStatusCode = $obj.Status
	If $oStatusCode <> 200 then
	 gOut("Response code not 200! It's: " & $oStatusCode)
	EndIf
EndFunc

Func GetSearchRange()
	$val = -1
	Select
		Case GUICtrlRead($hSearchRadio1) = $GUI_CHECKED
			$val = 0
		Case GUICtrlRead($hSearchRadio2) = $GUI_CHECKED
			$val = 20
		Case GUICtrlRead($hSearchRadio3) = $GUI_CHECKED
			$val = 30
		Case GUICtrlRead($hSearchRadio4) = $GUI_CHECKED
			$val = 40
		Case GUICtrlRead($hSearchRadio5) = $GUI_CHECKED
			$val = 60
	EndSelect
	Return $val
EndFunc

Func GetShipSize()
	$val = ""
	Select
		Case GUICtrlRead($hSizeRadio1) = $GUI_CHECKED
			$val = "Small"
		Case GUICtrlRead($hSizeRadio2) = $GUI_CHECKED
			$val = "Medium"
		Case GUICtrlRead($hSizeRadio3) = $GUI_CHECKED
			$val = "Large"
	EndSelect
	Return $val
EndFunc


