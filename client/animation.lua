local phoneProp = 0
local phoneModel = `prop_npc_phone_02`

local function checkAnimLoop()
    CreateThread(function()
        while PhoneData.AnimationData.lib and PhoneData.AnimationData.anim do
            if not IsEntityPlayingAnim(cache.ped, PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 3) then
                lib.requestAnimDict(PhoneData.AnimationData.lib, 5000)
                TaskPlayAnim(cache.ped, PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 3.0, 3.0, -1, 50, 0, false, false, false)
            end
            Wait(500)
        end
    end)
end

function NewPhoneProp()
	DeletePhone()
	lib.requestModel(phoneModel, 5000)
	phoneProp = CreateObject(phoneModel, 1.0, 1.0, 1.0, true, true, false)

	local bone = GetPedBoneIndex(cache.ped, 28422)
	if phoneModel == `prop_cs_phone_01` then
		AttachEntityToEntity(phoneProp, cache.ped, bone, 0.0, 0.0, 0.0, 50.0, 320.0, 50.0, true, true, false, false, 2, true)
	else
		AttachEntityToEntity(phoneProp, cache.ped, bone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
	end
end

function DeletePhone()
	if phoneProp ~= 0 then
		DeleteObject(phoneProp)
		phoneProp = 0
	end
end

function DoPhoneAnimation(anim)
    local animationLib = IsPedInAnyVehicle(cache.ped, false) and 'anim@cellphone@in_car@ps' or 'cellphone@'
    lib.requestAnimDict(animationLib, 5000)
    TaskPlayAnim(cache.ped, animationLib, anim, 3.0, 3.0, -1, 50, 0, false, false, false)

    PhoneData.AnimationData.lib = animationLib
    PhoneData.AnimationData.anim = anim

    checkAnimLoop()
end