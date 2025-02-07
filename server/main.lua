local INSERT_ITEMS_QUERY <const> = [[
    INSERT INTO items (name, label, weight) VALUES
    ('%s', '%s', 0.0)
    ON DUPLICATE KEY UPDATE label=VALUES(label)
]]

local NOTIFICATIONS = {
    NOT_OWNER = "~r~Vous n'êtes pas le propriétaire de ce printer.",
    TOO_FAR = "~r~Vous êtes trop loin du printer.",
    PRINTER_FULL = "~g~Votre printer n°%s est plein.",
    BATTERY_EMPTY = "~r~Votre printer n°%s n'a plus de batterie.",
    BATTERY_LOW = "~r~Votre printer n°%s a une batterie très faible (10%% ou moins).",
    BATTERY_FULL = "~g~La batterie du printer est déjà pleine.",
    BATTERY_RECHARGED = "~g~Vous avez rechargé la batterie du printer pour 500 $.",
    PRINTER_NOT_EXIST = "~r~Le printer n'existe plus.",
    MONEY_TAKEN = "Vous avez pris ~g~%s$~s~ dans le printer.",
    PRINTER_PLACED = "~g~Vous avez récupéré votre printer.",
    NO_MONEY = "~r~Il n'y a pas d'argent dans le printer.",
    PRINTER_INVALID = "~r~Ce printer n'existe pas.",
    PRINTER_NOT_PLACING = "~r~Vous n'êtes pas en train de poser un printer.",
    PAPER_FULL = "~r~Le printer est déjà plein de papier.",
    PAPER_ADDED = "~g~Vous avez ajouté du papier pour 500 $.",
    PAPER_LOW = "~r~Le printer est à court de papier.",
    INK_FULL = "~r~Le printer est déjà plein d'encre.",
    INK_LOW = "~r~Le printer est à court d'encre.",
    INK_ADDED = "~g~Vous avez ajouté de l'encre pour 500 $.",
}

EKALI.Printer.PlayerInPrinterPosing = EKALI.Printer.PlayerInPrinterPosing or {}
EKALI.Printer.PrinterPlaced = EKALI.Printer.PrinterPlaced or {}
EKALI.Printer.PrinterData = EKALI.Printer.PrinterData or {}

local function notifyPlayer(xPlayer, message)
    if xPlayer then
        xPlayer.showNotification(message)
    end
end

local function validateOwnership(playerId, entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local printerSyncData = EKALI.Printer.PrinterData[netId]
    return printerSyncData.printerOwner == playerId
end

local function validateDistance(xPlayer, distance)
    if distance > 3.0 then
        notifyPlayer(xPlayer, NOTIFICATIONS.TOO_FAR)
        return false
    end
    return true
end

local function handlePrinterPlacement(playerId, printerName, coords)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local printerData = EKALI.Printer.Items[printerName]

    if not printerData then
        notifyPlayer(xPlayer, NOTIFICATIONS.PRINTER_INVALID)
        return false
    end

    xPlayer.removeInventoryItem(printerName, 1)
    EKALI.Printer.PlayerInPrinterPosing[playerId] = nil

    local printerObject = CreateObjectNoOffset(printerData.model, coords, true, false, false)
    while not DoesEntityExist(printerObject) do
        Wait(0)
    end

    local netId = NetworkGetNetworkIdFromEntity(printerObject)

    if EKALI?.Printer?.PrinterPlaced[source] then
        local tbl = EKALI.Printer.PrinterPlaced[source]
        tbl[#tbl + 1] = netId
    else
        EKALI.Printer.PrinterPlaced[source] = { netId }
    end

    EKALI.Printer.PrinterData[netId] = {
        printerOwner = playerId,
        printerId = netId,
        moneyInPrinter = 0,
        powerLevel = 100,
        paperLevel = 0,
        inkLevel = 0,
        printerName = printerName
    }

    return printerObject
end

local function updateData(player, netId)
    local printerSyncData = EKALI.Printer.PrinterData[netId]
    TriggerLatentClientEvent("ekali:printer:SyncData", player, 1000, netId, printerSyncData)
end

local function updatePrinterState(printerObject, xPlayer, printerData)
    CreateThread(function()

        updateData(xPlayer.source, NetworkGetNetworkIdFromEntity(printerObject))

        while DoesEntityExist(printerObject) do
            Wait(printerData.interval * 1000)

            if not DoesEntityExist(printerObject) then break end
            local printerSyncData = EKALI.Printer.PrinterData[NetworkGetNetworkIdFromEntity(printerObject)]

            local currentMoney = printerSyncData.moneyInPrinter or 0
            local battery = printerSyncData.powerLevel or 100
            local currentPaper = printerSyncData.paperLevel or 0
            local currentInk = printerSyncData.inkLevel or 0

            if battery <= 0 or currentMoney >= printerData.capacity or currentPaper <= 0 or currentInk <= 0 then
                while DoesEntityExist(printerObject) and (battery <= 0 or currentMoney >= printerData.capacity or currentPaper <= 0 or currentInk <= 0) do
                    Wait(1000)
                    currentMoney = printerSyncData.moneyInPrinter or 0
                    battery = printerSyncData.powerLevel or 100
                    currentPaper = printerSyncData.paperLevel or 0
                    currentInk = printerSyncData.inkLevel or 0
                end
            end

            if not DoesEntityExist(printerObject) then break end

            printerSyncData.moneyInPrinter = currentMoney + printerData.printedAmount
            printerSyncData.powerLevel = battery - printerData.batteryRemove
            printerSyncData.paperLevel = currentPaper - printerData.paperRemove
            printerSyncData.inkLevel = currentInk - printerData.inkRemove

            currentMoney = printerSyncData.moneyInPrinter or 0
            battery = printerSyncData.powerLevel or 0
            currentPaper = printerSyncData.paperLevel or 0
            currentInk = printerSyncData.inkLevel or 0

            if currentMoney >= printerData.capacity then
                notifyPlayer(xPlayer, NOTIFICATIONS.PRINTER_FULL:format(printerSyncData.printerId))
            end

            if currentInk <= 0 then
                notifyPlayer(xPlayer, NOTIFICATIONS.INK_LOW)
            end

            if currentPaper <= 0 then
                notifyPlayer(xPlayer, NOTIFICATIONS.PAPER_LOW)
            end

            if battery <= 0 then
                notifyPlayer(xPlayer, NOTIFICATIONS.BATTERY_EMPTY:format(printerSyncData.printerId))
            elseif battery <= 10.0 then
                notifyPlayer(xPlayer, NOTIFICATIONS.BATTERY_LOW:format(printerSyncData.printerId))
            end

            updateData(xPlayer.source, NetworkGetNetworkIdFromEntity(printerObject))
        end
    end)
end

for k, v in pairs(EKALI.Printer.Items) do
    ESX.RegisterUsableItem(k, function(playerId)
        local xPlayer = ESX.GetPlayerFromId(playerId)
        TriggerClientEvent('ekali:printer:UsePrinter', playerId, k)
        EKALI.Printer.PlayerInPrinterPosing[playerId] = k
    end)

    if EKALI?.Printer?.InsertDatabase then
        MySQL.Async.execute(INSERT_ITEMS_QUERY:format(k, v.label), {}, function(rowsChanged)
            if rowsChanged > 0 then
                print(('Inserted printer item \'^2%s^7\' into the database'):format(k))
            end
        end)
    end
end

RegisterNetEvent('ekali:printer:addPaper')
AddEventHandler('ekali:printer:addPaper', function(data)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)

    if not validateDistance(xPlayer, data.distance) then return end

    local entity = NetworkGetEntityFromNetworkId(data.entity)
    local printerSyncData = EKALI.Printer.PrinterData[data.entity]

    if not validateOwnership(playerId, entity) then
        notifyPlayer(xPlayer, NOTIFICATIONS.NOT_OWNER)
        return
    end

    local paper = printerSyncData.paperLevel
    if paper >= 100 then
        notifyPlayer(xPlayer, NOTIFICATIONS.PAPER_FULL)
        return
    end

    local paperLevel = paper + 20

    printerSyncData.paperLevel = paperLevel
    xPlayer.removeMoney(500)
    notifyPlayer(xPlayer, NOTIFICATIONS.PAPER_ADDED)
end)

RegisterNetEvent('ekali:printer:addInk')
AddEventHandler('ekali:printer:addInk', function(data)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)

    if not validateDistance(xPlayer, data.distance) then return end

    local entity = NetworkGetEntityFromNetworkId(data.entity)
    local printerSyncData = EKALI.Printer.PrinterData[data.entity]

    if not validateOwnership(playerId, entity) then
        notifyPlayer(xPlayer, NOTIFICATIONS.NOT_OWNER)
        return
    end

    local ink = printerSyncData.inkLevel
    if ink >= 500 then
        notifyPlayer(xPlayer, NOTIFICATIONS.INK_FULL)
        return
    end

    local inkLevel = ink + 20

    printerSyncData.inkLevel = inkLevel
    xPlayer.removeMoney(500)
    notifyPlayer(xPlayer, NOTIFICATIONS.INK_ADDED)
end)

RegisterNetEvent('ekali:printer:CancelPrinter')
AddEventHandler('ekali:printer:CancelPrinter', function()
    local playerId = source
    local printerName = EKALI.Printer.PlayerInPrinterPosing[playerId]

    if printerName then
        EKALI.Printer.PlayerInPrinterPosing[playerId] = nil
        print(('Player %s has cancelled the printer %s placement'):format(playerId, printerName))
    end
end)

RegisterNetEvent('ekali:printer:PlacePrinter')
AddEventHandler('ekali:printer:PlacePrinter', function(coords)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local printerName = EKALI.Printer.PlayerInPrinterPosing[playerId]

    if not printerName then
        notifyPlayer(xPlayer, NOTIFICATIONS.PRINTER_NOT_PLACING)
        return
    end

    EKALI.Printer.PlayerInPrinterPosing[playerId] = nil

    local printerObject = handlePrinterPlacement(playerId, printerName, coords)
    if printerObject then
        updatePrinterState(printerObject, xPlayer, EKALI.Printer.Items[printerName])
    end
end)

RegisterNetEvent("ekali:printer:takeMoneyOnPrinter")
AddEventHandler("ekali:printer:takeMoneyOnPrinter", function(data)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)

    if not validateDistance(xPlayer, data.distance) then return end

    local entity = NetworkGetEntityFromNetworkId(data.entity)
    local printerSyncData = EKALI.Printer.PrinterData[data.entity]

    if not validateOwnership(playerId, entity) then
        notifyPlayer(xPlayer, NOTIFICATIONS.NOT_OWNER)
        return
    end

    local moneyInPrinter = printerSyncData.moneyInPrinter
    if moneyInPrinter <= 0 then
        notifyPlayer(xPlayer, NOTIFICATIONS.NO_MONEY)
        return
    end

    xPlayer.addMoney(moneyInPrinter)
    printerSyncData.moneyInPrinter = 0
    notifyPlayer(xPlayer, NOTIFICATIONS.MONEY_TAKEN:format(ESX.Math.GroupDigits(moneyInPrinter)))
end)

RegisterNetEvent("ekali:printer:fillBattery")
AddEventHandler("ekali:printer:fillBattery", function(data)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)

    if not validateDistance(xPlayer, data.distance) then return end

    local entity = NetworkGetEntityFromNetworkId(data.entity)
    local printerSyncData = EKALI.Printer.PrinterData[data.entity]

    if not validateOwnership(playerId, entity) then
        notifyPlayer(xPlayer, NOTIFICATIONS.NOT_OWNER)
        return
    end

    local battery = printerSyncData.powerLevel
    if battery >= 100 then
        notifyPlayer(xPlayer, NOTIFICATIONS.BATTERY_FULL)
        return
    end

    printerSyncData.powerLevel = 101
    xPlayer.removeMoney(500)
    notifyPlayer(xPlayer, NOTIFICATIONS.BATTERY_RECHARGED)
end)

RegisterNetEvent("ekali:printer:TakePrinter")
AddEventHandler("ekali:printer:TakePrinter", function(data)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)

    if not validateDistance(xPlayer, data.distance) then return end

    local entity = NetworkGetEntityFromNetworkId(data.entity)
    local printerSyncData = EKALI.Printer.PrinterData[data.entity]

    if not validateOwnership(playerId, entity) then
        notifyPlayer(xPlayer, NOTIFICATIONS.NOT_OWNER)
        return
    end

    for k, v in pairs(EKALI.Printer.PrinterPlaced[playerId]) do
        if v == data.entity then
            table.remove(EKALI.Printer.PrinterPlaced[playerId], k)
            break
        end
    end

    local moneyInPrinter = printerSyncData.moneyInPrinter
    if moneyInPrinter > 0 then
        xPlayer.addMoney(moneyInPrinter)
        printerSyncData.moneyInPrinter = 0
        notifyPlayer(xPlayer, NOTIFICATIONS.MONEY_TAKEN:format(ESX.Math.GroupDigits(moneyInPrinter)))
    end

    DeleteEntity(entity)
    xPlayer.addInventoryItem(printerSyncData.printerName, 1)
    notifyPlayer(xPlayer, NOTIFICATIONS.PRINTER_PLACED)
end)

AddEventHandler("playerDropped", function()
    local playerId = source
    local printerName = EKALI.Printer.PlayerInPrinterPosing[playerId]

    if printerName then
        EKALI.Printer.PlayerInPrinterPosing[playerId] = nil
    end

    if not EKALI.Printer.PrinterPlaced[playerId] then return end

    local printerIds = EKALI.Printer.PrinterPlaced[playerId] or {}

    for k, printerId in ipairs(printerIds) do
        local entity = NetworkGetEntityFromNetworkId(printerId)
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
        table.remove(printerIds, k)
    end

    EKALI.Printer.PrinterPlaced[playerId] = nil
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for playerId, printerIds in pairs(EKALI.Printer.PrinterPlaced) do
            for k, printerId in ipairs(printerIds) do
                local entity = NetworkGetEntityFromNetworkId(printerId)
                if DoesEntityExist(entity) then
                    DeleteEntity(entity)
                end
                table.remove(printerIds, k)
            end
        end
    end
end)