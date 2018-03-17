--[[
               OpenTX Telemetry Script for Taranis X9D Plus / X8R
               --------------------------------------------------

                       Alexander Koch <lynix47@gmail.com>

             Based on 'olimetry.lua' by Ollicious <bowdown@gmx.net>

                    Adapted for dRonin by <yds@Necessitu.de>
--]]


-- settings  -------------------------------------------------------------------

local Altd = "GAlt"	-- "Alt" for barometric or "GAlt" GPS altitude
local battCells = 0	-- 5=5S, 7=7S or 0=Autodetect 1S, 2S, 3S, 4S, 6S or 8S
local cellMinV = 3.30	-- minimum voltage alert threshold
local widgets = {
                  {"battery"},
                  {"gps", "dist", "alt"},
                  {"mode", "speed", "timer"},
                  {"rssi"}
                }


-- globals  --------------------------------------------------------------------

local fuel		= 0
local linq		= 0
local prevMode		= 0
local dispTime		= 0
local prevTime		= 0
local displayTimer	= 0
local displayWidth	= 212
local displayHeight	= 64
local widgetWidthSingle	= 35
local widgetWidthMulti	= 0
local widget		= {}


-- widget functions  -----------------------------------------------------------

local function round(n, p)
    p = 10^(p or 0)
    if n >= 0 then
	return math.floor(n * p + 0.5) / p
    else
	return math.ceil(n * p - 0.5) / p
    end
end


local function batteryWidget(x, y)

    lcd.drawFilledRectangle(x+13, y+7, 5, 2, 0)
    lcd.drawRectangle(x+10, y+9, 11, 40)

    local battVolt = 0
    local cellVolt = getValue("Cels")
    if type(cellVolt) == "table" then -- FrSky FLVSS
	battCells = 0
	for i, v in ipairs(cellVolt) do
	    battVolt = battVolt + v
	    battCells = battCells + 1
	end
    elseif type(cellVolt) == "number" then -- dRonin et al
	battVolt = cellVolt
    else
	battVolt = getValue("VFAS")
    end

    if battCells == 0 then
        if math.ceil(battVolt / 4.37 ) > battCells and battVolt < 4.37 * 8 then 
            battCells = math.ceil(battVolt / 4.37) -- no autodetect for 5S & 7S
            if battCells == 7 then battCells = 8 end -- empty 8S looks like 7S
            if battCells == 5 then battCells = 6 end -- empty 6S looks like 5S
        end
    end

    if battCells > 0 then 
        cellVolt = battVolt / battCells 
    end

    local v = 0
    local highVolt = battVolt > 4.22 * battCells
    if highVolt then
	v = cellVolt - 0.15
    else
	v = cellVolt
    end

    if     v > 4.2		then v = 100
    elseif v < 3.2		then v = 0
    elseif v >= 4		then v = 80 * v - 236
    elseif v <= 3.67		then v = 29.787234 * v - 95.319149 
    elseif v > 3.67 and v < 4	then v = 212.53 * v - 765.29
    end

    if fuel == 0 then 
	fuel = round(v) --init percent
    else 
	fuel = round(fuel * 0.98 + 0.02 * v)
    end

    local myPxHeight = math.floor(fuel * 0.37)
    local myPxY = 11 + 37 - myPxHeight
    if fuel > 0 then
        lcd.drawFilledRectangle(x+11, myPxY, 9, myPxHeight, 0)
    end

    for i=36, 1, -2 do
        lcd.drawLine(x+12, y+10+i, x+18, y+10+i, SOLID, GREY_DEFAULT)
    end

    local style = LEFT
    if cellVolt < cellMinV then
        style = style + BLINK
    end

    if displayTimer == 0 then
	lcd.drawText(x, y+54, battCells.."S ", style)
	style = style + PREC2
	lcd.drawNumber(lcd.getLastPos(), y+54, cellVolt*100, style)
    elseif displayTimer == 1 then
	style = style + PREC2
	lcd.drawNumber(x+5, y+54, battVolt*100, style)
    end
    if highVolt then style = BLINK else style = 0 end
    lcd.drawText(lcd.getLastPos(), y+54, "V", style)

end


local function rssiWidget(x, y)

    linq = getValue("RQly")	-- Crossfire Rx Link Quality
    if linq == 0 then
	linq = getValue("RSSI")	-- FrSky et al
    end
        
    local percent = 0
    if linq > 38 then
        percent = (math.log(linq-28, 10) - 1) / (math.log(72, 10) - 1) * 100
    end

    local pixmap = "/IMAGES/TELEM/RSSIh00.bmp"
    if     percent > 90 then pixmap = "/IMAGES/TELEM/RSSIh10.bmp"
    elseif percent > 80 then pixmap = "/IMAGES/TELEM/RSSIh09.bmp"
    elseif percent > 70 then pixmap = "/IMAGES/TELEM/RSSIh08.bmp"
    elseif percent > 60 then pixmap = "/IMAGES/TELEM/RSSIh07.bmp"
    elseif percent > 50 then pixmap = "/IMAGES/TELEM/RSSIh06.bmp"
    elseif percent > 40 then pixmap = "/IMAGES/TELEM/RSSIh05.bmp"
    elseif percent > 30 then pixmap = "/IMAGES/TELEM/RSSIh04.bmp"
    elseif percent > 20 then pixmap = "/IMAGES/TELEM/RSSIh03.bmp"
    elseif percent > 10 then pixmap = "/IMAGES/TELEM/RSSIh02.bmp"
    elseif percent > 0  then pixmap = "/IMAGES/TELEM/RSSIh01.bmp"
    end

    lcd.drawPixmap(x+4, y+1, pixmap)
    lcd.drawText(x+6, y+54, linq .. "dB", 0)

end


local function distWidget(x, y)

    local dist = getValue("Dist")

    lcd.drawPixmap(x+1, y+2, "/IMAGES/TELEM/dist.bmp")
    lcd.drawNumber(x+18, y+7, dist, LEFT)
    lcd.drawText(lcd.getLastPos(), y+7, "m", 0)

end


local function altitudeWidget(x, y)

    local altitude = getValue(Altd)

    lcd.drawPixmap(x+1, y+2, "/IMAGES/TELEM/hgt.bmp")
    lcd.drawNumber(x+18, y+7, altitude, LEFT)
    lcd.drawText(lcd.getLastPos(), y+7, "m", 0)

end


local function speedWidget(x, y)

    local speed = getValue("GSpd") * 3.6

    lcd.drawPixmap(x+1, y+2, "/IMAGES/TELEM/speed.bmp")
    lcd.drawNumber(x+18, y+7, speed, LEFT)
    lcd.drawText(lcd.getLastPos(), y+7, "kmh", 0)

end


local function headingWidget(x, y)

    local heading = getValue("Hdg")

    lcd.drawPixmap(x+1, y+2, "/IMAGES/TELEM/compass.bmp")
    lcd.drawNumber(x+18, y+7, heading, LEFT)
    lcd.drawText(lcd.getLastPos(), y+7, "dg", 0)

end


local function modeWidget(x, y)

    local style = MIDSIZE
    local sound
    local mode
    local m = getValue("RPM")
    local armed = math.floor(m * 0.01) == 1

    m = math.floor(m % 100)
  
    if linq <= 20 and m == 0 then
	mode = "No RX"
	style = style + BLINK
    elseif m ==  0 then mode = "Manual";	sound = "fm-mnl"
    elseif m ==  1 then mode = "Acro";		sound = "fm-acr"
    elseif m ==  2 then mode = "Level";		sound = "fm-lvl"
    elseif m ==  3 then mode = "Horizon";	sound = "fm-hrzn"
    elseif m ==  4 then mode = "AxisLck";	sound = "fm-axlk"
    elseif m ==  5 then mode = "VirtBar";	sound = "fm-vbar"
    elseif m ==  6 then mode = "Stabil1";	sound = "fm-stb1"
    elseif m ==  7 then mode = "Stabil2";	sound = "fm-stb2"
    elseif m ==  8 then mode = "Stabil3";	sound = "fm-stb3"
    elseif m ==  9 then mode = "Tune";		sound = "fm-tune";	style = style + BLINK
    elseif m == 10 then mode = "AltHold";	sound = "fm-ahld"
    elseif m == 11 then mode = "PosHold";	sound = "fm-phld"
    elseif m == 12 then mode = "RToHome";	sound = "fm-rth"
    elseif m == 13 then mode = "PathPln";	sound = "fm-plan"
    elseif m == 15 then mode = "Acro+";		sound = "fm-acrp"
    elseif m == 16 then mode = "AcrDyn";	sound = "fm-acrd"
    elseif m == 17 then mode = "Fail";		sound = "fm-fail";	style = style + BLINK
    end

    lcd.drawPixmap(x+1, y+2, "/IMAGES/TELEM/fm.bmp")
    lcd.drawText(x+20, y+4, mode, style)

    if prevMode ~= m then
        prevMode = m
        playFile(sound .. ".wav")
    end

end


local function timerWidget(x, y)

    lcd.drawPixmap(x+1, y+3, "/IMAGES/TELEM/timer_1.bmp")
    lcd.drawTimer(x+18, y+8, getValue(196), 0)

end


local function gpsWidget(x,y)

    local sats = getValue("Sats")
    local fix  = getValue("Fix")

    local fixImg = "/IMAGES/TELEM/sat0.bmp"
    if     fix == 2 then fixImg = "/IMAGES/TELEM/sat1.bmp"
    elseif fix == 3 then fixImg = "/IMAGES/TELEM/sat2.bmp"
    elseif fix == 4 then fixImg = "/IMAGES/TELEM/sat3.bmp"
    end

    local satImg = "/IMAGES/TELEM/gps_0.bmp"
    if     sats > 5 then satImg = "/IMAGES/TELEM/gps_6.bmp"
    elseif sats > 4 then satImg = "/IMAGES/TELEM/gps_5.bmp"
    elseif sats > 3 then satImg = "/IMAGES/TELEM/gps_4.bmp"
    elseif sats > 2 then satImg = "/IMAGES/TELEM/gps_3.bmp"
    elseif sats > 1 then satImg = "/IMAGES/TELEM/gps_2.bmp"
    elseif sats > 0 then satImg = "/IMAGES/TELEM/gps_1.bmp"
    end

    lcd.drawPixmap(x+1, y+1, fixImg)
    lcd.drawPixmap(x+13, y+3, satImg)
    lcd.drawNumber(x+19, y+1, sats, SMLSIZE)

end


-- main logic  -----------------------------------------------------------------

local function run(event)

    lcd.clear()

    local x = -1
    local y = -1
    local w

    for col=1, #widgets do
        if #widgets[col] == 1 then
            w = widgetWidthSingle
        else
            w = widgetWidthMulti
        end

        for row=1, #widgets[col] do
            lcd.drawLine(x, y, x+w, y, SOLID, GREY_DEFAULT)
            widget[widgets[col][row]](x+1, y+1) --call widget
            y = y + math.floor(displayHeight / #widgets[col])
        end

        y = -1
        x = x + w
    end

    dispTime = dispTime + (getTime() - prevTime)
    if dispTime >= 200 then -- 2s
	if displayTimer == 1 then 
	    displayTimer = 0 
	else 
	    displayTimer = 1
	end
	dispTime = 0
    end
    prevTime = getTime()

end


local function init()

    widget["alt"] = altitudeWidget
    widget["battery"] = batteryWidget
    widget["dist"] = distWidget
    widget["mode"] = modeWidget
    widget["gps"] = gpsWidget
    widget["heading"] = headingWidget
    widget["rssi"] = rssiWidget
    widget["speed"] = speedWidget
    widget["timer"] = timerWidget

    local colsSingle = 0
    local colsMulti  = 0
    for i=1, #widgets do
        if #widgets[i] == 1 then
            colsSingle = colsSingle + 1
        else
            colsMulti = colsMulti + 1
        end
    end

    widgetWidthMulti = (displayWidth - (colsSingle * widgetWidthSingle))
    widgetWidthMulti = widgetWidthMulti / colsMulti

end


-- module definition  ----------------------------------------------------------

return {init=init, run=run}