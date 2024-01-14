local config = require 'config.server'
local garageConfig = require '@qbx_garages.config.shared'
local QBPhone = {}
local AppAlerts = {}
local MentionedTweets = {}
local Hashtags = {}
local Calls = {}
local Adverts = {}
local GeneratedPlates = {}
local WebHook = ''
local bannedCharacters = {'%','$',';'}
local TWData = {}
local VEHICLES = exports.qbx_core:GetVehiclesByName()

local function getOnlineStatus(number)
    return exports.qbx_core:GetPlayerByPhone(number) or false
end

local function generateMailId()
    return math.random(111111, 999999)
end

local function escape_sqli(source)
    local replacements = {
        ['"'] = '\\"',
        ["'"] = "\\'"
    }
    return source:gsub("['\"]", replacements)
end

function QBPhone.AddMentionedTweet(citizenid, TweetData)
    if MentionedTweets[citizenid] == nil then
        MentionedTweets[citizenid] = {}
    end
    MentionedTweets[citizenid][#MentionedTweets[citizenid]+1] = TweetData
end

function QBPhone.SetPhoneAlerts(citizenid, app, alerts)
    if citizenid == nil or app == nil then return end

    AppAlerts[citizenid] = AppAlerts[citizenid] or {}
    AppAlerts[citizenid][app] = (AppAlerts[citizenid][app] or 0) + (alerts or 1)
end

local function splitStringToArray(string)
    local retval = {}
    for i in string.gmatch(string, '%S+') do
        retval[#retval + 1] = i
    end
    return retval
end

local function generateOwnerName()
    local names = {
        [1] = { name = 'Bailey Sykes',          citizenid = 'DSH091G93' },
        [2] = { name = 'Aroush Goodwin',        citizenid = 'AVH09M193' },
        [3] = { name = 'Tom Warren',            citizenid = 'DVH091T93' },
        [4] = { name = 'Abdallah Friedman',     citizenid = 'GZP091G93' },
        [5] = { name = 'Lavinia Powell',        citizenid = 'DRH09Z193' },
        [6] = { name = 'Andrew Delarosa',       citizenid = 'KGV091J93' },
        [7] = { name = 'Skye Cardenas',         citizenid = 'ODF09S193' },
        [8] = { name = 'Amelia-Mae Walter',     citizenid = 'KSD0919H3' },
        [9] = { name = 'Elisha Cote',           citizenid = 'NDX091D93' },
        [10] = { name = 'Janice Rhodes',        citizenid = 'ZAL0919X3' },
        [11] = { name = 'Justin Harris',        citizenid = 'ZAK09D193' },
        [12] = { name = 'Montel Graves',        citizenid = 'POL09F193' },
        [13] = { name = 'Benjamin Zavala',      citizenid = 'TEW0J9193' },
        [14] = { name = 'Mia Willis',           citizenid = 'YOO09H193' },
        [15] = { name = 'Jacques Schmitt',      citizenid = 'QBC091H93' },
        [16] = { name = 'Mert Simmonds',        citizenid = 'YDN091H93' },
        [17] = { name = 'Rickie Browne',        citizenid = 'PJD09D193' },
        [18] = { name = 'Deacon Stanley',       citizenid = 'RND091D93' },
        [19] = { name = 'Daisy Fraser',         citizenid = 'QWE091A93' },
        [20] = { name = 'Kitty Walters',        citizenid = 'KJH0919M3' },
        [21] = { name = 'Jareth Fernandez',     citizenid = 'ZXC09D193' },
        [22] = { name = 'Meredith Calhoun',     citizenid = 'XYZ0919C3' },
        [23] = { name = 'Teagan Mckay',         citizenid = 'ZYX0919F3' },
        [24] = { name = 'Kurt Bain',            citizenid = 'IOP091O93' },
        [25] = { name = 'Burt Kain',            citizenid = 'PIO091R93' },
        [26] = { name = 'Joanna Huff',          citizenid = 'LEK091X93' },
        [27] = { name = 'Carrie-Ann Pineda',    citizenid = 'ALG091Y93' },
        [28] = { name = 'Gracie-Mai Mcghee',    citizenid = 'YUR09E193' },
        [29] = { name = 'Robyn Boone',          citizenid = 'SOM091W93' },
        [30] = { name = 'Aliya William',        citizenid = 'KAS009193' },
        [31] = { name = 'Rohit West',           citizenid = 'SOK091093' },
        [32] = { name = 'Skylar Archer',        citizenid = 'LOK091093' },
        [33] = { name = 'Jake Kumar',           citizenid = 'AKA420609' },
    }

    return names[math.random(1, #names)]
end

lib.callback.register('qb-phone:server:GetCallState', function(contactData)
    local target = exports.qbx_core:GetPlayerByPhone(contactData.number)
    if target == nil then
        return false, false
    end

    local citizenId = target.PlayerData.citizenid
    local call = Calls[citizenId]

    if call and call.inCall then
        return false, true
    end

    return true, true
end)

lib.callback.register('qb-phone:server:GetPhoneData', function(source)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if Player then
        local PhoneData = {
            Applications = {},
            PlayerContacts = {},
            MentionedTweets = {},
            Chats = {},
            Hashtags = {},
            Invoices = {},
            Garage = {},
            Mails = {},
            Adverts = {},
            CryptoTransactions = {},
            Tweets = {},
            Images = {},
            InstalledApps = Player.PlayerData.metadata.phonedata.InstalledApps
        }
        PhoneData.Adverts = Adverts

        local result = MySQL.query.await('SELECT * FROM player_contacts WHERE citizenid = ? ORDER BY name ASC', {Player.PlayerData.citizenid})
        if result[1] then
            for _, v in pairs(result) do
                v.status = getOnlineStatus(v.number)
            end

            PhoneData.PlayerContacts = result
        end

        local invoices = MySQL.query.await('SELECT * FROM phone_invoices WHERE citizenid = ?', {Player.PlayerData.citizenid})
        if invoices[1] then
            for _, v in pairs(invoices) do
                local Ply = exports.qbx_core:GetPlayerByCitizenId(v.sender)
                if Ply then
                    v.number = Ply.PlayerData.charinfo.phone
                else
                    local res = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', {v.sender})
                    if res[1] then
                        res[1].charinfo = json.decode(res[1].charinfo)
                        v.number = res[1].charinfo.phone
                    else
                        v.number = nil
                    end
                end
            end
            PhoneData.Invoices = invoices
        end

        local garageresult = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', {Player.PlayerData.citizenid})
        if garageresult[1] then
            for _, v in pairs(garageresult) do
                local vehicleModel = v.vehicle
                if VEHICLES[vehicleModel]and garageConfig.garages[v.garage]then
                    v.garage = garageConfig.garages[v.garage].label
                    v.vehicle = VEHICLES[vehicleModel].name
                    v.brand = VEHICLES[vehicleModel].brand
                end

            end
            PhoneData.Garage = garageresult
        end

        local messages = MySQL.query.await('SELECT * FROM phone_messages WHERE citizenid = ?', {Player.PlayerData.citizenid})
        if messages and next(messages) then
            PhoneData.Chats = messages
        end

        PhoneData.Applications = AppAlerts[Player.PlayerData.citizenid] or PhoneData.Applications

        PhoneData.MentionedTweets = MentionedTweets[Player.PlayerData.citizenid] or PhoneData.MentionedTweets

        if Hashtags and next(Hashtags) then
            PhoneData.Hashtags = Hashtags
        end

        local tweets = MySQL.query.await('SELECT * FROM phone_tweets WHERE `date` > NOW() - INTERVAL ? hour', {config.tweetDuration})

        if tweets and next(tweets) then
            PhoneData.Tweets = tweets
            TWData = tweets
        end

        local mails = MySQL.query.await('SELECT * FROM player_mails WHERE citizenid = ? ORDER BY `date` ASC', {Player.PlayerData.citizenid})
        if mails[1] then
            for k, _ in pairs(mails) do
                if mails[k].button then
                    mails[k].button = json.decode(mails[k].button)
                end
            end
            PhoneData.Mails = mails
        end

        local transactions = MySQL.query.await('SELECT * FROM crypto_transactions WHERE citizenid = ? ORDER BY `date` ASC', {Player.PlayerData.citizenid})
        if transactions[1] then
            for _, v in pairs(transactions) do
                PhoneData.CryptoTransactions[#PhoneData.CryptoTransactions+1] = {
                    TransactionTitle = v.title,
                    TransactionMessage = v.message
                }
            end
        end
        local images = MySQL.query.await('SELECT * FROM phone_gallery WHERE citizenid = ? ORDER BY `date` DESC',{Player.PlayerData.citizenid})
        if images and next(images) then
            PhoneData.Images = images
        end
        return PhoneData
    end
end)

lib.callback.register('qb-phone:server:PayInvoice', function(source, society, amount, invoiceId, sendercitizenid)
    local Invoices = {}
    local player = exports.qbx_core:GetPlayer(source)
    local sender = exports.qbx_core:GetPlayerByCitizenId(sendercitizenid)
    local invoiceMailData = {}
    if sender and config.billingCommissions[society] then
        local commission = math.round(amount * config.billingCommissions[society])
        sender.Functions.AddMoney('bank', commission)
        invoiceMailData = {
            sender = 'Billing Department',
            subject = 'Commission Received',
            message = string.format('You received a commission check of $%s when %s %s paid a bill of $%s.', commission, player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname, amount)
        }
    elseif not sender and config.billingCommissions[society] then
        invoiceMailData = {
            sender = 'Billing Department',
            subject = 'Bill Paid',
            message = string.format('%s %s paid a bill of $%s', player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname, amount)
        }
    end
    player.Functions.RemoveMoney('bank', amount, 'paid-invoice')
    TriggerEvent('qb-phone:server:sendNewMailToOffline', sendercitizenid, invoiceMailData)
	exports.qbx_management:AddMoney(society, amount)
    MySQL.query('DELETE FROM phone_invoices WHERE id = ?', {invoiceId})
    local invoices = MySQL.query.await('SELECT * FROM phone_invoices WHERE citizenid = ?', {player.PlayerData.citizenid})
    Invoices = invoices[1] or Invoices
    return true, Invoices
end)

lib.callback.register('qb-phone:server:DeclineInvoice', function(source, invoiceId)
    local player = exports.qbx_core:GetPlayer(source)
    MySQL.query('DELETE FROM phone_invoices WHERE id = ?', {invoiceId})
    local invoices = MySQL.query.await('SELECT * FROM phone_invoices WHERE citizenid = ?', {player.PlayerData.citizenid})
    return true, invoices
end)

lib.callback.register('qb-phone:server:GetContactPictures', function(chats)
    for _, v in pairs(chats) do
        local query = '%' .. v.number .. '%'
        local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', {query})
        if result[1] then
            local metaData = json.decode(result[1].metadata)

            v.picture = metaData.phone.profilepicture or 'default'
        end
    end
    SetTimeout(100, function()
        return chats
    end)
end)

lib.callback.register('qb-phone:server:GetContactPicture', function(chat)
    local query = '%' .. chat.number .. '%'
    local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', {query})
    local metaData = json.decode(result[1].metadata)
    chat.picture = metaData.phone.profilepicture or 'default'
    SetTimeout(100, function()
        return chat
    end)
end)

lib.callback.register('qb-phone:server:GetPicture', function(number)
    local query = '%' .. number .. '%'
    local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', {query})
    if not result[1] then return nil end

    local picture = 'default'
    local metaData = json.decode(result[1].metadata)
    picture = metaData.phone.profilepicture or picture
    return picture
end)

lib.callback.register('qb-phone:server:FetchResult', function(search)
    search = escape_sqli(search)
    local searchData = {}
    local apaData = {}
    local query = 'SELECT * FROM `players` WHERE `citizenid` = "' .. search .. '"'
    -- Split on " " and check each var individual
    local searchParameters = splitStringToArray(search)
    -- Construct query dynamicly for individual parm check
    if #searchParameters > 1 then
        query = query .. ' OR `charinfo` LIKE "%' .. searchParameters[1] .. '%"'
        for i = 2, #searchParameters do
            query = query .. ' AND `charinfo` LIKE  "%' .. searchParameters[i] .. '%"'
        end
    else
        query = query .. ' OR `charinfo` LIKE "%' .. search .. '%"'
    end
    local apartmentData = MySQL.query.await('SELECT * FROM apartments', {})
    for k, v in pairs(apartmentData) do
        apaData[v.citizenid] = apartmentData[k]
    end
    local result = MySQL.query.await(query)
    if not result[1] then return nil end

    for _, v in pairs(result) do
        local charinfo = json.decode(v.charinfo)
        local metadata = json.decode(v.metadata)
        local appiePappie = {}
        if apaData[v.citizenid] and next(apaData[v.citizenid]) then
            appiePappie = apaData[v.citizenid]
        end
        searchData[#searchData + 1] = {
            citizenid = v.citizenid,
            firstname = charinfo.firstname,
            lastname = charinfo.lastname,
            birthdate = charinfo.birthdate,
            phone = charinfo.phone,
            nationality = charinfo.nationality,
            gender = charinfo.gender,
            warrant = false,
            driverlicense = metadata.licenses.driver,
            appartmentdata = appiePappie
        }
    end
    return searchData
end)

lib.callback.register('qb-phone:server:GetVehicleSearchResults', function(search)
    search = escape_sqli(search)
    local searchData = {}
    local query = '%' .. search .. '%'
    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate LIKE ? OR citizenid = ?', {query, search})
    if result[1] then
        for k, _ in pairs(result) do
            local player = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', {result[k].citizenid})
            if player[1] then
                local charinfo = json.decode(player[1].charinfo)
                local vehicleInfo = VEHICLES[result[k].vehicle]
                searchData[#searchData + 1] = {
                    plate = result[k].plate,
                    status = true,
                    owner = charinfo.firstname .. ' ' .. charinfo.lastname,
                    citizenid = result[k].citizenid,
                    label = vehicleInfo and vehicleInfo.name or 'Name not found..'
                }
            end
        end
    else
        if GeneratedPlates[search] then
            searchData[#searchData + 1] = {
                plate = GeneratedPlates[search].plate,
                status = GeneratedPlates[search].status,
                owner = GeneratedPlates[search].owner,
                citizenid = GeneratedPlates[search].citizenid,
                label = 'Brand unknown..'
            }
        else
            local ownerInfo = generateOwnerName()
            GeneratedPlates[search] = {
                plate = search,
                status = true,
                owner = ownerInfo.name,
                citizenid = ownerInfo.citizenid
            }
            searchData[#searchData + 1] = {
                plate = search,
                status = true,
                owner = ownerInfo.name,
                citizenid = ownerInfo.citizenid,
                label = 'Brand unknown..'
            }
        end
    end
    return searchData
end)

lib.callback.register('qb-phone:server:GetPicture', function(source, plate)
    local vehicleData

    if not plate then
        exports.qbx_core:Notify(source, 'No Vehicle Nearby', 'error')
        return
    end

    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ?', {plate})
    if result[1] then
        local player = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', {result[1].citizenid})
        local charInfo = json.decode(player[1].charinfo)
        vehicleData = {
            plate = plate,
            status = true,
            owner = charInfo.firstname .. ' ' .. charInfo.lastname,
            citizenid = result[1].citizenid
        }
    elseif GeneratedPlates and GeneratedPlates[plate] then
        vehicleData = GeneratedPlates[plate]
    else
        local ownerInfo = generateOwnerName()
        GeneratedPlates[plate] = {
            plate = plate,
            status = true,
            owner = ownerInfo.name,
            citizenid = ownerInfo.citizenid
        }
        vehicleData = {
            plate = plate,
            status = true,
            owner = ownerInfo.name,
            citizenid = ownerInfo.citizenid
        }
    end
    return vehicleData
end)

lib.callback.register('qb-phone:server:HasPhone', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    local hasPhone = player.Functions.GetItemByName('phone')
    return hasPhone
end)

lib.callback.register('qb-phone:server:CanTransferMoney', function(source, amount, iban)
    -- strip bad characters from bank transfers
    local newAmount = tostring(amount)
    local newIban = tostring(iban)
    for _, v in pairs(bannedCharacters) do
        newAmount = string.gsub(newAmount, '%' .. v, '')
        newIban = string.gsub(newIban, '%' .. v, '')
    end
    iban = newIban
    amount = tonumber(newAmount)

    local player = exports.qbx_core:GetPlayer(source)
    if (player.PlayerData.money.bank - amount) >= 0 then
        local query = '%"account":"' .. iban .. '"%'
        local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', {query})
        if not result[1] then return false end

        local reciever = exports.qbx_core:GetPlayerByCitizenId(result[1].citizenid)
        player.Functions.RemoveMoney('bank', amount)
        if reciever then
            reciever.Functions.AddMoney('bank', amount)
        else
            local recieverMoney = json.decode(result[1].money)
            recieverMoney.bank = (recieverMoney.bank + amount)
            MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?', {json.encode(recieverMoney), result[1].citizenid})
        end
        return true
    end
end)

lib.callback.register('qb-phone:server:GetCurrentLawyers', function()
    local lawyers = {}
    for _, v in pairs(exports.qbx_core:GetQBPlayers()) do
        local player = exports.qbx_core:GetPlayer(v)
        if player then
            if (player.PlayerData.job.name == 'lawyer' or player.PlayerData.job.name == 'realestate' or
                player.PlayerData.job.name == 'mechanic' or player.PlayerData.job.name == 'taxi' or
                player.PlayerData.job.name == 'police' or player.PlayerData.job.name == 'ambulance') and
                player.PlayerData.job.onduty then
                    lawyers[#lawyers + 1] = {
                    name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
                    phone = player.PlayerData.charinfo.phone,
                    typejob = player.PlayerData.job.name
                }
            end
        end
    end
    return lawyers
end)

lib.callback.register('qb-phone:server:GetWebhook', function()
    if WebHook ~= '' then
		return WebHook
	else
		lib.print.info('Set your webhook to ensure that your camera will work!!!!!! Set this on line 10 of the server sided script!!!!!')
		return nil
	end
end)

RegisterNetEvent('qb-phone:server:AddAdvert', function(msg, url)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local citizenId = player.PlayerData.citizenid
    if Adverts[citizenId] then
        Adverts[citizenId].message = msg
        Adverts[citizenId].name = '@' .. player.PlayerData.charinfo.firstname .. '' .. player.PlayerData.charinfo.lastname
        Adverts[citizenId].number = player.PlayerData.charinfo.phone
        Adverts[citizenId].url = url
    else
        Adverts[citizenId] = {
            message = msg,
            name = '@' .. player.PlayerData.charinfo.firstname .. '' .. player.PlayerData.charinfo.lastname,
            number = player.PlayerData.charinfo.phone,
            url = url
        }
    end
    TriggerClientEvent('qb-phone:client:UpdateAdverts', -1, Adverts, '@' .. player.PlayerData.charinfo.firstname .. '' .. player.PlayerData.charinfo.lastname)
end)

RegisterNetEvent('qb-phone:server:DeleteAdvert', function()
    local player = exports.qbx_core:GetPlayer(source)
    local citizenId = player.PlayerData.citizenid
    Adverts[citizenId] = nil
    TriggerClientEvent('qb-phone:client:UpdateAdvertsDel', -1, Adverts)
end)

RegisterNetEvent('qb-phone:server:SetCallState', function(bool)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    Calls[player.PlayerData.citizenid] = Calls[player.PlayerData.citizenid] or {}
    Calls[player.PlayerData.citizenid].inCall = bool
end)

RegisterNetEvent('qb-phone:server:RemoveMail', function(mailId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    MySQL.query('DELETE FROM player_mails WHERE mailid = ? AND citizenid = ?', {mailId, player.PlayerData.citizenid})
    SetTimeout(100, function()
        local mails = MySQL.query.await('SELECT * FROM player_mails WHERE citizenid = ? ORDER BY `date` ASC', {player.PlayerData.citizenid})
        if mails[1] then
            for k, _ in pairs(mails) do
                if mails[k].button then
                    mails[k].button = json.decode(mails[k].button)
                end
            end
        end
        TriggerClientEvent('qb-phone:client:UpdateMails', src, mails)
    end)
end)

RegisterNetEvent('qb-phone:server:sendNewMail', function(mailData)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if mailData.button == nil then
        MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`) VALUES (?, ?, ?, ?, ?, ?)', {player.PlayerData.citizenid, mailData.sender, mailData.subject, mailData.message, generateMailId(), 0})
    else
        MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES (?, ?, ?, ?, ?, ?, ?)', {player.PlayerData.citizenid, mailData.sender, mailData.subject, mailData.message, generateMailId(), 0, json.encode(mailData.button)})
    end
    TriggerClientEvent('qb-phone:client:NewMailNotify', src, mailData)
    SetTimeout(200, function()
        local mails = MySQL.query.await('SELECT * FROM player_mails WHERE citizenid = ? ORDER BY `date` DESC', {player.PlayerData.citizenid})
        if mails[1] then
            for k, _ in pairs(mails) do
                if mails[k].button then
                    mails[k].button = json.decode(mails[k].button)
                end
            end
        end
        TriggerClientEvent('qb-phone:client:UpdateMails', src, mails)
    end)
end)

RegisterNetEvent('qb-phone:server:sendNewMailToOffline', function(citizenid, mailData)
    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if player then
        local src = player.PlayerData.source
        if mailData.button == nil then
            MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`) VALUES (?, ?, ?, ?, ?, ?)', {player.PlayerData.citizenid, mailData.sender, mailData.subject, mailData.message, generateMailId(), 0})
            TriggerClientEvent('qb-phone:client:NewMailNotify', src, mailData)
        else
            MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES (?, ?, ?, ?, ?, ?, ?)', {player.PlayerData.citizenid, mailData.sender, mailData.subject, mailData.message, generateMailId(), 0, json.encode(mailData.button)})
            TriggerClientEvent('qb-phone:client:NewMailNotify', src, mailData)
        end
        SetTimeout(200, function()
            local mails = MySQL.query.await('SELECT * FROM player_mails WHERE citizenid = ? ORDER BY `date` ASC', {player.PlayerData.citizenid})
            if mails[1] then
                for k, _ in pairs(mails) do
                    if mails[k].button then
                        mails[k].button = json.decode(mails[k].button)
                    end
                end
            end
            TriggerClientEvent('qb-phone:client:UpdateMails', src, mails)
        end)
    else
        if mailData.button == nil then
            MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`) VALUES (?, ?, ?, ?, ?, ?)', {citizenid, mailData.sender, mailData.subject, mailData.message, generateMailId(), 0})
        else
            MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES (?, ?, ?, ?, ?, ?, ?)', {citizenid, mailData.sender, mailData.subject, mailData.message, generateMailId(), 0, json.encode(mailData.button)})
        end
    end
end)

RegisterNetEvent('qb-phone:server:sendNewEventMail', function(citizenid, mailData)
    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if mailData.button == nil then
        MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`) VALUES (?, ?, ?, ?, ?, ?)', {citizenid, mailData.sender, mailData.subject, mailData.message, generateMailId(), 0})
    else
        MySQL.insert('INSERT INTO player_mails (`citizenid`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES (?, ?, ?, ?, ?, ?, ?)', {citizenid, mailData.sender, mailData.subject, mailData.message, generateMailId(), 0, json.encode(mailData.button)})
    end
    SetTimeout(200, function()
        local mails = MySQL.query.await('SELECT * FROM player_mails WHERE citizenid = ? ORDER BY `date` ASC', {citizenid})
        if mails[1] then
            for k, _ in pairs(mails) do
                if mails[k].button then
                    mails[k].button = json.decode(mails[k].button)
                end
            end
        end
        TriggerClientEvent('qb-phone:client:UpdateMails', player.PlayerData.source, mails)
    end)
end)

RegisterNetEvent('qb-phone:server:ClearButtonData', function(mailId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    MySQL.update('UPDATE player_mails SET button = ? WHERE mailid = ? AND citizenid = ?', {'', mailId, player.PlayerData.citizenid})
    SetTimeout(200, function()
        local mails = MySQL.query.await('SELECT * FROM player_mails WHERE citizenid = ? ORDER BY `date` ASC', {player.PlayerData.citizenid})
        if mails[1] then
            for k, _ in pairs(mails) do
                if mails[k].button then
                    mails[k].button = json.decode(mails[k].button)
                end
            end
        end
        TriggerClientEvent('qb-phone:client:UpdateMails', src, mails)
    end)
end)

RegisterNetEvent('qb-phone:server:MentionedPlayer', function(firstName, lastName, tweetMessage)
    for _, v in pairs(exports.qbx_core:GetQBPlayers()) do
        local player = exports.qbx_core:GetPlayer(v)
        if player then
            if (player.PlayerData.charinfo.firstname == firstName and player.PlayerData.charinfo.lastname == lastName) then
                QBPhone.SetPhoneAlerts(player.PlayerData.citizenid, 'twitter')
                QBPhone.AddMentionedTweet(player.PlayerData.citizenid, tweetMessage)
                TriggerClientEvent('qb-phone:client:GetMentioned', player.PlayerData.source, tweetMessage, AppAlerts[player.PlayerData.citizenid].twitter)
            else
                local query1 = '%' .. firstName .. '%'
                local query2 = '%' .. lastName .. '%'
                local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ? AND charinfo LIKE ?', {query1, query2})
                if result[1] then
                    local MentionedTarget = result[1].citizenid
                    QBPhone.SetPhoneAlerts(MentionedTarget, 'twitter')
                    QBPhone.AddMentionedTweet(MentionedTarget, tweetMessage)
                end
            end
        end
    end
end)

RegisterNetEvent('qb-phone:server:CallContact', function(targetData, callId, anonymousCall)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local target = exports.qbx_core:GetPlayerByPhone(targetData.number)
    if target then
        TriggerClientEvent('qb-phone:client:GetCalled', target.PlayerData.source, player.PlayerData.charinfo.phone, callId, anonymousCall)
    end
end)

RegisterNetEvent('qb-phone:server:BillingEmail', function(data, paid)
    local player = exports.qbx_core:GetPlayer(source)
    for _, v in pairs(exports.qbx_core:GetQBPlayers()) do
        local target = exports.qbx_core:GetPlayer(v)
        if target.PlayerData.job.name == data.society then
            local name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
            TriggerClientEvent('qb-phone:client:BillingEmail', target.PlayerData.source, data, paid, name)
        end
    end
end)

RegisterNetEvent('qb-phone:server:UpdateHashtags', function(handle, messageData)
    local hashtagData = Hashtags[handle]
    if hashtagData and next(hashtagData) then
        hashtagData.messages[#hashtagData.messages+1] = messageData
    else
        Hashtags[handle] = {
            hashtag = handle,
            messages = {messageData}
        }
    end
    TriggerClientEvent('qb-phone:client:UpdateHashtags', -1, handle, messageData)
end)

RegisterNetEvent('qb-phone:server:SetPhoneAlerts', function(app, alerts)
    local src = source
    local citizenId = exports.qbx_core:GetPlayer(src).citizenid
    QBPhone.SetPhoneAlerts(citizenId, app, alerts)
end)

RegisterNetEvent('qb-phone:server:DeleteTweet', function(tweetId)
    local player = exports.qbx_core:GetPlayer(source)
    local delete = false
    local tId = tweetId
    local data = MySQL.scalar.await('SELECT citizenid FROM phone_tweets WHERE tweetId = ?', {tId})
    if data == player.PlayerData.citizenid then
        MySQL.query.await('DELETE FROM phone_tweets WHERE tweetId = ?', {tId})
        delete = true
    end

    if delete then
        for k, _ in pairs(TWData) do
            if TWData[k].tweetId == tId then
                TWData = nil
            end
        end
        TriggerClientEvent('qb-phone:client:UpdateTweets', -1, TWData, nil, true)
    end
end)

RegisterNetEvent('qb-phone:server:UpdateTweets', function(newTweets, tweetData)
    local src = source
    MySQL.insert('INSERT INTO phone_tweets (citizenid, firstName, lastName, message, date, url, picture, tweetid) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        tweetData.citizenid,
        tweetData.firstName,
        tweetData.lastName,
        tweetData.message,
        tweetData.time,
        tweetData.url:gsub("[%<>\"()\' $]",""),
        tweetData.picture:gsub("[%<>\"()\' $]",""),
        tweetData.tweetId
    })
    TriggerClientEvent('qb-phone:client:UpdateTweets', -1, src, newTweets, tweetData, false)
end)

RegisterNetEvent('qb-phone:server:TransferMoney', function(iban, amount)
    local src = source
    local sender = exports.qbx_core:GetPlayer(src)
    local query = '%' .. iban .. '%'
    local result = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', {query})
    if result[1] then
        local reciever = exports.qbx_core:GetPlayerByCitizenId(result[1].citizenid)

        if reciever then
            local phoneItem = reciever.Functions.GetItemByName('phone')
            reciever.Functions.AddMoney('bank', amount, 'phone-transfered-from-' .. sender.PlayerData.citizenid)
            sender.Functions.RemoveMoney('bank', amount, 'phone-transfered-to-' .. reciever.PlayerData.citizenid)

            if phoneItem then
                TriggerClientEvent('qb-phone:client:TransferMoney', reciever.PlayerData.source, amount, reciever.PlayerData.money.bank)
            end
        else
            local moneyInfo = json.decode(result[1].money)
            moneyInfo.bank = math.round((moneyInfo.bank + amount))
            MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?', {json.encode(moneyInfo), result[1].citizenid})
            sender.Functions.RemoveMoney('bank', amount, 'phone-transfered')
        end
    else
        exports.qbx_core:Notify(src, 'This account number doesn\'t exist!', 'error')
    end
end)

RegisterNetEvent('qb-phone:server:EditContact', function(newName, newNumber, newIban, oldName, oldNumber, _)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    MySQL.update('UPDATE player_contacts SET name = ?, number = ?, iban = ? WHERE citizenid = ? AND name = ? AND number = ?', {newName, newNumber, newIban, player.PlayerData.citizenid, oldName, oldNumber})
end)

RegisterNetEvent('qb-phone:server:RemoveContact', function(name, number)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    MySQL.query('DELETE FROM player_contacts WHERE name = ? AND number = ? AND citizenid = ?', {name, number, player.PlayerData.citizenid})
end)

RegisterNetEvent('qb-phone:server:AddNewContact', function(name, number, iban)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    MySQL.insert('INSERT INTO player_contacts (citizenid, name, number, iban) VALUES (?, ?, ?, ?)', {player.PlayerData.citizenid, tostring(name), tostring(number), tostring(iban)})
end)

RegisterNetEvent('qb-phone:server:UpdateMessages', function(chatMessages, chatNumber, _)
    local src = source
    local senderData = exports.qbx_core:GetPlayer(src)
    local query = '%' .. chatNumber .. '%'
    local player = MySQL.query.await('SELECT * FROM players WHERE charinfo LIKE ?', {query})
    if player[1] then
        local targetData = exports.qbx_core:GetPlayerByCitizenId(player[1].citizenid)
        if targetData then
            local chat = MySQL.query.await('SELECT * FROM phone_messages WHERE citizenid = ? AND number = ?', {senderData.PlayerData.citizenid, chatNumber})
            if chat[1] then
                -- Update for target
                MySQL.update('UPDATE phone_messages SET messages = ? WHERE citizenid = ? AND number = ?', {json.encode(chatMessages), targetData.PlayerData.citizenid, senderData.PlayerData.charinfo.phone})
                -- Update for sender
                MySQL.update('UPDATE phone_messages SET messages = ? WHERE citizenid = ? AND number = ?', {json.encode(chatMessages), senderData.PlayerData.citizenid, targetData.PlayerData.charinfo.phone})
                -- Send notification & Update messages for target
                TriggerClientEvent('qb-phone:client:UpdateMessages', targetData.PlayerData.source, chatMessages, senderData.PlayerData.charinfo.phone, false)
            else
                -- Insert for target
                MySQL.insert('INSERT INTO phone_messages (citizenid, number, messages) VALUES (?, ?, ?)', {targetData.PlayerData.citizenid, senderData.PlayerData.charinfo.phone, json.encode(chatMessages)})
                -- Insert for sender
                MySQL.insert('INSERT INTO phone_messages (citizenid, number, messages) VALUES (?, ?, ?)', {senderData.PlayerData.citizenid, targetData.PlayerData.charinfo.phone, json.encode(chatMessages)})
                -- Send notification & Update messages for target
                TriggerClientEvent('qb-phone:client:UpdateMessages', targetData.PlayerData.source, chatMessages, senderData.PlayerData.charinfo.phone, true)
            end
        else
            local chat = MySQL.query.await('SELECT * FROM phone_messages WHERE citizenid = ? AND number = ?', {senderData.PlayerData.citizenid, chatNumber})
            if chat[1] then
                -- Update for target
                MySQL.update('UPDATE phone_messages SET messages = ? WHERE citizenid = ? AND number = ?', {json.encode(chatMessages), player[1].citizenid, senderData.PlayerData.charinfo.phone})
                -- Update for sender
                player[1].charinfo = json.decode(player[1].charinfo)
                MySQL.update('UPDATE phone_messages SET messages = ? WHERE citizenid = ? AND number = ?', {json.encode(chatMessages), senderData.PlayerData.citizenid, player[1].charinfo.phone})
            else
                -- Insert for target
                MySQL.insert('INSERT INTO phone_messages (citizenid, number, messages) VALUES (?, ?, ?)', {player[1].citizenid, senderData.PlayerData.charinfo.phone, json.encode(chatMessages)})
                -- Insert for sender
                player[1].charinfo = json.decode(player[1].charinfo)
                MySQL.insert('INSERT INTO phone_messages (citizenid, number, messages) VALUES (?, ?, ?)', {senderData.PlayerData.citizenid, player[1].charinfo.phone, json.encode(chatMessages)})
            end
        end
    end
end)

RegisterNetEvent('qb-phone:server:AddRecentCall', function(type, data)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local hour = os.date('%H')
    local minute = os.date('%M')
    local label = hour .. ':' .. minute
    TriggerClientEvent('qb-phone:client:AddRecentCall', src, data, label, type)
    local target = exports.qbx_core:GetPlayerByPhone(data.number)
    if target then
        TriggerClientEvent('qb-phone:client:AddRecentCall', target.PlayerData.source, {
            name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
            number = player.PlayerData.charinfo.phone,
            anonymous = data.anonymous
        }, label, 'outgoing')
    end
end)

RegisterNetEvent('qb-phone:server:CancelCall', function(contactData)
    local player = exports.qbx_core:GetPlayerByPhone(contactData.TargetData.number)
    if player then
        TriggerClientEvent('qb-phone:client:CancelCall', player.PlayerData.source)
    end
end)

RegisterNetEvent('qb-phone:server:AnswerCall', function(callData)
    local player = exports.qbx_core:GetPlayerByPhone(callData.TargetData.number)
    if player then
        TriggerClientEvent('qb-phone:client:AnswerCall', player.PlayerData.source)
    end
end)

RegisterNetEvent('qb-phone:server:SaveMetaData', function(mData)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local result = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', {player.PlayerData.citizenid})
    local metaData = json.decode(result[1].metadata)
    metaData.phone = mData
    MySQL.update('UPDATE players SET metadata = ? WHERE citizenid = ?', {json.encode(metaData), player.PlayerData.citizenid})
    player.Functions.SetMetaData('phone', mData)
end)

RegisterNetEvent('qb-phone:server:GiveContactDetails', function(playerId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local suggestionData = {
        name = {
            [1] = player.PlayerData.charinfo.firstname,
            [2] = player.PlayerData.charinfo.lastname
        },
        number = player.PlayerData.charinfo.phone,
        bank = player.PlayerData.charinfo.account
    }

    TriggerClientEvent('qb-phone:client:AddNewSuggestion', playerId, suggestionData)
end)

RegisterNetEvent('qb-phone:server:AddTransaction', function(data)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    MySQL.insert('INSERT INTO crypto_transactions (citizenid, title, message) VALUES (?, ?, ?)', {
        player.PlayerData.citizenid,
        data.TransactionTitle,
        data.TransactionMessage
    })
end)

RegisterNetEvent('qb-phone:server:InstallApplication', function(applicationData)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    player.PlayerData.metadata.phonedata.InstalledApps[applicationData.app] = applicationData
    player.Functions.SetMetaData('phonedata', player.PlayerData.metadata.phonedata)

    -- TriggerClientEvent('qb-phone:RefreshPhone', src)
end)

RegisterNetEvent('qb-phone:server:RemoveInstallation', function(app)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    player.PlayerData.metadata.phonedata.InstalledApps[app] = nil
    player.Functions.SetMetaData('phonedata', player.PlayerData.metadata.phonedata)

    -- TriggerClientEvent('qb-phone:RefreshPhone', src)
end)

RegisterNetEvent('qb-phone:server:addImageToGallery', function(image)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    MySQL.insert('INSERT INTO phone_gallery (`citizenid`, `image`) VALUES (?, ?)', {player.PlayerData.citizenid,image})
end)

RegisterNetEvent('qb-phone:server:getImageFromGallery', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local images = MySQL.query.await('SELECT * FROM phone_gallery WHERE citizenid = ? ORDER BY `date` DESC', {player.PlayerData.citizenid})
    TriggerClientEvent('qb-phone:refreshImages', src, images)
end)

RegisterNetEvent('qb-phone:server:RemoveImageFromGallery', function(data)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local image = data.image
    MySQL.query('DELETE FROM phone_gallery WHERE citizenid = ? AND image = ?', {player.PlayerData.citizenid,image})
end)

RegisterNetEvent('qb-phone:server:sendPing', function(data)
    local src = source
    if src == data then
        exports.qbx_core:Notify(src, 'You cannot ping yourself', 'error')
    end
end)

lib.addCommand('setmetadata', {help = 'Set Player Metadata (God Only)', restricted = 'god'}, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    if args[1] == 'trucker' and args[2] then
        local newrep = player.PlayerData.metadata.jobrep
        newrep.trucker = tonumber(args[2])
        player.Functions.SetMetaData('jobrep', newrep)
    end
end)

lib.addCommand('bill', {help = 'Bill A Player', params = {{name = 'id', type = 'playerId', help = 'Player\'s Server ID'},{name = 'amount', type = 'number', help = 'Fine Amount'}}}, function(source, args)
    local biller = exports.qbx_core:GetPlayer(source)
    local billed = exports.qbx_core:GetPlayer(args.id)

    if not (biller.PlayerData.job.name == 'police' or biller.PlayerData.job.name == 'ambulance' or biller.PlayerData.job.name == 'mechanic') then
        exports.qbx_core:Notify(source, 'No Access', 'error')
        return
    end

    if billed == nil then
        exports.qbx_core:Notify(source, 'Player Not Online', 'error')
        return
    end

    if biller.PlayerData.citizenid == billed.PlayerData.citizenid then
        exports.qbx_core:Notify(source, 'You Cannot Bill Yourself', 'error')
        return
    end

    if not (args.amount and args.amount > 0) then
        exports.qbx_core:Notify(source, 'Must Be A Valid Amount Above 0', 'error')
        return
    end

    MySQL.insert('INSERT INTO phone_invoices (citizenid, amount, society, sender, sendercitizenid) VALUES (?, ?, ?, ?, ?)', {
        billed.PlayerData.citizenid,
        args.amount,
        biller.PlayerData.job.name,
        biller.PlayerData.charinfo.firstname,
        biller.PlayerData.citizenid
    })

    TriggerClientEvent('qb-phone:RefreshPhone', billed.PlayerData.source)
    exports.qbx_core:Notify(source, 'Invoice Successfully Sent', 'success')
    exports.qbx_core:Notify(billed.PlayerData.source, 'New Invoice Received', 'success')
end)