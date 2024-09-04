--/////////// vRP bind \\\\\\\\\\\--

local vRPCax = {}
Tunnel.bindInterface("ax_garages", vRPCax)
Proxy.addInterface("ax_garages", vRPCax)
vRP = Proxy.getInterface("vRP")
local vRPSax <const> = Tunnel.getInterface("ax_garages", "ax_garages")

--===============================================--

local CreateThread <const> = CreateThread
local Wait <const> = Wait
local DrawPoly <const> = DrawPoly

local inGarage = false
local cam, currentVehicle;
local distance <const> = 5.0 --// Distance in first person view
local defaultCameraFov <const> = 60.0
local saveWaitTimer <const> = 30 * 1000

--Blip Settings
local width <const> = 3.15
local length <const> = 5.3
local height <const> = 0.01

CreateThread(function()
    SetBlipAlpha(GetNorthRadarBlip(), 0)
end)

local defaultBoxColor = { 0, 255, 0 }
local boxColor = { 0, 255, 0 }
local textgaraj;

local garages = {}
local currentGarageIndex;

local blips = {}

local function CreateBlip(coords, id, color, text, garageID)
    blips[garageID] = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blips[garageID], id)
    SetBlipDisplay(blips[garageID], 4)
    SetBlipScale(blips[garageID], 0.8)
    SetBlipColour(blips[garageID], color)
    SetBlipAsShortRange(blips[garageID], true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(text)
    EndTextCommandSetBlipName(blips[garageID])
end

local cameraEnum <const> = {
    FIRST_PERSON = 1,
    TOP_VIEW = 2
}

local function ClearCamera()
    if cam then
        RenderScriptCams(false, false, 0, true, true)
        SetCamActive(cam, false)
        DestroyCam(cam)
    end
end

local cameraEnum = {
    FIRST_PERSON = nil,
    TOP_VIEW = nil
}

local function SetFirstPersonCamera()
    ClearCamera()
    local playerPed <const> = PlayerPedId()
    SetEntityAlpha(playerPed, 0, false)
    SetEntityVisible(playerPed, false)
    SetEntityCollision(playerPed, false, false)
    FreezeEntityPosition(playerPed, true)
    local camCoords = cameraEnum.FIRST_PERSON or GetOffsetFromEntityInWorldCoords(currentVehicle, 0.0, distance, 1.1)
    cameraEnum.FIRST_PERSON = camCoords;

    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, camCoords)
    PointCamAtEntity(cam, currentVehicle, 0.0, 0.0, 0.0, true)
    SetCamFov(cam, defaultCameraFov)
    RenderScriptCams(true, false, 0, true, true)
end

local TopViewDistance <const> = 7.0

local function SetTopViewCamera()
    ClearCamera()
    local camCoords = cameraEnum.TOP_VIEW or
        GetOffsetFromEntityInWorldCoords(currentVehicle, 0.0, 0.2, TopViewDistance + 0.0)
    cameraEnum.TOP_VIEW = camCoords;
    local cameraHeading = GetEntityHeading(currentVehicle) - 180.0

    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, camCoords)
    SetCamRot(cam, -90.0, 0.0, cameraHeading)
    SetCamFov(cam, defaultCameraFov)
    RenderScriptCams(true, false, 0, true, true)
end


local function ActivateCamera(cameraType)
    if cameraType == cameraEnum.FIRST_PERSON then
        SetFirstPersonCamera()
    elseif cameraType == cameraEnum.TOP_VIEW then
        SetTopViewCamera()
    end
end

vRPCax.refreshGarageData = function(data)
    --// Insert a new garage
    for _, garage in pairs(data) do
        if not blips[garage.id] then
            CreateBlip(garage.coords, 357, 2, garage.name, garage.id)
            garage.boxColor = defaultBoxColor
        end
    end

    --// Delete a garage
    for _, garage in pairs(garages) do
        local found = false
        for _, v in pairs(data) do
            if garage.id == v.id then
                found = true
            end
        end

        if not found then
            RemoveBlip(blips[garage.id])
            blips[garage.id] = nil
            goto finish
        end
    end
    ::finish::

    garages = data
end

CreateThread(function()
    Wait(200)
    vRPSax.getGaragesData({}, function(data)
        garages = data

        for _, garage in pairs(garages) do
            CreateBlip(garage.coords, 357, 2, garage.name, garage.id)
            garage.boxColor = defaultBoxColor
        end
    end)
end)

local function GetAngledPosition(center, dist, angle, mod)
    local angRad = math.rad(angle)
    return center + mod * dist * vector3(
        math.cos(angRad),
        math.sin(angRad),
        0.0
    )
end

local spawnHeading;
local modelLoading = false

local function spawnCar(model, plate, engineHealth, spawnCoords, heading)
    if modelLoading then return end

    local engine = tonumber(string.format("%.1f", engineHealth)) * 10

    if DoesEntityExist(currentVehicle) then
        DeleteEntity(currentVehicle)
    end
    Wait(50)

    RequestModel(model)
    while not HasModelLoaded(model) do
        modelLoading = true
        Citizen.Wait(0)
    end
    modelLoading = false

    spawnHeading = heading + 0.0
    local coords = spawnCoords

    currentVehicle = CreateVehicle(model, coords.x, coords.y, coords.z + 0.2, spawnHeading, true, false)
    Wait(10)
    SetEntityHeading(currentVehicle, spawnHeading)
    SetVehicleLights(currentVehicle, 2)
    SetVehicleNumberPlateText(currentVehicle, plate)
    SetVehicleEngineHealth(currentVehicle, engine + 0.0)
    SetVehicleLights(currentVehicle, 0)

    SendNUIMessage({
        act = 'setHeading',
        heading = spawnHeading,
    })

    local damageData = GetVehicleDamageTable(plate)
    if damageData then
        ApplyVehicleDamage(currentVehicle, damageData)
    end
end

local function DeleteMockCar()
    if DoesEntityExist(currentVehicle) then
        DeleteEntity(currentVehicle)
    end
end

local function round(number)
    return math.floor(number + 0.5)
end

local function parseDecimal(number, decimalPlaces)
    local multiplier = 10 ^ decimalPlaces
    return math.floor(number * multiplier) / multiplier
end


local server_maxSpeed = 500        --// Max Speed
local server_maxTraction = 3.5     --// Max Traction
local server_maxBraking = 2.5      --// Max Braking
local server_maxAcceleration = 2.5 --// Max Acceleration

local function getMaxSpeed(veh)
    local maxSpeed = GetVehicleModelMaxSpeed(GetHashKey(veh)) * 3.6
    return { value = parseDecimal(maxSpeed, 0), percentage = round(maxSpeed / server_maxSpeed * 100) }
end

local function getMaxTraction(veh)
    local maxTraction = GetVehicleModelMaxTraction(GetHashKey(veh))
    return { value = parseDecimal(maxTraction, 0), percentage = round(maxTraction / server_maxTraction * 100) }
end

local function getMaxBrakeing(veh)
    local maxBraking = GetVehicleModelMaxBraking(GetHashKey(veh))
    return { value = parseDecimal(maxBraking, 1), percentage = round(maxBraking / server_maxBraking * 100) }
end

local function getMaxAcceleration(veh)
    local maxAcceleration = GetVehicleModelAcceleration(GetHashKey(veh))
    return { value = parseDecimal(maxAcceleration, 1), percentage = round(maxAcceleration / server_maxAcceleration * 100) }
end



--Thread to display the Polygons
local textui = false

CreateThread(function()
    Wait(500)
    while true do
        Wait(1)
        if not inGarage then
            for index, garage in pairs(garages) do
                local dist = #(GetEntityCoords(PlayerPedId()) - garage.coords)
                if dist < 30.0 then
                    local center = vector3(garage.coords.x, garage.coords.y, garage.coords.z - 0.26)
                    local diagonal = math.sqrt((width / 2) ^ 2 + (length / 2) ^ 2)
                    local fullDiagonal = math.sqrt(width ^ 2 + length ^ 2)
                    local boxHeight = vector3(0.0, 0.0, height)

                    local newAngle = math.deg(math.asin(length / fullDiagonal))

                    local topRight = GetAngledPosition(center, diagonal, garage.heading + newAngle, 1)
                    local bottomRight = GetAngledPosition(center, diagonal, garage.heading - newAngle, 1)
                    local bottomLeft = GetAngledPosition(center, diagonal, garage.heading + newAngle, -1)
                    local topLeft = GetAngledPosition(center, diagonal, garage.heading - newAngle, -1)

                    DrawPoly(topRight, topLeft, topLeft + boxHeight, garage.boxColor[1], garage.boxColor[2],
                        garage.boxColor[3], 100)
                    DrawPoly(topRight, topLeft + boxHeight, topRight + boxHeight, garage.boxColor[1], garage.boxColor[2],
                        garage.boxColor[3],
                        100)

                    DrawPoly(bottomLeft, bottomRight, bottomRight + boxHeight, garage.boxColor[1], garage.boxColor[2],
                        garage.boxColor[3], 100)
                    DrawPoly(bottomLeft, bottomRight + boxHeight, bottomLeft + boxHeight, garage.boxColor[1],
                        garage.boxColor[2],
                        garage.boxColor[3], 100)

                    DrawPoly(topLeft, bottomLeft, bottomLeft + boxHeight, garage.boxColor[1], garage.boxColor[2],
                        garage.boxColor[3], 100)
                    DrawPoly(topLeft, bottomLeft + boxHeight, topLeft + boxHeight, garage.boxColor[1], garage.boxColor
                        [2], garage.boxColor[3],
                        100)

                    DrawPoly(bottomRight, topRight, topRight + boxHeight, garage.boxColor[1], garage.boxColor[2],
                        garage.boxColor[3], 100)
                    DrawPoly(bottomRight, topRight + boxHeight, bottomRight + boxHeight, garage.boxColor[1],
                        garage.boxColor[2],
                        garage.boxColor[3], 100)

                    DrawPoly(bottomRight + boxHeight, topRight + boxHeight, topLeft + boxHeight, garage.boxColor[1],
                        garage.boxColor
                        [2],
                        garage.boxColor[3],
                        100)
                    DrawPoly(topLeft + boxHeight, bottomLeft + boxHeight, bottomRight + boxHeight, garage.boxColor[1],
                        garage.boxColor[2],
                        garage.boxColor[3]
                        , 100)
                    if dist < 2.0 then
                        if IsPedInAnyVehicle(PlayerPedId(), false) then
                            textgaraj = "[E] Pentru a parca masina"
                        else
                            textgaraj = "[E] Pentru a deschide garajul"
                        end
                        if not textui then
                            textui = true
                            Config.functions.toggleTextUi(textgaraj)
                        end
                        if IsControlJustReleased(0, 38) then
                            Config.functions.toggleTextUi()

                            if IsPedInAnyVehicle(PlayerPedId(), false) then
                                local vehiclePedIsIn = GetVehiclePedIsIn(PlayerPedId(), false)

                                vRPSax.setCarParked(
                                    { GetVehicleNumberPlateText(vehiclePedIsIn), garage.id, GetVehicleEngineHealth(
                                        vehiclePedIsIn), GetVehicleFuelLevel(vehiclePedIsIn) }, function(success)
                                        if success then
                                            SetVehicleEngineOn(vehiclePedIsIn, false, false, false)
                                            SetVehicleUndriveable(vehiclePedIsIn, false)
                                            SetVehicleDoorsLocked(vehiclePedIsIn, 0)
                                            Wait(1000)
                                            TaskLeaveVehicle(PlayerPedId(), vehiclePedIsIn, 64)
                                            Wait(1000)

                                            SetVehicleDoorsLocked(vehiclePedIsIn, 2)

                                            Wait(2000)

                                            DeleteEntity(vehiclePedIsIn)
                                            Config.functions.notify(
                                                "De acum poti scoate<span> masina </span> doar de aici", "warn")

                                            SetBlipColour(blips[garage.id], 2)

                                            Wait(3000)
                                            garage.boxColor = { 0, 255, 0 }
                                            Wait(1000)
                                            textui = false
                                        end
                                    end)
                            else
                                vRPSax.getPlayersCars({ garage.id }, function(playerCars)
                                    if playerCars then
                                        currentGarageIndex = index
                                        for i, v in pairs(playerCars) do
                                            playerCars[i].maxSpeed = getMaxSpeed(v.model)
                                            playerCars[i].acceleration = getMaxAcceleration(v.model)
                                            playerCars[i].breaking = getMaxBrakeing(v.model)
                                            playerCars[i].traction = getMaxTraction(v.model)
                                        end

                                        Config.functions.toggleHud(false)
                                        DisplayRadar(false)

                                        DoScreenFadeOut(400)
                                        Wait(300)
                                        SendNUIMessage({
                                            act = "open",
                                            playerCars = playerCars
                                        })
                                        vRPSax.setVirtualWorld({ true })
                                        SetNuiFocus(true, true)

                                        for _, v in pairs(playerCars) do
                                            SetVehicleDamageTable(v.plate, v.damageData)
                                        end

                                        spawnCar(playerCars[1].model, playerCars[1].plate, playerCars[1].engineHealth,
                                            garage.coords, garage.heading)

                                        ActivateCamera(cameraEnum.FIRST_PERSON)
                                        Wait(500)
                                        DoScreenFadeIn(400)

                                        inGarage = true
                                    else
                                        Config.functions.notify(
                                            "Nu detii <span> vehicule </span> in acest garaj", "error")
                                    end
                                end)
                            end
                        end
                    else
                        if textui then
                            textui = false
                            Config.functions.toggleTextUi()
                        end
                    end
                end
            end
        end
    end
end)

local function openVehicleParts(vehicle, open)
    if open then
        SetVehicleDoorOpen(vehicle, 0, false, false) -- Open front left door
        SetVehicleDoorOpen(vehicle, 1, false, false) -- Open front right door
        SetVehicleDoorOpen(vehicle, 2, false, false) -- Open back left door
        SetVehicleDoorOpen(vehicle, 3, false, false) -- Open back right door
        SetVehicleDoorOpen(vehicle, 4, false, false) -- Open hood
        SetVehicleDoorOpen(vehicle, 5, false, false) -- Open trunk
        RollDownWindows(vehicle)                     -- Open windows
    else
        SetVehicleDoorShut(vehicle, 0, false)        -- Close front left door
        SetVehicleDoorShut(vehicle, 1, false)        -- Close front right door
        SetVehicleDoorShut(vehicle, 2, false)        -- Close back left door
        SetVehicleDoorShut(vehicle, 3, false)        -- Close back right door
        SetVehicleDoorShut(vehicle, 4, false)        -- Close hood
        SetVehicleDoorShut(vehicle, 5, false)        -- Close trunk
        RollUpWindow(vehicle, 0)                     -- Close front left window
        RollUpWindow(vehicle, 1)                     -- Close front right window
        RollUpWindow(vehicle, 2)                     -- Close back left window
        RollUpWindow(vehicle, 3)                     -- Close back right window
    end
end


RegisterCommand('engineon', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    if DoesEntityExist(vehicle) then
        SetVehicleUndriveable(vehicle, false)
        SetVehicleEngineOn(vehicle, true, false, false)
    end
end)

local function getPersonalCarOut(model, spawnCoords, plate, engineHealth, fuel)
    local engine = tonumber(engineHealth) * 10
    Wait(50)

    local coords = spawnCoords

    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z + 0.2, spawnHeading, true, false)
    Wait(10)
    SetEntityHeading(vehicle, spawnHeading)
    SetVehicleLights(vehicle, 2)
    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleEngineHealth(vehicle, engine + 0.0)
    SetVehicleLights(vehicle, 0)
    SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
    SetFollowPedCamViewMode(4)
    SetFollowVehicleCamViewMode(4)
    SetEntityHeading(vehicle, spawnHeading)
    SetVehicleFuelLevel(vehicle, fuel + 0.0)

    -- Prevent the vehicle from starting
    SetVehicleEngineOn(vehicle, false, false, true)
    SetVehicleUndriveable(vehicle, true)
    SetVehicleLights(vehicle, 0)
    DoScreenFadeIn(400)
    inGarage = false
    garages[currentGarageIndex].boxColor = { 255, 0, 0 }
    textgaraj = "[E] Pentru a parca masina"
    Config.functions.notify("Ai scos <span> masina </span> din garaj", "success")
    textui = false

    local damageData = GetVehicleDamageTable(plate)
    if damageData then
        ApplyVehicleDamage(vehicle, damageData)
    end

    CreateThread(function()
        while true do
            local coords = GetEntityCoords(PlayerPedId())
            Wait(1000)
            if #(coords - garages[currentGarageIndex].coords) > 5.0 then
                garages[currentGarageIndex].boxColor = defaultBoxColor
                currentGarageIndex = nil
                break
            end
        end
    end)

    CreateThread(function()
        while DoesEntityExist(vehicle) do
            StoreVehicleDamage(vehicle, plate)
            vRPSax.storeVehicleDamageTable({ plate, GetVehicleDamageTable(plate) })
            Wait(saveWaitTimer)
        end
    end)
end

local function ClearUIelements()
    local playerPed <const> = PlayerPedId()
    Config.functions.toggleHud(true)

    SetNuiFocus(false, false)
    RenderScriptCams(false, true, 0, true, true)
    SetEntityVisible(playerPed, true)
    SetEntityAlpha(playerPed, 255, false)

    inGarage = false
    SetEntityCollision(playerPed, true, true)
    FreezeEntityPosition(playerPed, false)
    DeleteMockCar()
    ClearCamera()
    vRPSax.setVirtualWorld({ false })
    cameraEnum = {
        FIRST_PERSON = nil,
        TOP_VIEW = nil
    }
end

RegisterNuiCallback("ax_garages", function(data, cb)
    if data.action == "closeUI" then
        ClearUIelements();
        textui = false
    elseif data.action == 'changeCar' then
        spawnCar(data.model, data.plate, data.engineHealth, garages[currentGarageIndex].coords,
            garages[currentGarageIndex].heading)
    elseif data.action == 'toggleVehicleExtras' then
        openVehicleParts(currentVehicle, data.state)
    elseif data.action == 'toggleTopView' then
        local state = data.state
        if state then
            ActivateCamera(cameraEnum.TOP_VIEW)
        else
            ActivateCamera(cameraEnum.FIRST_PERSON)
        end
    elseif data.action == 'getVehicleOut' then
        local carData = data.carData
        DoScreenFadeOut(400)
        Wait(500)
        openVehicleParts(currentVehicle, false)
        ClearUIelements()
        Wait(500)
        vRPSax.setCarOut({ carData.plate }, function(success)
            if success then
                getPersonalCarOut(carData.model, garages[currentGarageIndex].coords, carData.plate, carData.engineHealth,
                    carData.fuel)
            end
        end)
    elseif data.action == 'changePov' then
        data.value = tonumber(data.value)
        if data.value <= defaultCameraFov then
            SetCamFov(cam, data.value)
        end
    elseif data.action == 'changeHeading' then
        local newHeading = GetEntityHeading(currentVehicle) + tonumber(data.value)
        SetEntityHeading(currentVehicle, newHeading)
    end

    cb('ok')
end)
