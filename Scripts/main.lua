local UEHelpers = require("UEHelpers")

---@class FOutputDevice
---@field Log function

---@diagnostic disable-next-line: assign-type-mismatch
local AstroPlayStatics = StaticFindObject("/Script/Astro.Default__AstroPlayStatics") ---@type UAstroPlayStatics

---@type EDeformType
local EDeformType = {
    Subtract = 0,
    Add = 1,
    Flatten = 2,
    ColorPick = 3,
    ColorPaint = 4,
    CountCreative = 5,
    Crater = 6,
    FlattenSubtractOnly = 7,
    FlattenAddOnly = 8,
    TrueFlatStamp = 9,
    PlatformSurface = 10,
    RevertModifications = 11,
    Count = 12,
    EDeformType_MAX = 13,
}

---@type EAstroGameMenuTutorialSlideDeckKey
local EAstroGameMenuTutorialSlideDeckKey = {
    Invalid = 0,
    Power = 1,
    SoilExcavation = 2,
    Research = 3,
    Printers = 4,
    BaseBuilding = 5,
    CreativeMode = 6,
    QHAll = 7,
    QHPlanets = 8,
    QHResources = 9,
    Automation = 10,
    Missions = 11,
    AdventurePopup = 12,
    Flora = 13,
    Rails = 14,
    Expansion = 15,
    GW_Tutorial = 16,
    EAstroGameMenuTutorialSlideDeckKey_MAX = 17,
}

---@type ESlateVisibility
local ESlateVisibility = {
    Visible = 0,
    Collapsed = 1,
    Hidden = 2,
    HitTestInvisible = 3,
    SelfHitTestInvisible = 4,
    ESlateVisibility_MAX = 5,
}

local IsAutoWalkEnabled = false
local MaxSpeed = nil
local IsFirstInit = true

local AstropediaWidget = {
    Planet = CreateInvalidObject(),
    Resources = CreateInvalidObject()
}

function FVector(x, y, z)
    return { X = x, Y = y, Z = z }
end

local function fvectorToUserData(v)
    return { X = v.X, Y = v.Y, Z = v.Z }
end

local function vec3ToFVector(v)
    return { X = v.x, Y = v.y, Z = v.z }
end

---@param self RemoteUnrealParam?
---@param NewPawn RemoteUnrealParam?
local function init(self, NewPawn)
    local pc, newPawn

    if not AstroPlayStatics:IsValid() then
        AstroPlayStatics = StaticFindObject("/Script/Astro.Default__AstroPlayStatics") ---@diagnostic disable-line: cast-local-type
    end

    if self then
        pc = self:get()
    else
        pc = AstroPlayStatics:GetLocalPlayController(UEHelpers:GetWorldContextObject())
    end
    ---@cast pc APlayControllerInstance_C

    if NewPawn then
        newPawn = NewPawn:get()
    else
        newPawn = UEHelpers:GetPlayer()
    end
    ---@cast newPawn ADesignAstro_C




    -- Spot Light
    -- https://dev.epicgames.com/documentation/en-us/unreal-engine/1.2---spot-light?application_version=4.27
    local light = newPawn.SpotLight
    if light and light:IsValid() then
        light:SetIntensity(1)
        light:SetAttenuationRadius(6000)
        light:SetInnerConeAngle(60)
        light:SetOuterConeAngle(80)
        light.AttachSocketName = FName("")
        light.RelativeLocation = { X = 0, Y = 0, Z = 1000 }
        light.RelativeRotation = { Pitch = -75, Yaw = 90, Roll = 0 }
        -- light:SetLightColor({ R = 255, G = 255, B = 255, A = 255 }, true)
        -- light:SetCastShadows(false)
    end

    -- newPawn.bIsLightsOn = false
    newPawn.bEnableHeadlook = false

    -- Mouse zoom
    pc.bGeometricZoom = false
    pc.MouseZoomTickSize = 0.2
end

---@return string?
local function getMoveForwardKey()
    local AstroGameUserSettings = FindFirstOf("AstroGameUserSettings")

    if AstroGameUserSettings:IsValid() then ---@cast AstroGameUserSettings UAstroGameUserSettings
        local inputAxisKeyMapping = AstroGameUserSettings:GetInputAxisMappingKeys(FName("MoveForward"), 1.0, false, false)

        if #inputAxisKeyMapping > 0 then
            ---@diagnostic disable-next-line: undefined-field
            local mapping = inputAxisKeyMapping[1]:get() ---@type FInputAxisKeyMapping

            return mapping.Key.KeyName:ToString()
        end
    end
end

---@param stopWalkKeys FName[]
---@param maxSpeed float
local function autoWalk(stopWalkKeys, maxSpeed)
    local delay = 20
    local iterations = 20

    local playerController = UEHelpers:GetPlayerController()
    if playerController == nil or not playerController:IsValid() then
        IsAutoWalkEnabled = false
        return
    end

    local designAstro = AstroPlayStatics:GetLocalAstroCharacter(UEHelpers:GetWorld())
    if not designAstro:IsValid() then
        IsAutoWalkEnabled = false
        return
    end ---@cast designAstro ADesignAstro_C

    local movementComponent = designAstro.AstroMovementComponent
    if not movementComponent:IsValid() then
        IsAutoWalkEnabled = false
        return
    end

    IsAutoWalkEnabled = not IsAutoWalkEnabled

    if MaxSpeed == nil then
        -- default: 850.0
        MaxSpeed = movementComponent.MaxSpeed
    end

    if IsAutoWalkEnabled then
        if maxSpeed then
            movementComponent.MaxSpeed = maxSpeed
        end
    else
        movementComponent.MaxSpeed = MaxSpeed
    end

    if IsAutoWalkEnabled then
        local i = 0

        LoopAsync(delay, function()
            if not movementComponent:IsValid() then
                IsAutoWalkEnabled = false
                -- restore MaxSpeed
                movementComponent.MaxSpeed = MaxSpeed
                return true
            end

            for _, key in ipairs(stopWalkKeys) do
                if playerController:IsInputKeyDown({ KeyName = key }) and i >= iterations then
                    IsAutoWalkEnabled = false
                    -- restore MaxSpeed
                    movementComponent.MaxSpeed = MaxSpeed
                    return true
                end
            end

            local fw = designAstro:GetActorForwardVector()
            designAstro:AddMovementInput({ X = fw.X, Y = fw.Y, Z = fw.Z }, 1, false)

            if i < iterations then
                i = i + 1
            end

            if IsAutoWalkEnabled == false then
                -- restore MaxSpeed
                movementComponent.MaxSpeed = MaxSpeed
                return true
            end

            return false
        end)
    end
end

local function getKeyNameByValue(keyValue)
    for k, v in pairs(Key) do
        if keyValue == v then
            return k
        end
    end
end

local function registerAutoWalkKeyBinds(moveForwardKey)
    local designAstro = UEHelpers:GetPlayer()
    if not designAstro:IsValid() then
        print("ERROR: ADesignAstro_C not found.")
        return
    end ---@cast designAstro ADesignAstro_C

    local enabledAutoWalk = true
    local speed = 850 -- 850

    -- Auto walk
    if enabledAutoWalk then
        local key = Key.Z
        if moveForwardKey == "Z" then
            key = Key.W
        end
        RegisterKeyBind(key, {}, function()
            autoWalk({
                FName("F"),
                FName("S"),
                FName("W"),
                FName("Z"),
            }, speed)
        end)
    end
end

-- Activate a light under the Terrain Tool.
RegisterHook("/Script/Astro.PlayController:IsTerrainBrushLightActive", function(self, ...)
    ---@diagnostic disable-next-line: redundant-return-value
    return true
end)

RegisterHook("/Script/Engine.PlayerController:ClientReceiveLocalizedMessage",
    function(...)
        if IsFirstInit then
            IsFirstInit = false

            registerAutoWalkKeyBinds(getMoveForwardKey())
        end
    end)

--#region CameraSpaceDrivingRig

-- Set a pitch limit for the driving camera.
---@param self ACameraSpaceDrivingRig_C
---@diagnostic disable-next-line: redundant-parameter
NotifyOnNewObject("/Game/Camera/CameraSpaceDrivingRig.CameraSpaceDrivingRig_C", function(self)
    ExecuteWithDelay(1000, function()
        if self:IsValid() then
            self.PitchControlModifier.UpperLimit = 15
            self.PitchControlModifier.LowerLimit = -65
            self.PitchControlModifier.SpongeRange = 0
        end
    end)
end)
--[[ Debug
local drills = FindAllOf("Drill_T2_HardTerrain_1_C") ---@type ADrill_T2_HardTerrain_1_C[]?
if drills then
    for index, value in ipairs(drills) do
        print(index, value.UpArrowWrapper.RelativeScale3D.Y, value.DownArrowWrapper.RelativeScale3D.Y)
    end
end ]]
--#endregion

--#region Dynamite
-- local dynamites = FindAllOf("Dynamite_C") ---@type ADynamite_C[]?
-- if dynamites then
--     for index, dynamite in ipairs(dynamites) do
--         local loc = dynamite:K2_GetActorLocation()
--         dynamite.Explosive.Power = 100000                       -- default: 1
--         dynamite.Explosive.AutoResourceGenerationPercentage = 0 -- default: 2.5
--         dynamite.Countdown = 30                                 -- default: 3
--     end
-- end
--#endregion

ExecuteWithDelay(5000, function()
    ---@param self RemoteUnrealParam
    ---@param NewPawn RemoteUnrealParam
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self, NewPawn)
        init(self, NewPawn)
    end)
end)

-- Keybind to turn on/off the character torch (light).
RegisterKeyBind(Key.T, { ModifierKey.SHIFT }, function()
    local astroChar = AstroPlayStatics:GetLocalAstroCharacter(UEHelpers:GetWorld())
    astroChar.bIsLightsOn = not astroChar.bIsLightsOn
end)

-- Keybind to flip the rover when it is flipped. No need to wait for the tooltip to be displayed.
RegisterKeyBind(Key.R, { ModifierKey.SHIFT }, function()
    local pc = AstroPlayStatics:GetLocalPlayController(UEHelpers:GetWorldContextObject())
    local vehicle = pc.ControlledVehicle
    if vehicle:IsA("/Game/Vehicles/Rover_Base.Rover_Base_C") then ---@cast vehicle ARover_Base_C
        vehicle:ExecuteFlip()
    end
end)

--#region Deformation
-- Logging
-- RegisterHook("/Script/Astro.AstroPlanet:OnDeformationComplete",
--     function(self, params)
--         params = params:get() ---@cast params FDeformationParamsT2
--         print(params.AutoCreateResourceEfficiency,
--             params.CreativeModeNoResourceCollection,
--             params.DeltaTime,
--             params.ForceRemoveDecorators,
--             params.HardnessPenetration,
--             params.Instigator,
--             params.Intensity,
--             params.Location.X,
--             params.Location.Y,
--             params.Location.Z,
--             params.MaterialIndex,
--             params.Normal.X,
--             params.Normal.Y,
--             params.Normal.Z,
--             params.Operation,
--             params.Scale,
--             params.SequenceNumber,
--             params.Shape,
--             params.bEasyUnbury,
--             params.bUseAlternatePolygonization
--         )
--     end)

-- Keybind to open the Astropedia with the planets tab.
RegisterKeyBind(Key.J, {}, function()
    local astroHUD = FindFirstOf("AstroHUD") ---@cast astroHUD AAstroHUD

    if not astroHUD:IsValid() then
        return
    end

    if not AstropediaWidget.Planet:IsValid() then
        AstropediaWidget.Planet = astroHUD:CreateAstropediaWidget(EAstroGameMenuTutorialSlideDeckKey.QHPlanets, 0)
        return
    end

    if AstropediaWidget.Planet:IsInViewport() == true then
        AstropediaWidget.Planet:RemoveFromViewport()
    else
        AstropediaWidget.Planet:AddToViewport(0)
    end
end)

-- Keybind to open the Astropedia with the resources tab.
RegisterKeyBind(Key.H, {}, function()
    local astroHUD = FindFirstOf("AstroHUD") ---@cast astroHUD AAstroHUD

    if not astroHUD:IsValid() then
        return
    end

    if not AstropediaWidget.Resources:IsValid() then
        AstropediaWidget.Resources = astroHUD:CreateAstropediaWidget(EAstroGameMenuTutorialSlideDeckKey.QHResources, 0)
        return
    end

    if AstropediaWidget.Resources:IsInViewport() == true then
        AstropediaWidget.Resources:RemoveFromViewport()
    else
        AstropediaWidget.Resources:AddToViewport(0)
    end
end)

do
    local key = getMoveForwardKey()
    if key ~= nil and key ~= "" and key ~= "None" then
        registerAutoWalkKeyBinds(key)
    end
end

init()
