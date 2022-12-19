-- convertSV v1.0
-- by kloi34

---------------------------------------------------------------------------------------------------
-- Variable Management ----------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

-- Retrieves variables from the state
-- Parameters
--    listName  : name of the variable list [String]
--    variables : list of variables [Table]
function getVariables(listName, variables) 
    for key, value in pairs(variables) do
        variables[key] = state.GetValue(listName..key) or value
    end
end
-- Saves variables to the state
-- Parameters
--    listName  : name of the variable list [String]
--    variables : list of variables [Table]
function saveVariables(listName, variables)
    for key, value in pairs(variables) do
        state.SetValue(listName..key, value)
    end
end

---------------------------------------------------------------------------------------------------
-- Plugin -----------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

function draw()
    local vars = {
        red = 0,
        green = 1,
        blue = 1
    }
    getVariables("vars", vars)
    setPluginAppearanceColors(vars)
    updateRGBColors(vars)
    imgui.Begin("convertSV", imgui_window_flags.AlwaysAutoResize)
    imgui.BulletText("Removes negative SV")
    imgui.BulletText("Converts SVs > 10.00x to Timing points")
    state.IsWindowHovered = imgui.IsWindowHovered()
    convertButton(vars)
    imgui.End()
    saveVariables("vars", vars)
end


-- Configures the plugin GUI colors
-- Parameters
--    globalVars : list of variables used globally across all menus [Table]
function setPluginAppearanceColors(globalVars)
    local activeColor = {globalVars.red, globalVars.green, globalVars.blue, 0.8}
    local inactiveColor = {globalVars.red, globalVars.green, globalVars.blue, 0.5}
    local white = {1.00, 1.00, 1.00, 1.00}
    local clearWhite = {1.00, 1.00, 1.00, 0.40}
    local black = {0.00, 0.00, 0.00, 1.00}
    
    imgui.PushStyleColor( imgui_col.WindowBg,               black         )
    imgui.PushStyleColor( imgui_col.Border,                 inactiveColor )
    imgui.PushStyleColor( imgui_col.FrameBg,                inactiveColor )
    imgui.PushStyleColor( imgui_col.FrameBgHovered,         activeColor   )
    imgui.PushStyleColor( imgui_col.FrameBgActive,          activeColor   )
    imgui.PushStyleColor( imgui_col.TitleBg,                inactiveColor )
    imgui.PushStyleColor( imgui_col.TitleBgActive,          activeColor   )
    imgui.PushStyleColor( imgui_col.TitleBgCollapsed,       inactiveColor )
    imgui.PushStyleColor( imgui_col.CheckMark,              white         )
    imgui.PushStyleColor( imgui_col.SliderGrab,             white         )
    imgui.PushStyleColor( imgui_col.SliderGrabActive,       white         )
    imgui.PushStyleColor( imgui_col.Button,                 inactiveColor )
    imgui.PushStyleColor( imgui_col.ButtonHovered,          activeColor   )
    imgui.PushStyleColor( imgui_col.ButtonActive,           activeColor   )
    imgui.PushStyleColor( imgui_col.Tab,                    inactiveColor )
    imgui.PushStyleColor( imgui_col.TabHovered,             activeColor   )
    imgui.PushStyleColor( imgui_col.TabActive,              activeColor   )
    imgui.PushStyleColor( imgui_col.Header,                 inactiveColor )
    imgui.PushStyleColor( imgui_col.HeaderHovered,          inactiveColor )
    imgui.PushStyleColor( imgui_col.HeaderActive,           activeColor   )
    imgui.PushStyleColor( imgui_col.Separator,              inactiveColor )
    imgui.PushStyleColor( imgui_col.TextSelectedBg,         clearWhite    )
    imgui.PushStyleColor( imgui_col.ScrollbarGrab,          inactiveColor )
    imgui.PushStyleColor( imgui_col.ScrollbarGrabHovered,   activeColor   )
    imgui.PushStyleColor( imgui_col.ScrollbarGrabActive,    activeColor   )
end
-- Updates global RGB color values, cycling through high-saturation colors
-- Parameters
--    globalVars : list of variables used globally across all menus [Table]
function updateRGBColors(globalVars)
    local fullyRed = globalVars.red == 1
    local noRed = globalVars.red == 0
    local fullyGreen = globalVars.green == 1
    local noGreen = globalVars.green == 0
    local fullyBlue = globalVars.blue == 1
    local noBlue = globalVars.blue == 0
    
    local increaseRed = fullyBlue and noGreen and (not fullyRed)
    local increaseGreen = fullyRed and noBlue and (not fullyGreen)
    local increaseBlue = fullyGreen and noRed and (not fullyBlue)
    local decreaseRed = fullyGreen and noBlue and (not noRed)
    local decreaseGreen = fullyBlue and noRed and (not noGreen)
    local decreaseBlue = fullyRed and noGreen and (not noBlue)
    
    local increment = 0.0005
    if increaseRed then globalVars.red = round(globalVars.red + increment, 4) return end
    if decreaseRed then globalVars.red = round(globalVars.red - increment, 4) return end
    if increaseGreen then globalVars.green = round(globalVars.green + increment, 4) return end
    if decreaseGreen then globalVars.green = round(globalVars.green - increment, 4) return end
    if increaseBlue then globalVars.blue = round(globalVars.blue + increment, 4) return end
    if decreaseBlue then globalVars.blue = round(globalVars.blue - increment, 4) return end
end
-- Rounds a number to a given amount of decimal places
-- Returns the rounded number [Int/Float]
-- Parameters
--    number        : number to round [Int/Float]
--    decimalPlaces : number of decimal places to round the number to [Int]
function round(number, decimalPlaces)
    local multiplier = 10 ^ decimalPlaces
    return math.floor(number * multiplier + 0.5) / multiplier
end
function convertButton(vars)
    local buttonSize = {300, 60}
    if not imgui.Button("Convert SVs to OSU! compatible SVs", buttonSize) then return end
    
    local svsToRemove = {}
    local timingPointsToAdd = {}
    local lastSVAbove10 = false
    for _, sv in pairs(map.ScrollVelocities) do
        lastSVAbove10 = dealWithSVs(svsToRemove, timingPointsToAdd, sv, lastSVAbove10)
    end
    
    local editorActions = {
        utils.CreateEditorAction(action_type.RemoveScrollVelocityBatch, svsToRemove),
        utils.CreateEditorAction(action_type.AddTimingPointBatch, timingPointsToAdd)
    }
    actions.PerformBatch(editorActions)
end

function dealWithSVs(svsToRemove, timingPointsToAdd, sv, lastSVAbove10)
    local svTime = sv.StartTime
    local svMultiplier = sv.Multiplier
    local currentTimingPoint = map.GetTimingPointAt(svTime)
    if not currentTimingPoint then currentTimingPoint = map.TimingPoints[1] end
    local newTimingPointBPM = currentTimingPoint.Bpm * svMultiplier
    
    if lastSVAbove10 and svMultiplier <= 10 then
        table.insert(timingPointsToAdd, utils.CreateTimingPoint(svTime, currentTimingPoint.Bpm, currentTimingPoint.Signature))
    end
    if svMultiplier < 0 then table.insert(svsToRemove, sv) return false end
    if svMultiplier <= 10 then return false end
    table.insert(svsToRemove, sv)
    table.insert(timingPointsToAdd, utils.CreateTimingPoint(svTime, newTimingPointBPM, currentTimingPoint.Signature))
    return true
end