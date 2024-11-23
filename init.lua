local PMPR = {
    version = '0.1.0',
    initialized = false,
    modules = {
        data = require('modules/data.lua'),
        debug = require('modules/debug.lua'),
        gameSession = require('external/GameSession.lua'),
        interface = require('modules/interface.lua'),
        properties = require('properties.lua'),
    },
}

-- External Dependencies --

local AMM = nil
local NibblesToNPCs = nil

-- Game State --
local playerGender = nil
local isPhotoModeActive = false
local isOverlayOpen = false

-- Local Settings --
local vDefaultAppearances = {}
local jDefaultAppearances = {}

-- Accessors --

function PMPR.GetVEntity()
    return PMPR.modules.interface.vEntity
end

function PMPR.GetJEntity()
    return PMPR.modules.interface.jEntity
end

function PMPR.IsDefaultAppearance()
    return PMPR.modules.interface.isDefaultAppearance
end

function PMPR.ToggleDefaultAppearance(bool)
    PMPR.modules.interface.isDefaultAppearance = bool
end

-- @param index: integer (1-11)
function PMPR.GetEntityID(index)
    return PMPR.modules.data.GetEntityID(index)
end

-- Error Handling --

local function HandleError(message)
    PMPR.modules.interface.NotifyError(message)
    spdlog.info('[Photo Mode Player Replacer] Error: ' .. message)
end

-- Core Logic --

local function UpdatePlayerGender()
    playerGender = string.gmatch(tostring(Game.GetPlayer():GetResolvedGenderName()), '%-%-%[%[%s*(%a+)%s*%-%-%]%]')()
    PMPR.modules.interface.SetupDefaultV(playerGender)
end

local function SetDefaultAppearance()
    local player = Game.GetPlayer()
    local tsq = TSQ_ALL()
    local success, parts = Game.GetTargetingSystem():GetTargetParts(player, tsq)
    if success then
        for _, part in ipairs(parts) do
            local entity = part:GetComponent(part):GetEntity()
            if entity then
                local ID = AMM:GetScanID(entity)
                if ID == PMPR.modules.data.GetEntityID(11) then
                    AMM.API.ChangeAppearance(entity, jDefaultAppearances[PMPR.GetJEntity()])
                    PMPR.ToggleDefaultAppearance(false)
                end
            end
        end
    end
end

-- Initialization --

local function CheckDependencies()
    AMM = GetMod('AppearanceMenuMod')

    if not AMM then
        HandleError('Missing Requirement - Appearance Menu Mod')
    end

    if ModArchiveExists('Photomode_NPCs_AMM.archive') then
        NibblesToNPCs = true
    else
        HandleError('Missing Requirement - Nibbles To NPCs')
    end
end

local function Initialize()
    -- Setup default appearance preferences
    for i, entry in ipairs(PMPR.modules.properties.defAppsV) do
        vDefaultAppearances[i] = entry.appearanceName
    end

    for i, entry in ipairs(PMPR.modules.properties.defAppsJ) do
        jDefaultAppearances[i] = entry.appearanceName
    end
end

local function SetupObservers()
    Override("PhotoModeSystem", "IsPhotoModeActive", function(this, wrappedMethod)
        isPhotoModeActive = wrappedMethod()
        -- Sets default appearance of Johnny Replacer
        if isPhotoModeActive and PMPR.GetJEntity() ~= 1 and PMPR.IsDefaultAppearance() then
            SetDefaultAppearance()
        end
        -- Resets the condition for updating default appearance if user doesn't change replacers before reopening photo mode
        if not isPhotoModeActive and not PMPR.IsDefaultAppearance() then
            PMPR.ToggleDefaultAppearance(true)
        end
    end)
end

registerForEvent('onInit', function ()
    CheckDependencies()
    Initialize()
    SetupObservers()

    PMPR.modules.gameSession.OnStart(function()
        if not PMPR.modules.interface.initialized then
            PMPR.modules.interface.Initialize(PMPR.modules.data)
        end
        if not playerGender then
            UpdatePlayerGender()
        end
    end)
    PMPR.modules.gameSession.OnEnd(function()
        if playerGender then
            playerGender = nil
        end
    end)

end)

registerForEvent('onOverlayOpen', function()
    isOverlayOpen = true
end)

registerForEvent('onOverlayClose', function()
    isOverlayOpen = false
end)

registerForEvent('onDraw', function() 
    if not isOverlayOpen then
        return
    elseif isOverlayOpen then
        PMPR.modules.interface.DrawUI()
    end
end)

return PMPR