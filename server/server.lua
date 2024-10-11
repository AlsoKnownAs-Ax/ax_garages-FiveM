--/////////// vRP bind \\\\\\\\\\\--

local Tunnel <const> = module("vrp", "lib/Tunnel")
local Proxy <const> = module("vrp", "lib/Proxy")

local vRP <const> = Proxy.getInterface("vRP")
local vRPclient <const> = Tunnel.getInterface("vRP", "ax_garages")

local vRPCax <const> = Tunnel.getInterface("ax_garages", "ax_garages")

local vRPSax = {}
Tunnel.bindInterface("ax_garages", vRPSax)
Proxy.addInterface("ax_garages", vRPSax)

--===============================================--
------------------------------------------------------
function debug(...)
    if Config.debug then
        local args = { ... }

        for i = 1, #args do
            local arg = args[i]
            args[i] = type(arg) == 'table' and json.encode(arg, { sort_keys = true, indent = true }) or tostring(arg)
        end

        print('^6[DEBUG] ^7', table.concat(args, '\t'))
    end
end

------------------------------------------------------

local garages = {}

local getGarageData <const> = function(garageID)
    for i, garage in pairs(garages) do
        if (garage.id == garageID) then
            return garage
        end
    end

    return false
end

local function round(number)
    return math.floor(number + 0.5)
end

vRPSax.setVirtualWorld = function(state, vehicle)
    if state then
        SetPlayerRoutingBucket(source, source)
    else
        SetPlayerRoutingBucket(source, 0)
    end
end

vRPSax.getGaragesData = function()
    return garages
end

local outvehs = {}

vRPSax.setCarParked = function(veh_plate, garageID, engineHealth, fuel)
    local source <const> = source
    local user_id <const> = vRP.getUserId { source }

    local p = promise:new()
    exports.oxmysql:execute(
        'UPDATE vrp_user_vehicles SET status = @status, garage = @garage, engine = @engine, fuel = @fuel  WHERE veh_plate = @plate AND user_id = @user_id',
        {
            status = "Parcat",
            garage = garageID,
            engine = round(engineHealth) + 0.0,
            fuel = fuel,
            plate = veh_plate,
            user_id = user_id
        }, function(affectedRows)
            if affectedRows.affectedRows <= 0 then
                vRPclient.notify(source, { "Aceasta masina nu iti apartine!", "error" })
                p:resolve(false)
            else
                p:resolve(true)
            end
        end)

    local status = Citizen.Await(p)

    if status then
        if outvehs[user_id] then
            for i = 1, #outvehs[user_id] do
                if outvehs[user_id][i] == veh_plate then
                    table.remove(outvehs[user_id], i)
                    goto finish
                end
            end
        end
        ::finish::

        return true
    end

    return false
end

vRPSax.setCarOut = function(veh_plate, carData)
    local source <const> = source
    local user_id <const> = vRP.getUserId { source }

    if not outvehs[user_id] then
        outvehs[user_id] = {}
    end

    table.insert(outvehs[user_id], veh_plate)

    return true
end

vRPSax.isCarOut = function(veh_plate)
    local source <const> = source
    local user_id <const> = vRP.getUserId { source }

    if outvehs[user_id] then
        for i = 1, #outvehs[user_id] do
            if outvehs[user_id][i] == veh_plate then
                return true
            end
        end
    end

    return false
end

vRPSax.storeVehicleDamageTable = function(plate, damageData)
    local source <const> = source
    local user_id <const> = vRP.getUserId { source }

    exports.oxmysql:execute('UPDATE vrp_user_vehicles SET veh_damage = ? WHERE user_id = ? AND veh_plate = ?',
        { json.encode(damageData), user_id, plate })
end

vRPSax.getPlayersCars = function(garageID)
    local source <const> = source
    local garageData <const> = getGarageData(garageID)
    local user_id <const> = vRP.getUserId { source }
    debug("garageID: ", garageID)
    debug("Garage Data: ", garageData)
    if not garageData then return end

    local p = promise:new()
    local playerCars = {}

    exports.oxmysql:execute(
    'SELECT vehicle, veh_type, veh_name, veh_plate, fuel, engine, status, veh_damage FROM vrp_user_vehicles WHERE user_id = ? AND garage = ?',
        { user_id, garageData.id }, function(rows)
        if #rows > 0 then
            if not playerCars[user_id] then
                playerCars[user_id] = {}
            end

            for i = 1, #rows do
                local status = rows[i].status

                if status == "Parcat" then
                    if outvehs[user_id] then
                        for _, v in pairs(outvehs[user_id]) do
                            if v == rows[i].veh_plate then
                                status = "Afara"
                                break
                            end
                        end
                    end
                end

                table.insert(playerCars[user_id], {
                    model = rows[i].vehicle,
                    veh_type = rows[i].veh_type or "Unknown",
                    name = rows[i].veh_name or "Unknown",
                    plate = rows[i].veh_plate or "Unknown Plate",
                    fuel = round(rows[i].fuel) or 60,
                    engineHealth = round((rows[i].engine / 10)) or 80,
                    status = status,
                    damageData = json.decode(rows[i].veh_damage) or {}
                })
            end

            p:resolve(playerCars[user_id])
        else
            p:resolve(false)
        end
    end)

    local result = Citizen.Await(p)

    debug("playerCars[user_id]: ", result)
    return result
end

AddEventHandler("playerDropped", function(reason)
    local player <const> = source
    local user_id <const> = vRP.getUserId { player }

    if outvehs[user_id] then
        for i = 1, #outvehs[user_id] do
            exports.oxmysql:execute('UPDATE vrp_user_vehicles SET status = ? WHERE veh_plate = ? AND user_id = ?',
                { "Afara", outvehs[user_id][i], user_id }, function(affectedRows)
                if #affectedRows > 0 then
                    debug("Masina cu nr de inmatriculare" ..
                    outvehs[user_id][i] .. " a fost salvata ca fiind afara! (user_id: " .. user_id .. ")")
                end
            end)
        end
    end
end)

RegisterCommand('creategarage', function(source)
    local user_id <const> = vRP.getUserId { source }

    if not vRP.isUserFondator { user_id } then
        vRPclient.notify(source, { "Nu ai acces la aceasta comanda!", "error" })
        return
    end

    vRP.prompt({source, "Nume Garaj", "Garaj Public", function(player, garageName)
        if garageName then
            local coords = GetEntityCoords(GetPlayerPed(player))
            local heading = GetEntityHeading(GetPlayerPed(player))

            local coordsToInsert = vec4(coords.x, coords.y, coords.z, heading)

            exports.oxmysql:execute('INSERT INTO ax_garages (name, coords) VALUES (@name, @coords)', {
                name = garageName,
                coords = json.encode(coordsToInsert)
            }, function(id)
                if id then
                    table.insert(garages, {
                        id = id,
                        coords = coords,
                        heading = heading,
                        name = garageName
                    })
                    vRPCax.refreshGarageData(-1, { garages })
                    vRPclient.notify(player, { "Garajul a fost creat cu succes!", "success" })
                else
                    vRPclient.notify(player, { "A aparut o eroare la crearea garajului!", "error" })
                end
            end)
        end
    end})
end)

RegisterCommand('removegarage', function(source)
    local user_id <const> = vRP.getUserId { source }

    if not vRP.isUserFondator { user_id } then
        vRPclient.notify(source, { "Nu ai acces la aceasta comanda!", "error" })
        return
    end

    local pcoords = GetEntityCoords(GetPlayerPed(source))

    for i, v in pairs(garages) do
        local dist = #(pcoords - v.coords)

        if dist < 5.0 then
            exports.oxmysql:execute('DELETE FROM ax_garages WHERE id = ?', { v.id }, function(affectedRows)
                if affectedRows > 0 then
                    table.remove(garages, i)
                    vRPCax.refreshGarageData(-1, { garages })
                    vRPclient.notify(source, { "Garajul a fost sters cu succes!", "success" })
                else
                    vRPclient.notify(source, { "A aparut o eroare la stergerea garajului!", "error" })
                end
            end)
        end
    end
end)

local function extractNumber(str)
    local numberStr = str:match(':%s*(%-?%d+%.?%d*)')
    local number = tonumber(numberStr)

    return number
end

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end

    local p = promise:new()

    exports.oxmysql:execute('SELECT * FROM ax_garages', {}, function(rows)
        if #rows > 0 then
            for i = 1, #rows do
                local x, y, z, h = string.match(rows[i].coords, "([^,]+),([^,]+),([^,]+),([^,]+)")

                table.insert(garages, {
                    id = rows[i].id,
                    coords = extractNumber(x),
                    extractNumber(y),
                    extractNumber(z),
                    heading = h,
                    name = rows[i].name
                })
            end

            p:resolve(true)
        end
    end)

    Citizen.Await(p)
end)

    Citizen.Await(p)
end)
