local UEHelpers = require("UEHelpers")

---@diagnostic disable-next-line: assign-type-mismatch
local AstroPlayStatics = StaticFindObject("/Script/Astro.Default__AstroPlayStatics") ---@type UAstroPlayStatics

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

---@class Debug
---@field staticMeshActorClassShortName string
---@field staticMeshActorClassName string
---@field staticMeshActorClass UClass?
---@field material UMaterialInterface?
---@field mesh UStaticMesh?
---@field scale FVector
local debug = {
    staticMeshActorClassShortName = "StaticMeshActor",
    staticMeshActorClassName = "/Script/Engine.StaticMeshActor",
    staticMeshActorClass = nil,
    material = nil,
    material2 = nil,
    mesh = nil,
    scale = { X = 0.1, Y = 0.1, Z = 0.1 }
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

---@param world UWorld
---@param staticMeshActorClass UClass
---@param mesh UStaticMesh
---@param material UMaterialInterface
---@param location FVector
---@param rotation FRotator?
---@param scale FVector?
---@param color FLinearColor?
---@return AStaticMeshActor
local function spawnDebugObject(world, staticMeshActorClass, mesh, material, location, rotation, scale, color)
    rotation = rotation or { Pitch = 0, Roll = 0, Yaw = 0 }
    scale = scale or { X = 1, Y = 1, Z = 1 }
    color = color or { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }

    ---@diagnostic disable-next-line: undefined-field
    local staticMeshActor = world:SpawnActor(staticMeshActorClass, fvectorToUserData(location),
        rotation) ---@cast staticMeshActor AStaticMeshActor
    assert(staticMeshActor:IsValid())

    staticMeshActor.StaticMeshComponent.StaticMesh = mesh

    local matInstance = staticMeshActor.StaticMeshComponent:CreateDynamicMaterialInstance(0, material, FName(0))
    matInstance:SetVectorParameterValue(FName("Color"), color)

    local bounds = staticMeshActor.StaticMeshComponent.StaticMesh:GetBounds()

    local newScale = {
        X = scale.X / bounds.BoxExtent.X,
        Y = scale.Y / bounds.BoxExtent.Y,
        Z = scale.Z / bounds.BoxExtent.Z
    }
    staticMeshActor:SetActorScale3D(newScale)

    return staticMeshActor
end

---@param self RemoteUnrealParam?
---@param NewPawn RemoteUnrealParam?
local function init(self, NewPawn)
    local pc, newPawn

    ---@diagnostic disable-next-line: assign-type-mismatch
    AstroPlayStatics = StaticFindObject("/Script/Astro.Default__AstroPlayStatics") ---@type UAstroPlayStatics

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

    ExecuteInGameThread(function()
        --[[
        Open FModel, go in Engine > Content > EngineDebugMaterials

        "/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"
        "/Engine/EngineDebugMaterials/WireframeMaterial.WireframeMaterial" -- Params: Color (wireframe, emissive).
        "/Engine/EngineDebugMaterials/DebugMeshMaterial.DebugMeshMaterial" -- Params: Color (emissive).
        "/Engine/EngineDebugMaterials/DebugEditorMaterial.DebugEditorMaterial" -- Params: Color, Desaturation, Opacity (emissive).
        "/Engine/EngineDebugMaterials/M_SimpleTranslucent.M_SimpleTranslucent" -- Params: Color (translucent).
        "/Engine/EngineMaterials/EmissiveTexturedMaterial.EmissiveTexturedMaterial" -- Params: Texture.
        "/Engine/EngineMaterials/WorldGridMaterial.WorldGridMaterial" -- Params: None.
    ]]
        local mat = "/Engine/EngineDebugMaterials/WireframeMaterial.WireframeMaterial"
        LoadAsset(mat) ---@diagnostic disable-line: undefined-global
        local mat2 = "/Engine/EngineDebugMaterials/DebugMeshMaterial.DebugMeshMaterial"
        LoadAsset(mat2) ---@diagnostic disable-line: undefined-global

        -- Cone, Cube, Cylinder, Plane, Sphere
        local mesh = "/Engine/BasicShapes/Sphere.Sphere"
        LoadAsset(mesh) ---@diagnostic disable-line: undefined-global

        debug.staticMeshActorClass = StaticFindObject(debug.staticMeshActorClassName) ---@diagnostic disable-line: assign-type-mismatch
        debug.material = StaticFindObject(mat) ---@diagnostic disable-line: assign-type-mismatch
        debug.material2 = StaticFindObject(mat2) ---@diagnostic disable-line: assign-type-mismatch
        debug.mesh = StaticFindObject(mesh) ---@diagnostic disable-line: assign-type-mismatch

        if not debug.staticMeshActorClass:IsValid() then
            debug.staticMeshActorClass = StaticFindObject(debug.staticMeshActorClassName) ---@diagnostic disable-line: assign-type-mismatch
        end
        if not debug.material:IsValid() then
            debug.material = StaticFindObject(mat) ---@diagnostic disable-line: assign-type-mismatch
        end
        if not debug.mesh:IsValid() then
            debug.mesh = StaticFindObject(mesh) ---@diagnostic disable-line: assign-type-mismatch
        end

        if not AstroPlayStatics:IsValid() then
            AstroPlayStatics = StaticFindObject("/Script/Astro.Default__AstroPlayStatics") ---@diagnostic disable-line: cast-local-type
        end
    end)

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

-- Activate a light under the Terrain Tool.
RegisterHook("/Script/Astro.PlayController:IsTerrainBrushLightActive", function(self, ...)
    ---@diagnostic disable-next-line: redundant-return-value
    return true
end)

--#region CameraSpaceDrivingRig

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
RegisterKeyBind(Key.L, {}, function()
    local astroChar = AstroPlayStatics:GetLocalAstroCharacter(UEHelpers:GetWorld())
    astroChar.bIsLightsOn = not astroChar.bIsLightsOn
end)

-- Keybind to flip the rover when it is flipped. No need to wait for the tooltip to be displayed.
RegisterKeyBind(Key.FOUR, { ModifierKey.SHIFT }, function()
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

RegisterKeyBind(Key.R, { ModifierKey.SHIFT }, function()
    local pc = AstroPlayStatics:GetLocalPlayController(UEHelpers:GetWorld())
    local loc = pc:GetAstroCharacter():K2_GetActorLocation()
    local norm = math.sqrt(loc.X ^ 2 + loc.Y ^ 2 + loc.Z ^ 2)
    local normal = { X = loc.X / norm, Y = loc.Y / norm, Z = loc.Z / norm }

    local sphereSize = 5000

    pc:ClientDoDeformation(
        {
            AutoCreateResourceEfficiency = 0,
            CreativeModeNoResourceCollection = false,
            DeltaTime = 0.03299999982118, -- ???
            ForceRemoveDecorators = false,
            HardnessPenetration = 10,
            Instigator = nil,
            Intensity = 5, -- minus 1 to do progressive restoration
            Location = { X = loc.X, Y = loc.Y, Z = loc.Z },
            MaterialIndex = -1,
            Normal = { X = normal.X, Y = normal.Y, Z = normal.Z },
            Operation = EDeformType.RevertModifications,
            Scale = sphereSize, -- distance, radius
            SequenceNumber = 0,
            Shape = 0,
            bEasyUnbury = false,
            bUseAlternatePolygonization = true
        })

    local dbgObjectsInst = FindAllOf(debug.staticMeshActorClassShortName) ---@type AActor[]?
    if dbgObjectsInst then
        for _, value in ipairs(dbgObjectsInst) do
            value:K2_DestroyActor()
        end
    end

    local obj = spawnDebugObject(UEHelpers:GetWorld(), debug.staticMeshActorClass, debug.mesh, debug.material, loc, nil,
        { X = sphereSize, Y = sphereSize, Z = sphereSize },
        { R = 0, G = 1, B = 0, A = 1 })
    local obj2 = spawnDebugObject(UEHelpers:GetWorld(), debug.staticMeshActorClass, debug.mesh, debug.material2, loc, nil,
        { X = sphereSize, Y = sphereSize, Z = sphereSize },
        { R = 0, G = 1, B = 0, A = 0.05 })

    -- destroy the debug object (sphere) after n seconds
    ExecuteWithDelay(30000, function()
        if obj:IsValid() then obj:K2_DestroyActor() end
        if obj2:IsValid() then obj2:K2_DestroyActor() end
    end)
end)
--#endregion

-- Keybind to toggle the game pause.
RegisterKeyBind(Key.PAUSE, function()
    local gameplayStatics = UEHelpers.GetGameplayStatics()
    local world = UEHelpers.GetWorld()

    gameplayStatics:SetGamePaused(world, not gameplayStatics:IsGamePaused(world) and true or false)
end)

init()
local dbgObjectsInst = FindAllOf(debug.staticMeshActorClassShortName) ---@type AActor[]?
if dbgObjectsInst then
    for _, value in ipairs(dbgObjectsInst) do
        value:K2_DestroyActor()
    end
end
