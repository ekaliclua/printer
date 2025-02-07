local dui_url = 'nui://ekali/web/index.html'
local dui_width, dui_height = 1920, 1080
local printerDUIs = {}
local printerSyncData = {}

local function createDUI(entity)
    local dui_object = CreateDui(dui_url, dui_width, dui_height)
    local dui_handle = GetDuiHandle(dui_object)
    local txd = CreateRuntimeTxd("dui_texture_txd_" .. entity)
    CreateRuntimeTextureFromDuiHandle(txd, "dui_texture_" .. entity, dui_handle)

    printerDUIs[entity] = {
        dui_object = dui_object,
        dui_handle = dui_handle,
        txd = txd,
        texture_name = "dui_texture_" .. entity,
    }
end

local function deleteDUI(entity)
    local duiData = printerDUIs[entity]
    if duiData then
        DestroyDui(duiData.dui_object)
        printerDUIs[entity] = nil
    end
end

RegisterNetEvent('ekali:printer:UsePrinter')
AddEventHandler('ekali:printer:UsePrinter', function(printerName)
    local printerData = EKALI.Printer.Items[printerName]
    if not printerData then
        ESX.ShowNotification('Ce printer n\'existe pas.')
        return
    end

    local model = printerData.model
    local playerPed = PlayerPedId()

    CreateThread(function()
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(0)
        end

        local printer = CreateObject(model, GetEntityCoords(playerPed), false, false, false)
        SetEntityAlpha(printer, 200, false)

        SetEntityDrawOutlineShader(1)
        SetEntityDrawOutlineColor(0, 255, 0, 255)
        SetEntityDrawOutline(printer, true)

        local placing = true
        while placing do
            Wait(0)
            local playerCoords = GetEntityCoords(playerPed)
            local printerCoords = playerCoords + GetEntityForwardVector(playerPed) * 1.0

            SetEntityCoords(printer, printerCoords)
            SetEntityRotation(printer, GetEntityRotation(playerPed))
            PlaceObjectOnGroundProperly(printer)

            UI.Draw3DTextNoDownsize(printerCoords.x, printerCoords.y, printerCoords.z,
                    "[~g~E~s~] pour poser le printer\n[~r~X~s~] pour annuler la pose du printer", 13, 0.6, 0.6, 255)

            if IsControlJustPressed(0, 38) then
                placing = false
                DeleteEntity(printer)
                TriggerServerEvent('ekali:printer:PlacePrinter', printerCoords)
            elseif IsControlJustPressed(0, 73) then
                placing = false
                DeleteEntity(printer)
                ESX.ShowNotification('~r~Vous avez annulé l\'utilisation du printer.')
                TriggerServerEvent('ekali:printer:CancelPrinter')
            end
        end
    end)
end)

--CreateThread(function()
--    while true do
--        Wait(1000)
--
--        local playerCoords = GetEntityCoords(PlayerPedId())
--        local entities = ESX.Game.GetObjects()
--
--        for _, entity in ipairs(entities) do
--            local entCoords = GetEntityCoords(entity)
--            local dist = #(playerCoords - entCoords)
--
--            if dist < 100.0 then
--                if not NetworkGetNetworkIdFromEntity(entity) then
--                    goto continue
--                end
--
--                local entState = printerSyncData[NetworkGetNetworkIdFromEntity(entity)]
--
--                if not entState then
--                    goto continue
--                end
--
--                if entState.printerOwner == cache.serverId then
--                    if not printerDUIs[entity] then
--                        createDUI(entity)
--                    end
--                else
--                    deleteDUI(entity)
--                end
--
--                ::continue::
--            end
--        end
--    end
--end)

CreateThread(function()
    while true do
        Wait(0)

        local playerCoords = GetEntityCoords(PlayerPedId())

        for entity, duiData in pairs(printerDUIs) do
            if DoesEntityExist(entity) then
                local entState = printerSyncData[NetworkGetNetworkIdFromEntity(entity)]
                local entCoords = GetEntityCoords(entity)
                local dist = #(playerCoords - entCoords)

                if dist < 3.0 then
                    SendDuiMessage(duiData.dui_object, json.encode({
                        type = 'UPDATE_PRINTER_DATA',
                        data = {
                            printerId = entState.printerId,
                            battery = entState.powerLevel,
                            money = entState.moneyInPrinter,
                            paper = entState.paperLevel,
                            ink = entState.inkLevel
                        }
                    }))

                    local ret, x, y = GetScreenCoordFromWorldCoord(entCoords.x, entCoords.y, entCoords.z + 1.0)
                    if ret then
                        DrawSprite("dui_texture_txd_" .. entity, duiData.texture_name, x, y, 0.75, 0.75, 0.0, 255, 255, 255, 255)
                    end
                end
            else
                deleteDUI(entity)
            end
        end
    end
end)

--AddStateBagChangeHandler("printerOwner", nil, function(bagName, key, value)
--    if key == "printerOwner" then
--        local obj = GetEntityFromStateBagName(bagName)
--        local netId = NetworkGetNetworkIdFromEntity(obj)
--
--        PlaceObjectOnGroundProperly(obj)
--
--        if value == cache.serverId then
--            exports.ox_target:addEntity(netId, {
--                {
--                    label = "Récupérer le printer",
--                    icon = "fas fa-print",
--                    serverEvent = 'ekali:printer:TakePrinter',
--                    distance = 3.0
--                },
--                {
--                    label = "Récupérer l'argent",
--                    icon = "fas fa-money-bill-wave",
--                    serverEvent = 'ekali:printer:takeMoneyOnPrinter',
--                    distance = 3.0,
--                    canInteract = function(ent)
--                        return Entity(ent).state.moneyInPrinter > 0
--                    end
--                },
--                {
--                    label = "Ajouter 20 feuilles",
--                    icon = "fas fa-file",
--                    serverEvent = 'ekali:printer:addPaper',
--                    distance = 3.0,
--                    canInteract = function(ent)
--                        return Entity(ent).state.paperLevel < 100
--                    end
--                },
--                {
--                    label = "Ajouter 20 ml d'encre",
--                    icon = "fas fa-tint",
--                    serverEvent = 'ekali:printer:addInk',
--                    distance = 3.0,
--                    canInteract = function(ent)
--                        return Entity(ent).state.inkLevel < 500
--                    end
--                },
--                {
--                    label = "Remplir la batterie (500$)",
--                    icon = "fas fa-battery-full",
--                    serverEvent = 'ekali:printer:fillBattery',
--                    distance = 3.0,
--                    canInteract = function(ent)
--                        return Entity(ent).state.powerLevel <= 0.0
--                    end
--                }
--            })
--        end
--    end
--end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, duiData in pairs(printerDUIs) do
            if IsDuiAvailable(duiData.dui_object) then
                DestroyDui(duiData.dui_object)
            end
        end
        printerDUIs = {}
    end
end)

RegisterNetEvent('ekali:printer:SyncData')
AddEventHandler('ekali:printer:SyncData', function(netId, data)
    local attempt = 0
    while not NetworkDoesNetworkIdExist(netId) and attempt <= 5 do
        Wait(100)
        attempt = attempt + 1
    end
    printerSyncData[netId] = data
    if not printerDUIs[NetworkGetEntityFromNetworkId(netId)] then
        createDUI(NetworkGetEntityFromNetworkId(netId))
        local obj = NetworkGetEntityFromNetworkId(netId)

        PlaceObjectOnGroundProperly(obj)

        exports.ox_target:addEntity(netId, {
            {
                label = "Récupérer le printer",
                icon = "fas fa-print",
                serverEvent = 'ekali:printer:TakePrinter',
                distance = 3.0
            },
            {
                label = "Récupérer l'argent",
                icon = "fas fa-money-bill-wave",
                serverEvent = 'ekali:printer:takeMoneyOnPrinter',
                distance = 3.0,
                canInteract = function(ent)
                    local syncData = printerSyncData[NetworkGetNetworkIdFromEntity(ent)]
                    return syncData.moneyInPrinter > 0
                end
            },
            {
                label = "Ajouter 20 feuilles",
                icon = "fas fa-file",
                serverEvent = 'ekali:printer:addPaper',
                distance = 3.0,
                canInteract = function(ent)
                    local syncData = printerSyncData[NetworkGetNetworkIdFromEntity(ent)]
                    return syncData.paperLevel < 100
                end
            },
            {
                label = "Ajouter 20 ml d'encre",
                icon = "fas fa-tint",
                serverEvent = 'ekali:printer:addInk',
                distance = 3.0,
                canInteract = function(ent)
                    local syncData = printerSyncData[NetworkGetNetworkIdFromEntity(ent)]
                    return syncData.inkLevel < 500
                end
            },
            {
                label = "Remplir la batterie (500$)",
                icon = "fas fa-battery-full",
                serverEvent = 'ekali:printer:fillBattery',
                distance = 3.0,
                canInteract = function(ent)
                    local syncData = printerSyncData[NetworkGetNetworkIdFromEntity(ent)]
                    return syncData.powerLevel <= 0.0
                end
            }
        })
    end
end)