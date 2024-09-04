local carDamages = {}
local next <const> = next

function StoreVehicleDamage(vehicle, numberPlate)
    if not carDamages[numberPlate] then
        carDamages[numberPlate] = {
            bodyHealth = GetVehicleBodyHealth(vehicle),
            doors = {},
            windows = {},
            tires = {}
        }
    end

    for doorIndex = 0, 6 do
        if IsVehicleDoorDamaged(vehicle, doorIndex) == 1 then
            carDamages[numberPlate].doors[doorIndex] = true
        end
    end

    for windowIndex = 0, 7 do
        local windowIntact = IsVehicleWindowIntact(vehicle, windowIndex)
        carDamages[numberPlate].windows[windowIndex] = not windowIntact
    end

    for tireIndex = 0, 7 do
        local tireBurst = IsVehicleTyreBurst(vehicle, tireIndex, false)
        carDamages[numberPlate].tires[tireIndex] = tireBurst
    end
end

function GetVehicleDamageTable(numberPlate)
    return carDamages[numberPlate] or nil
end

function SetVehicleDamageTable(numberPlate, damageData)
    carDamages[numberPlate] = damageData
end

function ApplyVehicleDamage(vehicle, damageData)
    if not next(damageData) then return end

    for doorIndex, doorDamage in pairs(damageData.doors) do
        if doorDamage then
            SetVehicleDoorBroken(vehicle, doorIndex, true)
        end
    end

    for windowIndex, windowBroken in pairs(damageData.windows) do
        if windowBroken then
            RemoveVehicleWindow(vehicle, windowIndex)
        end
    end

    for tireIndex, tireBurst in pairs(damageData.tires) do
        if tireBurst then
            SetVehicleTyreBurst(vehicle, tireIndex, false, 1000.0)
        end
    end

    SetVehicleBodyHealth(vehicle, damageData.bodyHealth)
end
