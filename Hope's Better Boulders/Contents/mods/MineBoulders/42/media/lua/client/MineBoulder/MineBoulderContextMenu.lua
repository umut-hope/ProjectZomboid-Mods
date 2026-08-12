MineBoulderContextMenu = {}

-- Check if the object is a boulder by looking at its sprite name
local function isBoulder(object)
    if not object then return false end
    
    local spriteName = nil
    if object.getSprite and object:getSprite() then
        spriteName = object:getSprite():getName()
    end
    if not spriteName and object.getSpriteName then
        spriteName = object:getSpriteName()
    end
    
    if not spriteName then return false end
    
    -- Captures sprites from boulders_0 to boulders_55
    if luautils.stringStarts(spriteName, "boulders_") then
        return true
    end
    
    return false
end

-- Check if the player has a pickaxe in their hands or inventory
local function getPickAxe(player)
    local inv = player:getInventory()
    local item = inv:getFirstEvalRecurse(function(item)
        if item:isBroken() then return false end
        return item:hasTag(ItemTag.PICK_AXE) or item:getType() == "PickAxe"
    end)
    return item
end

local function onMineBoulder(worldobjects, boulder, player, pickAxe)
    if luautils.walkAdj(player, boulder:getSquare()) then
        -- If the pickaxe is not in both hands, force equip it in two hands
        if player:getPrimaryHandItem() ~= pickAxe or player:getSecondaryHandItem() ~= pickAxe then
            ISWorldObjectContextMenu.transferIfNeeded(player, pickAxe)
            ISTimedActionQueue.add(ISEquipWeaponAction:new(player, pickAxe, 50, true, true))
        end
        -- Then add the mining timed action to the queue
        ISTimedActionQueue.add(ISMineBoulderAction:new(player, boulder))
    end
end

MineBoulderContextMenu.onFillWorldObjectContextMenu = function(playerNum, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end

    local player = getSpecificPlayer(playerNum)
    local boulder = nil
    
    -- Scan objects in the clicked square and find a boulder
    for _, obj in ipairs(worldobjects) do
        local square = obj:getSquare()
        if square then
            for i=0, square:getObjects():size()-1 do
                local squareObj = square:getObjects():get(i)
                if isBoulder(squareObj) then
                    boulder = squareObj
                    break
                end
            end
        end
        if boulder then break end
    end
    
    -- If there is no boulder, do not add to the menu
    if not boulder then
        return
    end
    
    -- Find the pickaxe
    local pickAxe = getPickAxe(player)
    
    -- Add option to the context menu
    local option = context:addOption("Mine Boulder", worldobjects, onMineBoulder, boulder, player, pickAxe)
    
    -- If no pickaxe, make the option red (disabled) and show the requirement tooltip
    if not pickAxe then
        option.notAvailable = true
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip:setName("Mine Boulder")
        tooltip.description = getText("ContextMenu_Require", getItemNameFromFullType("Base.PickAxe"))
        option.toolTip = tooltip
    end
end

Events.OnFillWorldObjectContextMenu.Add(MineBoulderContextMenu.onFillWorldObjectContextMenu)
