local config = require 'config.client'
--local apartmentConfig = require '@qbx_apartments.config.shared'
local VEHICLES = exports.qbx_core:GetVehiclesByName()
local patt = '[?!@#]'
local frontCam = false
PhoneData = {
    MetaData = {},
    isOpen = false,
    PlayerData = nil,
    Contacts = {},
    Tweets = {},
    MentionedTweets = {},
    Hashtags = {},
    Chats = {},
    Invoices = {},
    CallData = {},
    RecentCalls = {},
    Garage = {},
    Mails = {},
    Adverts = {},
    GarageVehicles = {},
    AnimationData = {
        lib = nil,
        anim = nil,
    },
    SuggestedContacts = {},
    CryptoTransactions = {},
    Images = {},
}

local function escape_str(s)
    return s
end

local function generateTweetId()
    return 'TWEET-' .. math.random(11111111, 99999999)
end

local function isNumberInContacts(num)
    for _, v in pairs(PhoneData.Contacts) do
        if num == v.number then
            return v.name
        end
    end

    return 'Unknown'
end

local function calculateTimeToDisplay()
    local hour = GetClockHours()
    local minute = GetClockMinutes()

    local obj = {}

    if minute <= 9 then
        minute = '0' .. minute
    end

    obj.hour = hour
    obj.minute = minute

    return obj
end

local function getKeyByDate(number, date)
    if PhoneData.Chats[number] and PhoneData.Chats[number].messages then
        for key, chat in pairs(PhoneData.Chats[number].messages) do
            if chat.date == date then
                return key
            end
        end
    end
    return nil
end

local function getKeyByNumber(number)
    for k, v in pairs(PhoneData.Chats or {}) do
        if v.number == tostring(number) then
            return k
        end
    end
    return nil
end

local function reorganizeChats(key)
    local reorganizedChats = {}
    reorganizedChats[1] = PhoneData.Chats[key]
    for k, chat in pairs(PhoneData.Chats) do
        if k ~= key then
            reorganizedChats[#reorganizedChats + 1] = chat
        end
    end
    PhoneData.Chats = reorganizedChats
end

local function findVehFromPlateAndLocate(plate)
    local gameVehicles = GetGamePool('CVehicle')
    for i = 1, #gameVehicles do
        local vehicle = gameVehicles[i]
        if DoesEntityExist(vehicle) then
            if qbx.getVehiclePlate(vehicle) == plate then
                local vehCoords = GetEntityCoords(vehicle)
                SetNewWaypoint(vehCoords.x, vehCoords.y)
                return true
            end
        end
    end
end

local function disableDisplayControlActions()
    local controlActions = {1, 2, 3, 4, 5, 6, 263, 264, 257, 140, 141, 142, 143, 177, 200, 202, 322, 245}

    for _, controlAction in ipairs(controlActions) do
        DisableControlAction(0, controlAction, true)
    end
end

local function loadPhone()
    Wait(100)

    local pData = lib.callback.await('qb-phone:server:GetPhoneData', false)

    PhoneData.PlayerData = QBX.PlayerData
    local PhoneMeta = PhoneData.PlayerData.metadata.phone
    PhoneData.MetaData = PhoneMeta

    if pData.InstalledApps and next(pData.InstalledApps) then
        for _, v in pairs(pData.InstalledApps) do
            local AppData = config.storeApps[v.app]
            config.phoneApps[v.app] = {
                app = v.app,
                color = AppData.color,
                icon = AppData.icon,
                tooltipText = AppData.title,
                tooltipPos = 'right',
                job = AppData.job,
                blockedjobs = AppData.blockedjobs,
                slot = AppData.slot,
                Alerts = 0,
            }
        end
    end

    PhoneData.MetaData.profilepicture = PhoneMeta.profilepicture or 'default'

    if pData.Applications and next(pData.Applications) then
        for k, v in pairs(pData.Applications) do
            config.phoneApps[k].Alerts = v
        end
    end

    if pData.MentionedTweets and next(pData.MentionedTweets) then
        PhoneData.MentionedTweets = pData.MentionedTweets
    end

    if pData.PlayerContacts and next(pData.PlayerContacts) then
        PhoneData.Contacts = pData.PlayerContacts
    end

    if pData.Chats and next(pData.Chats) then
        local chats = {}
        for _, v in pairs(pData.Chats) do
            chats[v.number] = {
                name = isNumberInContacts(v.number),
                number = v.number,
                messages = json.decode(v.messages)
            }
        end

        PhoneData.Chats = chats
    end

    if pData.Invoices and next(pData.Invoices) then
        for _, invoice in pairs(pData.Invoices) do
            invoice.name = isNumberInContacts(invoice.number)
        end
        PhoneData.Invoices = pData.Invoices
    end

    if pData.Hashtags and next(pData.Hashtags) then
        PhoneData.Hashtags = pData.Hashtags
    end

    if pData.Tweets and next(pData.Tweets) then
        PhoneData.Tweets = pData.Tweets
    end

    if pData.Mails and next(pData.Mails) then
        PhoneData.Mails = pData.Mails
    end

    if pData.Adverts and next(pData.Adverts) then
        PhoneData.Adverts = pData.Adverts
    end

    if pData.CryptoTransactions and next(pData.CryptoTransactions) then
        PhoneData.CryptoTransactions = pData.CryptoTransactions
    end

    if pData.Images and next(pData.Images) then
        PhoneData.Images = pData.Images
    end

    SendNUIMessage({
        action = 'loadPhoneData',
        PhoneData = PhoneData,
        PlayerData = PhoneData.PlayerData,
        PlayerJob = PhoneData.PlayerData.job,
        applications = config.phoneApps,
        PlayerId = GetPlayerServerId(cache.playerId)
    })
end

local function openPhone()
    local hasPhone = lib.callback.await('qb-phone:server:GetPhoneData', false)
    if not hasPhone then exports.qbx_core:Notify('You don\'t have a phone', 'error') end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        Tweets = PhoneData.Tweets,
        AppData = config.phoneApps,
        CallData = PhoneData.CallData,
        PlayerData = QBX.PlayerData,
    })

    PhoneData.isOpen = true

    CreateThread(function()
        while PhoneData.isOpen do
            disableDisplayControlActions()
            Wait(1)
        end
    end)

    local animation = PhoneData.CallData.InCall and 'cellphone_call_to_text' or 'cellphone_text_in'
    DoPhoneAnimation(animation)

    SetTimeout(250, function()
        NewPhoneProp()
    end)

    local vehicles = lib.callback.await('qb-phone:server:GetPhoneData', false)
    PhoneData.GarageVehicles = vehicles
end

local function generateCallId(caller, target)
    return (tonumber(caller) + tonumber(target)) // 100
end

local function cancelCall()
    TriggerServerEvent('qb-phone:server:cancelCall', PhoneData.CallData)

    if PhoneData.CallData.CallType == 'ongoing' then
        exports['pma-voice']:removePlayerFromCall(PhoneData.CallData.CallId)
    end

    PhoneData.CallData.CallType = nil
    PhoneData.CallData.InCall = false
    PhoneData.CallData.AnsweredCall = false
    PhoneData.CallData.TargetData = {}
    PhoneData.CallData.CallId = nil

    if not PhoneData.isOpen then
        StopAnimTask(cache.ped, PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 2.5)
        DeletePhone()
    end

    PhoneData.AnimationData.lib = nil
    PhoneData.AnimationData.anim = nil

    TriggerServerEvent('qb-phone:server:SetCallState', false)

    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Phone',
            text = 'The call has been ended',
            icon = 'fas fa-phone',
            color = '#e84118',
        },
    })

    if PhoneData.isOpen then
        SendNUIMessage({
            action = 'SetupHomeCall',
            CallData = PhoneData.CallData,
        })

        SendNUIMessage({
            action = 'CancelOutgoingCall',
        })
    end
end

local function callContact(callData, anonymousCall)
    local repeatCount = 0
    PhoneData.CallData.CallType = 'outgoing'
    PhoneData.CallData.InCall = true
    PhoneData.CallData.TargetData = callData
    PhoneData.CallData.AnsweredCall = false
    PhoneData.CallData.CallId = generateCallId(PhoneData.PlayerData.charinfo.phone, callData.number)

    TriggerServerEvent('qb-phone:server:callContact', PhoneData.CallData.TargetData, PhoneData.CallData.CallId, anonymousCall)
    TriggerServerEvent('qb-phone:server:SetCallState', true)

    for _ = 1, config.callRepeats + 1, 1 do
        if not PhoneData.CallData.AnsweredCall then
            if repeatCount + 1 ~= config.callRepeats + 1 then
                if PhoneData.CallData.InCall then
                    repeatCount = repeatCount + 1
                    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'demo', 0.1)
                else
                    break
                end
                Wait(config.repeatTimeout)
            else
                cancelCall()
                break
            end
        else
            break
        end
    end
end

local function answerCall()
    if (PhoneData.CallData.CallType == 'incoming' or PhoneData.CallData.CallType == 'outgoing') and PhoneData.CallData.InCall and not PhoneData.CallData.AnsweredCall then
        PhoneData.CallData.CallType = 'ongoing'
        PhoneData.CallData.AnsweredCall = true
        PhoneData.CallData.CallTime = 0

        SendNUIMessage({
            action = 'answerCall',
            CallData = PhoneData.CallData
        })

        SendNUIMessage({
            action = 'SetupHomeCall',
            CallData = PhoneData.CallData
        })

        TriggerServerEvent('qb-phone:server:SetCallState', true)

        local animation = PhoneData.isOpen and 'cellphone_text_to_call' or 'cellphone_call_listen_base'
        DoPhoneAnimation(animation)

        CreateThread(function()
            while true do
                if PhoneData.CallData.AnsweredCall then
                    PhoneData.CallData.CallTime = PhoneData.CallData.CallTime + 1
                    SendNUIMessage({
                        action = 'UpdateCallTime',
                        Time = PhoneData.CallData.CallTime,
                        Name = PhoneData.CallData.TargetData.name,
                    })
                else
                    break
                end

                Wait(1000)
            end
        end)

        TriggerServerEvent('qb-phone:server:answerCall', PhoneData.CallData)
        exports['pma-voice']:addPlayerToCall(PhoneData.CallData.CallId)
    else
        PhoneData.CallData.InCall = false
        PhoneData.CallData.CallType = nil
        PhoneData.CallData.AnsweredCall = false

        SendNUIMessage({
            action = 'PhoneNotification',
            PhoneNotify = {
                title = 'Phone',
                text = 'You don\'t have a incoming call...',
                icon = 'fas fa-phone',
                color = '#e84118',
            },
        })
    end
end

local function cellFrontCamActivate(activate)
    return Citizen.InvokeNative(0x2491A93618B7D838, activate)
end

RegisterCommand('phone', function()
    if not PhoneData.isOpen and LocalPlayer.state.isLoggedIn then
        if QBX.PlayerData.metadata.ishandcuffed and QBX.PlayerData.metadata.inlaststand and QBX.PlayerData.metadata.isdead and IsPauseMenuActive() then
            exports.qbx_core:Notify('Action not available at the moment..', 'error')
        end

        openPhone()
    end
end, false)

RegisterKeyMapping('phone', 'Open Phone', 'keyboard', 'M')

RegisterNUICallback('CancelOutgoingCall', function(_, cb)
    cancelCall()
    cb('ok')
end)

RegisterNUICallback('DenyIncomingCall', function(_, cb)
    cancelCall()
    cb('ok')
end)

RegisterNUICallback('CancelOngoingCall', function(_, cb)
    cancelCall()
    cb('ok')
end)

RegisterNUICallback('answerCall', function(_, cb)
    answerCall()
    cb('ok')
end)

RegisterNUICallback('ClearRecentAlerts', function(_, cb)
    TriggerServerEvent('qb-phone:server:SetPhoneAlerts', 'phone', 0)
    config.phoneApps.phone.Alerts = 0
    SendNUIMessage({ action = 'RefreshAppAlerts', AppData = config.phoneApps })
    cb('ok')
end)

RegisterNUICallback('SetBackground', function(data, cb)
    local background = data.background
    PhoneData.MetaData.background = background
    TriggerServerEvent('qb-phone:server:SaveMetaData', PhoneData.MetaData)
    cb('ok')
end)

RegisterNUICallback('GetMissedCalls', function(_, cb)
    cb(PhoneData.RecentCalls)
end)

RegisterNUICallback('GetSuggestedContacts', function(_, cb)
    cb(PhoneData.SuggestedContacts)
end)

RegisterNUICallback('HasPhone', function(_, cb)
    local hasPhone = lib.callback.await('qb-phone:server:HasPhone', false)
    cb(hasPhone)
end)

RegisterNUICallback('SetupGarageVehicles', function(_, cb)
    cb(PhoneData.GarageVehicles)
end)

RegisterNUICallback('RemoveMail', function(data, cb)
    local mailId = data.mailId
    TriggerServerEvent('qb-phone:server:RemoveMail', mailId)
    cb('ok')
end)

RegisterNUICallback('Close', function(_, cb)
    if not PhoneData.CallData.InCall then
        DoPhoneAnimation('cellphone_text_out')
        SetTimeout(400, function()
            StopAnimTask(cache.ped, PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 2.5)
            DeletePhone()
            PhoneData.AnimationData.lib = nil
            PhoneData.AnimationData.anim = nil
        end)
    else
        PhoneData.AnimationData.lib = nil
        PhoneData.AnimationData.anim = nil
        DoPhoneAnimation('cellphone_text_to_call')
    end

    SetNuiFocus(false, false)
    SetTimeout(500, function()
        PhoneData.isOpen = false
    end)
    cb('ok')
end)

RegisterNUICallback('AcceptMailButton', function(data, cb)
    if data.buttonEvent or data.buttonData then
        TriggerEvent(data.buttonEvent, data.buttonData)
    end
    TriggerServerEvent('qb-phone:server:ClearButtonData', data.mailId)
    cb('ok')
end)

RegisterNUICallback('AddNewContact', function(data, cb)
    PhoneData.Contacts[#PhoneData.Contacts + 1] = {
        name = data.ContactName,
        number = data.ContactNumber,
        iban = data.ContactIban
    }
    Wait(100)
    cb(PhoneData.Contacts)
    if PhoneData.Chats[data.ContactNumber] and next(PhoneData.Chats[data.ContactNumber]) then
        PhoneData.Chats[data.ContactNumber].name = data.ContactName
    end
    TriggerServerEvent('qb-phone:server:AddNewContact', data.ContactName, data.ContactNumber, data.ContactIban)
end)

RegisterNUICallback('GetMails', function(_, cb)
    cb(PhoneData.Mails)
end)

RegisterNUICallback('GetMessagesChat', function(data, cb)
    local chat = PhoneData.Chats[data.phone]
    cb(chat or false)
end)

RegisterNUICallback('GetProfilePicture', function(data, cb)
    local number = data.number
    local picture = lib.callback.await('qb-phone:server:GetPicture', false, number)
    cb(picture)
end)

RegisterNUICallback('GetBankContacts', function(_, cb)
    cb(PhoneData.Contacts)
end)

RegisterNUICallback('GetInvoices', function(_, cb)
    if PhoneData.Invoices and next(PhoneData.Invoices) then
        cb(PhoneData.Invoices)
    else
        cb(nil)
    end
end)

RegisterNUICallback('SharedLocation', function(data, cb)
    local x = data.coords.x
    local y = data.coords.y
    SetNewWaypoint(x, y)
    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Messages',
            text = 'Location has been set!',
            icon = 'fab fa-comment',
            color = '#25D366',
            timeout = 1500,
        },
    })
    cb('ok')
end)

RegisterNUICallback('PostAdvert', function(data, cb)
    TriggerServerEvent('qb-phone:server:AddAdvert', data.message, data.url)
    cb('ok')
end)

RegisterNUICallback('DeleteAdvert', function(_, cb)
    TriggerServerEvent('qb-phone:server:DeleteAdvert')
    cb('ok')
end)

RegisterNUICallback('LoadAdverts', function(_, cb)
    SendNUIMessage({
        action = 'RefreshAdverts',
        Adverts = PhoneData.Adverts
    })
    cb('ok')
end)

RegisterNUICallback('ClearAlerts', function(data, cb)
    local chat = data.number
    local chatKey = getKeyByNumber(chat)

    if PhoneData.Chats[chatKey].Unread then
        local newAlerts = (config.phoneApps.messages.Alerts - PhoneData.Chats[chatKey].Unread)
        config.phoneApps.whataspp.Alerts = newAlerts
        TriggerServerEvent('qb-phone:server:SetPhoneAlerts', 'messages', newAlerts)

        PhoneData.Chats[chatKey].Unread = 0

        SendNUIMessage({
            action = 'RefreshMessagesAlerts',
            Chats = PhoneData.Chats,
        })
        SendNUIMessage({ action = 'RefreshAppAlerts', AppData = config.phoneApps })
    end
    cb('ok')
end)

RegisterNUICallback('PayInvoice', function(data, cb)
    local senderCitizenId = data.senderCitizenId
    local society = data.society
    local amount = data.amount
    local invoiceId = data.invoiceId

    local canPay, invoices = lib.callback.await('ox_inventory:getItemCount', false, society, amount, invoiceId, senderCitizenId)
    if canPay then PhoneData.Invoices = invoices end

    cb(canPay)
    TriggerServerEvent('qb-phone:server:BillingEmail', data, true)
end)

RegisterNUICallback('DeclineInvoice', function(data, cb)
    local society = data.society
    local amount = data.amount
    local invoiceId = data.invoiceId

    local _, invoices = lib.callback.await('qb-phone:server:DeclineInvoice', false, society, amount, invoiceId)
    PhoneData.Invoices = invoices

    cb('ok')
    TriggerServerEvent('qb-phone:server:BillingEmail', data, false)
end)

RegisterNUICallback('EditContact', function(data, cb)
    local newName = data.CurrentContactName
    local newNumber = data.CurrentContactNumber
    local newIban = data.CurrentContactIban
    local oldName = data.OldContactName
    local oldNumber = data.OldContactNumber
    local oldIban = data.OldContactIban
    for _, v in pairs(PhoneData.Contacts) do
        if v.name == oldName and v.number == oldNumber then
            v.name = newName
            v.number = newNumber
            v.iban = newIban
        end
    end
    if PhoneData.Chats[newNumber] and next(PhoneData.Chats[newNumber]) then
        PhoneData.Chats[newNumber].name = newName
    end
    Wait(100)
    cb(PhoneData.Contacts)
    TriggerServerEvent('qb-phone:server:EditContact', newName, newNumber, newIban, oldName, oldNumber, oldIban)
end)

RegisterNUICallback('GetHashtagMessages', function(data, cb)
    local hashtags = PhoneData.Hashtags[data.hashtag]
    cb(hashtags and next(hashtags) and hashtags or nil)
end)

RegisterNUICallback('GetTweets', function(_, cb)
    cb(PhoneData.Tweets)
end)

RegisterNUICallback('UpdateProfilePicture', function(data, cb)
    local pf = data.profilepicture
    PhoneData.MetaData.profilepicture = pf
    TriggerServerEvent('qb-phone:server:SaveMetaData', PhoneData.MetaData)
    cb('ok')
end)

RegisterNUICallback('PostNewTweet', function(data, cb)
    local tweetMessage = {
        firstName = PhoneData.PlayerData.charinfo.firstname,
        lastName = PhoneData.PlayerData.charinfo.lastname,
        citizenid = PhoneData.PlayerData.citizenid,
        message = escape_str(data.Message),
        time = data.Date,
        tweetId = generateTweetId(),
        picture = data.Picture,
        url = data.url
    }

    local twitterMessage = data.Message
    local mentionTag = twitterMessage:split('@')
    local hashtag = twitterMessage:split('#')
    if #hashtag <= 3 then
        for i = 2, #hashtag, 1 do
            local Handle = hashtag[i]:split(' ')[1]
            if Handle or Handle ~= '' then
                local invalidSymbol = string.match(Handle, patt)
                if invalidSymbol then
                    Handle = Handle:gsub('%' .. invalidSymbol, '')
                end
                TriggerServerEvent('qb-phone:server:UpdateHashtags', Handle, tweetMessage)
            end
        end

        for i = 2, #mentionTag, 1 do
            local handle = mentionTag[i]:split(' ')[1]
            if handle or handle ~= '' then
                local fullName = handle:split('_')
                local firstName = fullName[1]
                table.remove(fullName, 1)
                local lastName = table.concat(fullName, ' ')

                if (firstName and firstName ~= '') and (lastName and lastName ~= '') then
                    if firstName ~= PhoneData.PlayerData.charinfo.firstname and lastName ~= PhoneData.PlayerData.charinfo.lastname then
                        TriggerServerEvent('qb-phone:server:MentionedPlayer', firstName, lastName, tweetMessage)
                    end
                end
            end
        end

        PhoneData.Tweets[#PhoneData.Tweets + 1] = tweetMessage
        Wait(100)
        cb(PhoneData.Tweets)

        TriggerServerEvent('qb-phone:server:UpdateTweets', PhoneData.Tweets, tweetMessage)
    else
        SendNUIMessage({
            action = 'PhoneNotification',
            PhoneNotify = {
                title = 'Twitter',
                text = 'Invalid Tweet',
                icon = 'fab fa-twitter',
                color = '#1DA1F2',
                timeout = 1000,
            },
        })
    end
end)

RegisterNUICallback('DeleteTweet', function(data, cb)
    TriggerServerEvent('qb-phone:server:DeleteTweet', data.id)
    cb('ok')
end)

RegisterNUICallback('GetMentionedTweets', function(_, cb)
    cb(PhoneData.MentionedTweets)
end)

RegisterNUICallback('GetHashtags', function(_, cb)
    if PhoneData.Hashtags and next(PhoneData.Hashtags) then
        cb(PhoneData.Hashtags)
    else
        cb(nil)
    end
end)

RegisterNUICallback('FetchSearchResults', function(data, cb)
    local result = lib.callback.await('ox_inventory:getItemCount', false, data.input)
    cb(result)
end)

local function getFirstAvailableSlot() -- Placeholder
    return nil
end

local canDownloadApps = false

RegisterNUICallback('InstallApplication', function(data, cb)
    local applicationData = config.storeApps[data.app]
    local newSlot = getFirstAvailableSlot()

    if not canDownloadApps then
        return
    end

    if newSlot <= config.maxSlots then
        TriggerServerEvent('qb-phone:server:InstallApplication', {app = data.app})
        cb({app = data.app, data = applicationData})
    else
        cb(false)
    end
end)

RegisterNUICallback('RemoveApplication', function(data, cb)
    TriggerServerEvent('qb-phone:server:RemoveInstallation', data.app)
    cb('ok')
end)

RegisterNUICallback('GetTruckerData', function(_, cb)
    local truckerMeta = QBX.PlayerData.metadata.jobrep.trucker
    local tierData = exports.qbx_trucker:GetTier(truckerMeta)
    cb(tierData)
end)

RegisterNUICallback('GetGalleryData', function(_, cb)
    local data = PhoneData.Images
    cb(data)
end)

RegisterNUICallback('DeleteImage', function(image, cb)
    TriggerServerEvent('qb-phone:server:RemoveImageFromGallery', image)
    Wait(400)
    TriggerServerEvent('qb-phone:server:getImageFromGallery')
    cb(true)
end)


RegisterNUICallback('track-vehicle', function(data, cb)
    local veh = data.veh
    if findVehFromPlateAndLocate(veh.plate) then
        exports.qbx_core:Notify('Vehicle tracked', 'success' )
    else
        exports.qbx_core:Notify('Vehicle cannot be located', 'error' )
    end
    cb('ok')
end)

RegisterNUICallback('DeleteContact', function(data, cb)
    local name = data.CurrentContactName
    local number = data.CurrentContactNumber

    for k, v in pairs(PhoneData.Contacts) do
        if v.name == name and v.number == number then
            table.remove(PhoneData.Contacts, k)
            --if PhoneData.isOpen then
            SendNUIMessage({
                action = 'PhoneNotification',
                PhoneNotify = {
                    title = 'Phone',
                    text = 'You deleted contact!',
                    icon = 'fa fa-phone-alt',
                    color = '#04b543',
                    timeout = 1500,
                },
            })
            break
        end
    end
    Wait(100)
    cb(PhoneData.Contacts)
    if PhoneData.Chats[number] and next(PhoneData.Chats[number]) then
        PhoneData.Chats[number].name = number
    end
    TriggerServerEvent('qb-phone:server:RemoveContact', name, number)
end)

RegisterNUICallback('GetCryptoData', function(data, cb)
    local cryptoData = lib.callback.await('qb-crypto:server:GetCryptoData', false, data.crypto)
    cb(cryptoData)
end)

RegisterNUICallback('BuyCrypto', function(data, cb)
    local cryptoData = lib.callback.await('qb-crypto:server:BuyCrypto', false, data)
    cb(cryptoData)
end)

RegisterNUICallback('SellCrypto', function(data, cb)
    local cryptoData = lib.callback.await('qb-crypto:server:SellCrypto', false, data)
    cb(cryptoData)
end)

RegisterNUICallback('TransferCrypto', function(data, cb)
    local cryptoData = lib.callback.await('qb-crypto:server:TransferCrypto', false, data)
    cb(cryptoData)
end)

RegisterNUICallback('GetCryptoTransactions', function(_, cb)
    local data = {
        CryptoTransactions = PhoneData.CryptoTransactions
    }
    cb(data)
end)

RegisterNUICallback('GetAvailableRaces', function(_, cb)
    local races = lib.callback.await('qb-lapraces:server:GetRaces', false)
    cb(races)
end)

RegisterNUICallback('JoinRace', function(data, cb)
    TriggerServerEvent('qb-lapraces:server:JoinRace', data.RaceData)
    cb('ok')
end)

RegisterNUICallback('LeaveRace', function(data, cb)
    TriggerServerEvent('qb-lapraces:server:LeaveRace', data.RaceData)
    cb('ok')
end)

RegisterNUICallback('StartRace', function(data, cb)
    TriggerServerEvent('qb-lapraces:server:StartRace', data.RaceData.RaceId)
    cb('ok')
end)

RegisterNUICallback('SetAlertWaypoint', function(data, cb)
    local coords = data.alert.coords
    exports.qbx_core:Notify('GPS Location set: ' .. data.alert.title, 'inform' )
    SetNewWaypoint(coords.x, coords.y)
    cb('ok')
end)

RegisterNUICallback('RemoveSuggestion', function(data, cb)
    data = data.data
    if PhoneData.SuggestedContacts and next(PhoneData.SuggestedContacts) then
        for k, v in pairs(PhoneData.SuggestedContacts) do
            if (data.name[1] == v.name[1] and data.name[2] == v.name[2]) and data.number == v.number and data.bank == v.bank then
                table.remove(PhoneData.SuggestedContacts, k)
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('FetchVehicleResults', function(data, cb)
    local result = lib.callback.await('qb-phone:server:GetVehicleSearchResults', false, data.input)
    if result then
        for k, _ in pairs(result) do
            local flagged = lib.callback.await('police:IsPlateFlagged', false, result[k].plate)
            result[k].isFlagged = flagged
            Wait(50)
        end
    end
    cb(result)
end)

RegisterNUICallback('FetchVehicleScan', function(_, cb)
    local vehicle, _ = lib.getClosestVehicle(GetEntityCoords(cache.ped), 20)
    local plate = qbx.getVehiclePlate(vehicle)
    local vehName = qbx.getVehicleDisplayName(vehicle):lower()
    local result = lib.callback.await('qb-phone:server:ScanPlate', false, plate)
    local flagged = lib.callback.await('police:IsPlateFlagged', false, plate)

    result.isFlagged = flagged
    result.label = VEHICLES[vehName] and VEHICLES[vehName].name or 'Unknown brand..'
    cb(result)
end)

RegisterNUICallback('GetRaces', function(_, cb)
    local races = lib.callback.await('qb-lapraces:server:GetListedRaces', false)
    cb(races)
end)

RegisterNUICallback('GetTrackData', function(data, cb)
    local TrackData, CreatorData = lib.callback.await('qb-lapraces:server:GetTrackData', false, data.RaceId)
    TrackData.CreatorData = CreatorData
    cb(TrackData)
end)

RegisterNUICallback('SetupRace', function(data, cb)
    TriggerServerEvent('qb-lapraces:server:SetupRace', data.RaceId, tonumber(data.AmountOfLaps))
    cb('ok')
end)

RegisterNUICallback('HasCreatedRace', function(_, cb)
    local hasCreated = lib.callback.await('qb-lapraces:server:HasCreatedRace', false)
    cb(hasCreated)
end)

RegisterNUICallback('IsInRace', function(_, cb)
    local inRace = exports.qbx_lapraces:IsInRace()
    cb(inRace)
end)

RegisterNUICallback('IsAuthorizedToCreateRaces', function(data, cb)
    local isAuthorized, nameAvailable = lib.callback.await('qb-lapraces:server:IsAuthorizedToCreateRaces', false, data.TrackName)
    data = {
        IsAuthorized = isAuthorized,
        IsBusy = exports.qbx_lapraces:IsInEditor(),
        IsNameAvailable = nameAvailable,
    }
    cb(data)
end)

RegisterNUICallback('StartTrackEditor', function(data, cb)
    TriggerServerEvent('qb-lapraces:server:CreateLapRace', data.TrackName)
    cb('ok')
end)

RegisterNUICallback('GetRacingLeaderboards', function(_, cb)
    local races = lib.callback.await('qb-lapraces:server:GetRacingLeaderboards', false)
    cb(races)
end)

RegisterNUICallback('RaceDistanceCheck', function(data, cb)
    local raceData = lib.callback.await('qb-lapraces:server:GetRacingData', false, data.RaceId)
    if not raceData then
        exports.qbx_core:Notify('You have no races saved yet...', 'error' )
        return
    end
    local coords = GetEntityCoords(cache.ped)
    local checkpointcoords = raceData.Checkpoints[1].coords
    local dist = #(coords - vector3(checkpointcoords.x, checkpointcoords.y, checkpointcoords.z))
    if dist <= 115.0 then
        if data.Joined then
            TriggerEvent('qb-lapraces:client:WaitingDistanceCheck')
        end
        cb(true)
    else
        exports.qbx_core:Notify('You\'re too far away from the race. GPS has been set to the race.', 'error' )
        SetNewWaypoint(checkpointcoords.x, checkpointcoords.y)
        cb(false)
    end
end)

RegisterNUICallback('IsBusyCheck', function(data, cb)
    if data.check == 'editor' then
        cb(exports.qbx_lapraces:IsInEditor())
    else
        cb(exports.qbx_lapraces:IsInRace())
    end
end)

RegisterNUICallback('CanRaceSetup', function(_, cb)
    local canSetup = lib.callback.await('qb-lapraces:server:CanRaceSetup', false)
    cb(canSetup)
end)

RegisterNUICallback('GetPlayerHouses', function(_, cb)
    local houses = lib.callback.await('qb-phone:server:GetPlayerHouses', false)
    cb(houses)
end)

RegisterNUICallback('GetPlayerKeys', function(_, cb)
    local keys = lib.callback.await('qb-phone:server:GetHouseKeys', false)
    cb(keys)
end)

RegisterNUICallback('SetHouseLocation', function(data, cb)
    SetNewWaypoint(data.HouseData.HouseData.coords.enter.x, data.HouseData.HouseData.coords.enter.y)
    exports.qbx_core:Notify('GPS has been set to ' .. data.HouseData.HouseData.adress .. '!', 'success' )
    cb('ok')
end)

RegisterNUICallback('RemoveKeyholder', function(data, cb)
    TriggerServerEvent('qb-houses:server:removeHouseKey', data.HouseData.name, {
        citizenid = data.HolderData.citizenid,
        firstname = data.HolderData.charinfo.firstname,
        lastname = data.HolderData.charinfo.lastname,
    })
    cb('ok')
end)

RegisterNUICallback('TransferCid', function(data, cb)
    local transferedCid = data.newBsn
    local canTransfer = lib.callback.await('qb-phone:server:TransferCid', false, transferedCid, data.HouseData)
    cb(canTransfer)
end)

RegisterNUICallback('FetchPlayerHouses', function(data, cb)
    local result = lib.callback.await('qb-phone:server:MeosGetPlayerHouses', false, data.input)
    cb(result)
end)

RegisterNUICallback('SetGPSLocation', function(data, cb)
    SetNewWaypoint(data.coords.x, data.coords.y)
    exports.qbx_core:Notufy('GPS has been set!', 'success' )
    cb('ok')
end)

RegisterNUICallback('SetApartmentLocation', function(data, cb)
    local apartmentData = data.data.appartmentdata
    local typeData = apartmentConfig.locations[apartmentData.type]
    SetNewWaypoint(typeData.coords.enter.x, typeData.coords.enter.y)
    exports.qbx_core:Notify('GPS has been set!', 'success' )
    cb('ok')
end)

RegisterNUICallback('GetCurrentLawyers', function(_, cb)
    local lawyers = lib.callback.await('qb-phone:server:GetCurrentLawyers', false)
    cb(lawyers)
end)

RegisterNUICallback('SetupStoreApps', function(_, cb)
    local data = {
        StoreApps = config.storeApps,
        PhoneData = QBX.PlayerData.metadata.phonedata
    }
    cb(data)
end)

RegisterNUICallback('ClearMentions', function(_, cb)
    config.phoneApps.twitter.Alerts = 0
    SendNUIMessage({
        action = 'RefreshAppAlerts',
        AppData = config.phoneApps
    })
    TriggerServerEvent('qb-phone:server:SetPhoneAlerts', 'twitter', 0)
    SendNUIMessage({ action = 'RefreshAppAlerts', AppData = config.phoneApps })
    cb('ok')
end)

RegisterNUICallback('ClearGeneralAlerts', function(data, cb)
    SetTimeout(400, function()
        config.phoneApps[data.app].Alerts = 0
        SendNUIMessage({
            action = 'RefreshAppAlerts',
            AppData = config.phoneApps
        })
        TriggerServerEvent('qb-phone:server:SetPhoneAlerts', data.app, 0)
        SendNUIMessage({ action = 'RefreshAppAlerts', AppData = config.phoneApps })
        cb('ok')
    end)
end)

RegisterNUICallback('TransferMoney', function(data, cb)
    data.amount = tonumber(data.amount)
    if tonumber(PhoneData.PlayerData.money.bank) >= data.amount then
        local newAmount = PhoneData.PlayerData.money.bank - data.amount
        TriggerServerEvent('qb-phone:server:TransferMoney', data.iban, data.amount)
        local cbData = {
            CanTransfer = true,
            NewAmount = newAmount
        }
        cb(cbData)
    else
        local cbData = {
            CanTransfer = false,
            NewAmount = nil,
        }
        cb(cbData)
    end
end)

RegisterNUICallback('CanTransferMoney', function(data, cb)
    local amount = tonumber(data.amountOf)
    local iban = data.sendTo

    if (QBX.PlayerData.money.bank - amount) >= 0 then
        local transferd = lib.callback.await('qb-phone:server:CanTransferMoney', false, amount, iban)
        if transferd then
            cb({ TransferedMoney = true, NewBalance = (QBX.PlayerData.money.bank - amount) })
        else
            SendNUIMessage({
                action = 'PhoneNotification',
                PhoneNotify = {
                    timeout = 3000,
                    title = 'Bank',
                    text = 'Account does not exist!',
                    icon = 'fas fa-university',
                    color = '#ff0000',
                }
            })
            cb({ TransferedMoney = false })
        end
    else
        cb({ TransferedMoney = false })
    end
end)

RegisterNUICallback('GetMessagesChats', function(_, cb)
    local chats = lib.callback.await('qb-phone:server:GetContactPictures', false, PhoneData.Chats)
    cb(chats)
end)

RegisterNUICallback('callContact', function(data, cb)
    local canCall, isOnline = lib.callback.await('qb-phone:server:GetCallState', false, data.ContactData)
    local status = {
        CanCall = canCall,
        IsOnline = isOnline,
        InCall = PhoneData.CallData.InCall,
    }
    cb(status)
    if canCall and not status.InCall and (data.ContactData.number ~= PhoneData.PlayerData.charinfo.phone) then
        callContact(data.ContactData, data.Anonymous)
    end
end)

RegisterNUICallback('SendMessage', function(data, cb)
    local ChatMessage = data.ChatMessage
    local ChatDate = data.ChatDate
    local ChatNumber = data.ChatNumber
    local ChatTime = data.ChatTime
    local ChatType = data.ChatType
    local Pos = GetEntityCoords(cache.ped)
    local NumberKey = getKeyByNumber(ChatNumber)
    local ChatKey = getKeyByDate(NumberKey, ChatDate)
    if PhoneData.Chats[NumberKey] then
        if (PhoneData.Chats[NumberKey].messages == nil) then
            PhoneData.Chats[NumberKey].messages = {}
        end
        if PhoneData.Chats[NumberKey].messages[ChatKey] then
            if ChatType == 'message' then
                PhoneData.Chats[NumberKey].messages[ChatKey].messages[
                    #PhoneData.Chats[NumberKey].messages[ChatKey].messages + 1] = {
                    message = ChatMessage,
                    time = ChatTime,
                    sender = PhoneData.PlayerData.citizenid,
                    type = ChatType,
                    data = {},
                }
            elseif ChatType == 'location' then
                PhoneData.Chats[NumberKey].messages[ChatKey].messages[
                    #PhoneData.Chats[NumberKey].messages[ChatKey].messages + 1] = {
                    message = 'Shared Location',
                    time = ChatTime,
                    sender = PhoneData.PlayerData.citizenid,
                    type = ChatType,
                    data = {
                        x = Pos.x,
                        y = Pos.y,
                    },
                }
            elseif ChatType == 'picture' then
                PhoneData.Chats[NumberKey].messages[ChatKey].messages[
                    #PhoneData.Chats[NumberKey].messages[ChatKey].messages + 1] = {
                    message = 'Photo',
                    time = ChatTime,
                    sender = PhoneData.PlayerData.citizenid,
                    type = ChatType,
                    data = {
                        url = data.url
                    },
                }
            end
            TriggerServerEvent('qb-phone:server:UpdateMessages', PhoneData.Chats[NumberKey].messages, ChatNumber, false)
            NumberKey = getKeyByNumber(ChatNumber)
            reorganizeChats(NumberKey)
        else
            PhoneData.Chats[NumberKey].messages[#PhoneData.Chats[NumberKey].messages + 1] = {
                date = ChatDate,
                messages = {},
            }
            ChatKey = getKeyByDate(NumberKey, ChatDate)
            if ChatType == 'message' then
                PhoneData.Chats[NumberKey].messages[ChatKey].messages[
                    #PhoneData.Chats[NumberKey].messages[ChatKey].messages + 1] = {
                    message = ChatMessage,
                    time = ChatTime,
                    sender = PhoneData.PlayerData.citizenid,
                    type = ChatType,
                    data = {},
                }
            elseif ChatType == 'location' then
                PhoneData.Chats[NumberKey].messages[ChatDate].messages[
                    #PhoneData.Chats[NumberKey].messages[ChatDate].messages + 1] = {
                    message = 'Shared Location',
                    time = ChatTime,
                    sender = PhoneData.PlayerData.citizenid,
                    type = ChatType,
                    data = {
                        x = Pos.x,
                        y = Pos.y,
                    },
                }
            elseif ChatType == 'picture' then
                PhoneData.Chats[NumberKey].messages[ChatKey].messages[
                    #PhoneData.Chats[NumberKey].messages[ChatKey].messages + 1] = {
                    message = 'Photo',
                    time = ChatTime,
                    sender = PhoneData.PlayerData.citizenid,
                    type = ChatType,
                    data = {
                        url = data.url
                    },
                }
            end
            TriggerServerEvent('qb-phone:server:UpdateMessages', PhoneData.Chats[NumberKey].messages, ChatNumber, true)
            NumberKey = getKeyByNumber(ChatNumber)
            reorganizeChats(NumberKey)
        end
    else
        PhoneData.Chats[#PhoneData.Chats + 1] = {
            name = isNumberInContacts(ChatNumber),
            number = ChatNumber,
            messages = {},
        }
        NumberKey = getKeyByNumber(ChatNumber)
        PhoneData.Chats[NumberKey].messages[#PhoneData.Chats[NumberKey].messages + 1] = {
            date = ChatDate,
            messages = {},
        }
        ChatKey = getKeyByDate(NumberKey, ChatDate)
        if ChatType == 'message' then
            PhoneData.Chats[NumberKey].messages[ChatKey].messages[
                #PhoneData.Chats[NumberKey].messages[ChatKey].messages + 1] = {
                message = ChatMessage,
                time = ChatTime,
                sender = PhoneData.PlayerData.citizenid,
                type = ChatType,
                data = {},
            }
        elseif ChatType == 'location' then
            PhoneData.Chats[NumberKey].messages[ChatKey].messages[
                #PhoneData.Chats[NumberKey].messages[ChatKey].messages + 1] = {
                message = 'Shared Location',
                time = ChatTime,
                sender = PhoneData.PlayerData.citizenid,
                type = ChatType,
                data = {
                    x = Pos.x,
                    y = Pos.y,
                },
            }
        elseif ChatType == 'picture' then
            PhoneData.Chats[NumberKey].messages[ChatKey].messages[
                #PhoneData.Chats[NumberKey].messages[ChatKey].messages + 1] = {
                message = 'Photo',
                time = ChatTime,
                sender = PhoneData.PlayerData.citizenid,
                type = ChatType,
                data = {
                    url = data.url
                },
            }
        end
        TriggerServerEvent('qb-phone:server:UpdateMessages', PhoneData.Chats[NumberKey].messages, ChatNumber, true)
        NumberKey = getKeyByNumber(ChatNumber)
        reorganizeChats(NumberKey)
    end

    local chat = lib.callback.await('qb-phone:server:GetContactPictures', false, PhoneData.Chats[getKeyByNumber(ChatNumber)])
    SendNUIMessage({
        action = 'UpdateChat',
        chatData = chat,
        chatNumber = ChatNumber,
    })
    cb('ok')
end)

RegisterNUICallback('TakePhoto', function(_, cb)
    SetNuiFocus(false, false)
    CreateMobilePhone(1)
    CellCamActivate(true, true)
    local takePhoto = true
    while takePhoto do
        if IsControlJustPressed(1, 27) then -- Toogle Mode
            frontCam = not frontCam
            cellFrontCamActivate(frontCam)
        elseif IsControlJustPressed(1, 177) then -- CANCEL
            DestroyMobilePhone()
            CellCamActivate(false, false)
            cb(json.encode({ url = nil }))
            break
        elseif IsControlJustPressed(1, 176) then -- TAKE.. PIC
            local hook = lib.callback.await('qb-phone:server:GetWebhook', false)
            if not hook then return end
            exports['screenshot-basic']:requestScreenshotUpload(tostring(hook), 'files[]', function(data)
                local image = json.decode(data)
                DestroyMobilePhone()
                CellCamActivate(false, false)
                TriggerServerEvent('qb-phone:server:addImageToGallery', image.attachments[1].proxy_url)
                Wait(400)
                TriggerServerEvent('qb-phone:server:getImageFromGallery')
                cb(json.encode(image.attachments[1].proxy_url))
            end)
            takePhoto = false
        end
        HideHudComponentThisFrame(7)
        HideHudComponentThisFrame(8)
        HideHudComponentThisFrame(9)
        HideHudComponentThisFrame(6)
        HideHudComponentThisFrame(19)
        HideHudAndRadarThisFrame()
        EnableAllControlActions(0)
        Wait(0)
    end
    Wait(1000)
    openPhone()
end)

RegisterCommand('ping', function(_, args)
    if not args[1] then
        exports.qbx_core:Notify('You need to input a Player ID', 'error' )
    end

    TriggerServerEvent('qb-phone:server:sendPing', args[1])
end, false)

-- Handler Events

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    loadPhone()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PhoneData = {
        MetaData = {},
        isOpen = false,
        PlayerData = nil,
        Contacts = {},
        Tweets = {},
        MentionedTweets = {},
        Hashtags = {},
        Chats = {},
        Invoices = {},
        CallData = {},
        RecentCalls = {},
        Garage = {},
        Mails = {},
        Adverts = {},
        GarageVehicles = {},
        AnimationData = {
            lib = nil,
            anim = nil,
        },
        SuggestedContacts = {},
        CryptoTransactions = {},
    }
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    SendNUIMessage({
        action = 'UpdateApplications',
        JobData = JobInfo,
        applications = config.phoneApps
    })
end)

RegisterNetEvent('qb-phone:client:TransferMoney', function(amount, newMoney)
    PhoneData.PlayerData.money.bank = newMoney
    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'QBank',
            text = '&#36;' .. amount .. ' has been added to your account!',
            icon = 'fas fa-university',
            color = '#8c7ae6',
        }
    })
    SendNUIMessage({ action = 'UpdateBank', NewBalance = PhoneData.PlayerData.money.bank })
end)

-- RegisterNetEvent('qb-phone:client:UpdateTweetsDel', function(source, Tweets)
--     PhoneData.Tweets = Tweets
--     print(source)
--     print(PhoneData.PlayerData.source)
--     --local MyPlayerId = PhoneData.PlayerData.source
--     --GetPlayerServerId(PlayerPedId())
--     if source ~= MyPlayerId then
--         SendNUIMessage({
--             action = 'UpdateTweets',
--             Tweets = PhoneData.Tweets
--         })
--     end
-- end)

RegisterNetEvent('qb-phone:client:UpdateTweets', function(src, tweets, newTweetData, delete)
    PhoneData.Tweets = tweets
    local MyPlayerId = PhoneData.PlayerData.source
    if not delete then -- New Tweet
        if src ~= MyPlayerId then
            SendNUIMessage({
                action = 'PhoneNotification',
                PhoneNotify = {
                    title = 'New Tweet (@' .. newTweetData.firstName .. ' ' .. newTweetData.lastName .. ')',
                    text = 'A new tweet as been posted.',
                    icon = 'fab fa-twitter',
                    color = '#1DA1F2',
                },
            })
            SendNUIMessage({
                action = 'UpdateTweets',
                Tweets = PhoneData.Tweets
            })
        else
            SendNUIMessage({
                action = 'PhoneNotification',
                PhoneNotify = {
                    title = 'Twitter',
                    text = 'The Tweet has been posted!',
                    icon = 'fab fa-twitter',
                    color = '#1DA1F2',
                    timeout = 1000,
                },
            })
        end
    else -- Deleting a tweet
        if src == MyPlayerId then
            SendNUIMessage({
                action = 'PhoneNotification',
                PhoneNotify = {
                    title = 'Twitter',
                    text = 'The Tweet has been deleted!',
                    icon = 'fab fa-twitter',
                    color = '#1DA1F2',
                    timeout = 1000,
                },
            })
        end
        SendNUIMessage({
            action = 'UpdateTweets',
            Tweets = PhoneData.Tweets
        })
    end
end)

RegisterNetEvent('qb-phone:client:RaceNotify', function(message)
    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Racing',
            text = message,
            icon = 'fas fa-flag-checkered',
            color = '#353b48',
            timeout = 3500,
        },
    })
end)

RegisterNetEvent('qb-phone:client:AddRecentCall', function(data, time, type)
    PhoneData.RecentCalls[#PhoneData.RecentCalls + 1] = {
        name = isNumberInContacts(data.number),
        time = time,
        type = type,
        number = data.number,
        anonymous = data.anonymous
    }
    TriggerServerEvent('qb-phone:server:SetPhoneAlerts', 'phone')
    config.phoneApps.phone.Alerts = config.phoneApps.phone.Alerts + 1
    SendNUIMessage({
        action = 'RefreshAppAlerts',
        AppData = config.phoneApps
    })
end)

RegisterNetEvent('qb-phone-new:client:BankNotify', function(text)
    SendNUIMessage({
        action = 'PhoneNotification',
        NotifyData = {
            title = 'Bank',
            content = text,
            icon = 'fas fa-university',
            timeout = 3500,
            color = '#ff002f',
        },
    })
end)

RegisterNetEvent('qb-phone:client:NewMailNotify', function(mailData)
    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Mail',
            text = 'You received a new mail from ' .. mailData.sender,
            icon = 'fas fa-envelope',
            color = '#ff002f',
            timeout = 1500,
        },
    })
    config.phoneApps.mail.Alerts = config.phoneApps.mail.Alerts + 1
    TriggerServerEvent('qb-phone:server:SetPhoneAlerts', 'mail')
end)

RegisterNetEvent('qb-phone:client:UpdateMails', function(newMails)
    SendNUIMessage({
        action = 'UpdateMails',
        Mails = newMails
    })
    PhoneData.Mails = newMails
end)

RegisterNetEvent('qb-phone:client:UpdateAdvertsDel', function(adverts)
    PhoneData.Adverts = adverts
    SendNUIMessage({
        action = 'RefreshAdverts',
        Adverts = PhoneData.Adverts
    })
end)

RegisterNetEvent('qb-phone:client:UpdateAdverts', function(adverts, lastAd)
    PhoneData.Adverts = adverts
    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Advertisement',
            text = 'A new ad has been posted by ' .. lastAd,
            icon = 'fas fa-ad',
            color = '#ff8f1a',
            timeout = 2500,
        },
    })
    SendNUIMessage({
        action = 'RefreshAdverts',
        Adverts = PhoneData.Adverts
    })
end)

RegisterNetEvent('qb-phone:client:BillingEmail', function(data, paid, name)
    if paid then
        TriggerServerEvent('qb-phone:server:sendNewMail', {
            sender = 'Billing Department',
            subject = 'Invoice Paid',
            message = 'Invoice Has Been Paid From ' .. name .. ' In The Amount Of $' .. data.amount,
        })
    else
        TriggerServerEvent('qb-phone:server:sendNewMail', {
            sender = 'Billing Department',
            subject = 'Invoice Declined',
            message = 'Invoice Has Been Declined From ' .. name .. ' In The Amount Of $' .. data.amount,
        })
    end
end)

RegisterNetEvent('qb-phone:client:cancelCall', function()
    if PhoneData.CallData.CallType == 'ongoing' then
        SendNUIMessage({
            action = 'CancelOngoingCall'
        })
        exports['pma-voice']:removePlayerFromCall(PhoneData.CallData.CallId)
    end
    PhoneData.CallData.CallType = nil
    PhoneData.CallData.InCall = false
    PhoneData.CallData.AnsweredCall = false
    PhoneData.CallData.TargetData = {}

    if not PhoneData.isOpen then
        StopAnimTask(cache.ped, PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 2.5)
        DeletePhone()
        PhoneData.AnimationData.lib = nil
        PhoneData.AnimationData.anim = nil
    else
        PhoneData.AnimationData.lib = nil
        PhoneData.AnimationData.anim = nil
    end

    TriggerServerEvent('qb-phone:server:SetCallState', false)

    if not PhoneData.isOpen then
        SendNUIMessage({
            action = 'PhoneNotification',
            NotifyData = {
                title = 'Phone',
                content = 'The call has been ended',
                icon = 'fas fa-phone',
                timeout = 3500,
                color = '#e84118',
            },
        })
    else
        SendNUIMessage({
            action = 'PhoneNotification',
            PhoneNotify = {
                title = 'Phone',
                text = 'The call has been ended',
                icon = 'fas fa-phone',
                color = '#e84118',
            },
        })

        SendNUIMessage({
            action = 'SetupHomeCall',
            CallData = PhoneData.CallData,
        })

        SendNUIMessage({
            action = 'CancelOutgoingCall',
        })
    end
end)

RegisterNetEvent('qb-phone:client:GetCalled', function(CallerNumber, CallId, AnonymousCall)
    local RepeatCount = 0
    local CallData = {
        number = CallerNumber,
        name = isNumberInContacts(CallerNumber),
        anonymous = AnonymousCall
    }

    if AnonymousCall then
        CallData.name = 'Anonymous'
    end

    PhoneData.CallData.CallType = 'incoming'
    PhoneData.CallData.InCall = true
    PhoneData.CallData.AnsweredCall = false
    PhoneData.CallData.TargetData = CallData
    PhoneData.CallData.CallId = CallId

    TriggerServerEvent('qb-phone:server:SetCallState', true)

    SendNUIMessage({
        action = 'SetupHomeCall',
        CallData = PhoneData.CallData,
    })

    for _ = 1, config.callRepeats + 1, 1 do
        if not PhoneData.CallData.AnsweredCall then
            if RepeatCount + 1 ~= config.callRepeats + 1 then
                if PhoneData.CallData.InCall then
                    local HasPhone = lib.callback.await('qb-phone:server:HasPhone', false)
                    if HasPhone then
                        RepeatCount = RepeatCount + 1
                        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'ringing', 0.2)

                        if not PhoneData.isOpen then
                            SendNUIMessage({
                                action = 'IncomingCallAlert',
                                CallData = PhoneData.CallData.TargetData,
                                Canceled = false,
                                AnonymousCall = AnonymousCall,
                            })
                        end
                    end
                else
                    SendNUIMessage({
                        action = 'IncomingCallAlert',
                        CallData = PhoneData.CallData.TargetData,
                        Canceled = true,
                        AnonymousCall = AnonymousCall,
                    })
                    TriggerServerEvent('qb-phone:server:AddRecentCall', 'missed', CallData)
                    break
                end
                Wait(config.repeatTimeout)
            else
                SendNUIMessage({
                    action = 'IncomingCallAlert',
                    CallData = PhoneData.CallData.TargetData,
                    Canceled = true,
                    AnonymousCall = AnonymousCall,
                })
                TriggerServerEvent('qb-phone:server:AddRecentCall', 'missed', CallData)
                break
            end
        else
            TriggerServerEvent('qb-phone:server:AddRecentCall', 'missed', CallData)
            break
        end
    end
end)

RegisterNetEvent('qb-phone:client:UpdateMessages', function(ChatMessages, SenderNumber, New)
    local NumberKey = getKeyByNumber(SenderNumber)

    if New then
        PhoneData.Chats[#PhoneData.Chats + 1] = {
            name = isNumberInContacts(SenderNumber),
            number = SenderNumber,
            messages = {},
        }

        NumberKey = getKeyByNumber(SenderNumber)

        PhoneData.Chats[NumberKey] = {
            name = isNumberInContacts(SenderNumber),
            number = SenderNumber,
            messages = ChatMessages
        }

        if PhoneData.Chats[NumberKey].Unread then
            PhoneData.Chats[NumberKey].Unread = PhoneData.Chats[NumberKey].Unread + 1
        else
            PhoneData.Chats[NumberKey].Unread = 1
        end

        if PhoneData.isOpen then
            if SenderNumber ~= PhoneData.PlayerData.charinfo.phone then
                SendNUIMessage({
                    action = 'PhoneNotification',
                    PhoneNotify = {
                        title = 'Messages',
                        text = 'New message from ' .. isNumberInContacts(SenderNumber) .. '!',
                        icon = 'fab fa-comment',
                        color = '#25D366',
                        timeout = 1500,
                    },
                })
            else
                SendNUIMessage({
                    action = 'PhoneNotification',
                    PhoneNotify = {
                        title = 'Messages',
                        text = 'Messaged yourself',
                        icon = 'fab fa-comment',
                        color = '#25D366',
                        timeout = 4000,
                    },
                })
            end

            NumberKey = getKeyByNumber(SenderNumber)
            reorganizeChats(NumberKey)

            Wait(100)
            local Chats = lib.callback.await('qb-phone:server:GetContactPictures', false, PhoneData.Chats)
            SendNUIMessage({
                action = 'UpdateChat',
                chatData = Chats[getKeyByNumber(SenderNumber)],
                chatNumber = SenderNumber,
                Chats = Chats,
            })
        else
            SendNUIMessage({
                action = 'PhoneNotification',
                PhoneNotify = {
                    title = 'messages',
                    text = 'New message from ' .. isNumberInContacts(SenderNumber) .. '!',
                    icon = 'fab fa-comment',
                    color = '#25D366',
                    timeout = 3500,
                },
            })
            config.phoneApps.messages.Alerts = config.phoneApps.messages.Alerts + 1
            TriggerServerEvent('qb-phone:server:SetPhoneAlerts', 'messages')
        end
    else
        PhoneData.Chats[NumberKey].messages = ChatMessages

        if PhoneData.Chats[NumberKey].Unread then
            PhoneData.Chats[NumberKey].Unread = PhoneData.Chats[NumberKey].Unread + 1
        else
            PhoneData.Chats[NumberKey].Unread = 1
        end

        if PhoneData.isOpen then
            if SenderNumber ~= PhoneData.PlayerData.charinfo.phone then
                SendNUIMessage({
                    action = 'PhoneNotification',
                    PhoneNotify = {
                        title = 'Messages',
                        text = 'New message from ' .. isNumberInContacts(SenderNumber) .. '!',
                        icon = 'fab fa-comment',
                        color = '#25D366',
                        timeout = 1500,
                    },
                })
            else
                SendNUIMessage({
                    action = 'PhoneNotification',
                    PhoneNotify = {
                        title = 'Messages',
                        text = 'Messaged yourself',
                        icon = 'fab fa-comment',
                        color = '#25D366',
                        timeout = 4000,
                    },
                })
            end

            NumberKey = getKeyByNumber(SenderNumber)
            reorganizeChats(NumberKey)

            Wait(100)
            local Chats = lib.callback.await('qb-phone:server:GetContactPictures', false, PhoneData.Chats)
            SendNUIMessage({
                action = 'UpdateChat',
                chatData = Chats[getKeyByNumber(SenderNumber)],
                chatNumber = SenderNumber,
                Chats = Chats,
            })
        else
            SendNUIMessage({
                action = 'PhoneNotification',
                PhoneNotify = {
                    title = 'Messages',
                    text = 'New message from ' .. isNumberInContacts(SenderNumber) .. '!',
                    icon = 'fab fa-comment',
                    color = '#25D366',
                    timeout = 3500,
                },
            })

            NumberKey = getKeyByNumber(SenderNumber)
            reorganizeChats(NumberKey)

            config.phoneApps.messages.Alerts = config.phoneApps.messages.Alerts + 1
            TriggerServerEvent('qb-phone:server:SetPhoneAlerts', 'messages')
        end
    end
end)

RegisterNetEvent('qb-phone:client:RemoveBankMoney', function(amount)
    if amount > 0 then
        SendNUIMessage({
            action = 'PhoneNotification',
            PhoneNotify = {
                title = 'Bank',
                text = '$' .. amount .. ' has been removed from your balance!',
                icon = 'fas fa-university',
                color = '#ff002f',
                timeout = 3500,
            },
        })
    end
end)

RegisterNetEvent('qb-phone:RefreshPhone', function()
    loadPhone()
    SetTimeout(250, function()
        SendNUIMessage({
            action = 'RefreshAlerts',
            AppData = config.phoneApps,
        })
    end)
end)

RegisterNetEvent('qb-phone:client:AddTransaction', function(_, _, message, title)
    local data = {
        TransactionTitle = title,
        TransactionMessage = message,
    }
    PhoneData.CryptoTransactions[#PhoneData.CryptoTransactions + 1] = data
    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Crypto',
            text = message,
            icon = 'fas fa-chart-pie',
            color = '#04b543',
            timeout = 1500,
        },
    })
    SendNUIMessage({
        action = 'UpdateTransactions',
        CryptoTransactions = PhoneData.CryptoTransactions
    })

    TriggerServerEvent('qb-phone:server:AddTransaction', data)
end)

RegisterNetEvent('qb-phone:client:AddNewSuggestion', function(suggestionData)
    PhoneData.SuggestedContacts[#PhoneData.SuggestedContacts + 1] = suggestionData
    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Phone',
            text = 'You have a new suggested contact!',
            icon = 'fa fa-phone-alt',
            color = '#04b543',
            timeout = 1500,
        },
    })
    config.phoneApps.phone.Alerts = config.phoneApps.phone.Alerts + 1
    TriggerServerEvent('qb-phone:server:SetPhoneAlerts', 'phone', config.phoneApps.phone.Alerts)
end)

RegisterNetEvent('qb-phone:client:UpdateHashtags', function(handle, msgData)
    if PhoneData.Hashtags[handle] then
        PhoneData.Hashtags[handle].messages[#PhoneData.Hashtags[handle].messages + 1] = msgData
    else
        PhoneData.Hashtags[handle] = {
            hashtag = handle,
            messages = {}
        }
        PhoneData.Hashtags[handle].messages[#PhoneData.Hashtags[handle].messages + 1] = msgData
    end

    SendNUIMessage({
        action = 'UpdateHashtags',
        Hashtags = PhoneData.Hashtags,
    })
end)

RegisterNetEvent('qb-phone:client:answerCall', function()
    if (PhoneData.CallData.CallType == 'incoming' or PhoneData.CallData.CallType == 'outgoing') and PhoneData.CallData.InCall and not PhoneData.CallData.AnsweredCall then
        PhoneData.CallData.CallType = 'ongoing'
        PhoneData.CallData.AnsweredCall = true
        PhoneData.CallData.CallTime = 0

        SendNUIMessage({ action = 'answerCall', CallData = PhoneData.CallData })
        SendNUIMessage({ action = 'SetupHomeCall', CallData = PhoneData.CallData })

        TriggerServerEvent('qb-phone:server:SetCallState', true)

        local animation = PhoneData.isOpen and 'cellphone_text_to_call' or 'cellphone_call_listen_base'
        DoPhoneAnimation(animation)

        CreateThread(function()
            while true do
                if PhoneData.CallData.AnsweredCall then
                    PhoneData.CallData.CallTime = PhoneData.CallData.CallTime + 1
                    SendNUIMessage({
                        action = 'UpdateCallTime',
                        Time = PhoneData.CallData.CallTime,
                        Name = PhoneData.CallData.TargetData.name,
                    })
                else
                    break
                end

                Wait(1000)
            end
        end)
        exports['pma-voice']:addPlayerToCall(PhoneData.CallData.CallId)
    else
        PhoneData.CallData.InCall = false
        PhoneData.CallData.CallType = nil
        PhoneData.CallData.AnsweredCall = false

        SendNUIMessage({
            action = 'PhoneNotification',
            PhoneNotify = {
                title = 'Phone',
                text = 'You don\'t have a incoming call...',
                icon = 'fas fa-phone',
                color = '#e84118',
            },
        })
    end
end)

RegisterNetEvent('qb-phone:client:addPoliceAlert', function(alertData)
    if not (QBX.PlayerData.job.type == 'leo' and not QBX.PlayerData.job.onduty) then return end
    SendNUIMessage({
        action = 'AddPoliceAlert',
        alert = alertData,
    })
end)

RegisterNetEvent('qb-phone:client:GiveContactDetails', function()
    local player, _, distance = lib.getClosestPlayer(GetEntityCoords(cache.ped))
    if player ~= -1 and distance < 2.5 then
        local PlayerId = GetPlayerServerId(player)
        TriggerServerEvent('qb-phone:server:GiveContactDetails', PlayerId)
    else
        exports.qbx_core:Notify('No one nearby!', 'error')
    end
end)

RegisterNetEvent('qb-phone:client:UpdateLapraces', function()
    SendNUIMessage({
        action = 'UpdateRacingApp',
    })
end)

RegisterNetEvent('qb-phone:client:GetMentioned', function(TweetMessage, AppAlerts)
    config.phoneApps.twitter.Alerts = AppAlerts
    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'You have been mentioned in a Tweet!',
            text = TweetMessage.message,
            icon = 'fab fa-twitter',
            color = '#1DA1F2',
        }
    })

    TweetMessage = {
        firstName = TweetMessage.firstName,
        lastName = TweetMessage.lastName,
        message = escape_str(TweetMessage.message),
        time = TweetMessage.time,
        picture = TweetMessage.picture
    }

    PhoneData.MentionedTweets[#PhoneData.MentionedTweets + 1] = TweetMessage

    SendNUIMessage({
        action = 'RefreshAppAlerts',
        AppData = config.phoneApps
    })

    SendNUIMessage({
        action = 'UpdateMentionedTweets',
        Tweets = PhoneData.MentionedTweets
    })
end)

RegisterNetEvent('qb-phone:refreshImages', function(images)
    PhoneData.Images = images
end)

RegisterNetEvent('qb-phone:client:CustomNotification', function(title, text, icon, color, timeout) -- Send a PhoneNotification to the phone from anywhere
    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = title,
            text = text,
            icon = icon,
            color = color,
            timeout = timeout,
        },
    })
end)

CreateThread(function()
    Wait(500)
    loadPhone()
end)

CreateThread(function()
    while true do
        if PhoneData.isOpen then
            SendNUIMessage({
                action = 'UpdateTime',
                InGameTime = calculateTimeToDisplay(),
            })
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        if LocalPlayer.state.isLoggedIn then
            local pData = lib.callback.await('qb-phone:server:GetPhoneData', false)
            if pData.PlayerContacts and next(pData.PlayerContacts) then
                PhoneData.Contacts = pData.PlayerContacts
            end
            SendNUIMessage({
                action = 'RefreshContacts',
                Contacts = PhoneData.Contacts
            })
        end
    end
end)
