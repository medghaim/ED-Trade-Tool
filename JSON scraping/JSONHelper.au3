#include <Array.au3>
#include "JSON.au3"
#include "JSON_Translate.au3" ; examples of translator functions, includes JSON_pack and JSON_unpack
Func _JSONGet($json, $path, $seperator = ".")
Local $seperatorPos,$current,$next,$l

$seperatorPos = StringInStr($path, $seperator)
If $seperatorPos > 0 Then
$current = StringLeft($path, $seperatorPos - 1)
$next = StringTrimLeft($path, $seperatorPos + StringLen($seperator) - 1)
Else
$current = $path
$next = ""
EndIf

If _JSONIsObject($json) Then
$l = UBound($json, 1)
For $i = 0 To $l - 1
If $json[$i][0] == $current Then
If $next == "" Then
return $json[$i][1]
Else
return _JSONGet($json[$i][1], $next, $seperator)
EndIf
EndIf
Next
ElseIf IsArray($json) And UBound($json, 0) == 1 And UBound($json, 1) > $current Then
If $next == "" Then
return $json[$current]
Else
return _JSONGet($json[$current], $next, $seperator)
EndIf
EndIf

return $_JSONNull
EndFunc

;create an json object to test
;;Local $json = _JSONDecode('{"test":{"x":[11,22,{"y":55}]}}')
;;Local $json = _JSONDecode("{"&'"'&"SearchRange"&'"'&":"&'"'&"60"&'"'&","&'"'&"SystemName"&'"'&":"&'"'&"Gliese 868"&'"'&","&'"'&"PadSize"&'"'&":"&'"'&"Medium"&'"'&","&'"'&"MaxDistanceFromJumpIn"&'"'&":"&'"'&"450"&'"'&","&'"'&"MaxDistanceBetweenSystems"&'"'&":"&'"'&"50"&'"'&"}")
;Local $json = _JSONDecode('{"List": [{"OutgoingCommodityName": "Palladium","ReturningCommodityName": "Progenitor Cells","OutgoingBuy": 12585,"OutgoingSell": 14275,"OutgoingBuyLastUpdate": "1d 3h 33m","OutgoingSellLastUpdate": "4h 5m","ReturningBuy": 6212,"ReturningSell": 7463,"ReturningBuyLastUpdate": "20m","ReturningSellLastUpdate": "1d 3h 33m","OutgoingProfit": 1690,"ReturningProfit": 1251,"TotalProfit": 2941,"Source": "Gliese 868 (Reilly Enterprise)","SourceStationId": 6028,"SourceSystemId": 37738,"SourceStationDistance": 60,"Destination": "Tsim Binba (Kopal Orbital)","DestinationStationId": 3287,"DestinationSystemId": 49913,"DestinationStationDistance": 10,"Distance": 49.14},{"OutgoingCommodityName": "Progenitor Cells","ReturningCommodityName": "Palladium","OutgoingBuy": 6212,"OutgoingSell": 7463,"OutgoingBuyLastUpdate": "20m","OutgoingSellLastUpdate": "1d 3h 33m","ReturningBuy": 12585,"ReturningSell": 14275,"ReturningBuyLastUpdate": "1d 3h 33m","ReturningSellLastUpdate": "4h 5m","OutgoingProfit": 1251,"ReturningProfit": 1690,"TotalProfit": 2941,"Source": "Tsim Binba (Kopal Orbital)","SourceStationId": 3287,"SourceSystemId": 49913,"SourceStationDistance": 10,"Destination": "Gliese 868 (Reilly Enterprise)","DestinationStationId": 6028,"DestinationSystemId": 37738,"DestinationStationDistance": 60,"Distance": 49.14}]}')

;query this object
;Local $result = _JSONGet($json, "List.0.OutgoingCommodityName")
;ConsoleWrite(_JSONIsNull($result) & @CRLF)
;ConsoleWrite($result & @CRLF & @CRLF)
;_ArrayDisplay($result)
