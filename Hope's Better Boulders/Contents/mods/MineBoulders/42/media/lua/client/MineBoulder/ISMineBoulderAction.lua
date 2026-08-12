require "TimedActions/ISBaseTimedAction"

ISMineBoulderAction = ISBaseTimedAction:derive("ISMineBoulderAction");

function ISMineBoulderAction:isValid()
    local pickAxe = self.character:getPrimaryHandItem()
    if not pickAxe or pickAxe:isBroken() or not (pickAxe:hasTag(ItemTag.PICK_AXE) or pickAxe:getType() == "PickAxe") then
        return false
    end
    if isClient() and self.started then
        return true
    end
    local diffX = math.abs(self.boulder:getSquare():getX() + 0.5 - self.character:getX());
    local diffY = math.abs(self.boulder:getSquare():getY() + 0.5 - self.character:getY());
    return self.boulder:getObjectIndex() ~= -1 and (diffX <= 1.6 and diffY <= 1.6);
end

function ISMineBoulderAction:waitToStart()
    self.character:faceThisObject(self.boulder)
    return self.character:shouldBeTurning()
end

function ISMineBoulderAction:update()
    self.character:faceThisObject(self.boulder);
    self.spriteFrame = self.character:getSpriteDef():getFrame();
    self.character:setMetabolicTarget(Metabolics.HeavyWork);
end

function ISMineBoulderAction:start()
    if self.boulder == nil then return end
    
    self.pickAxe = self.character:getPrimaryHandItem();
    if self.character:isSecondaryHandItem(self.pickAxe) then
        self:setActionAnim("DestroyFloor")
    else
        self:setActionAnim("HammerOre")
    end
    
    addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 20, 10);
    self.started = true
end

function ISMineBoulderAction:stop()
    ISBaseTimedAction.stop(self);
end

function ISMineBoulderAction:perform()
    if not isClient() then
        ISInventoryPage.renderDirty = true
    end
    self.character:playSound("CraftMineralDepositRemove")
    ISBaseTimedAction.perform(self);
end

function ISMineBoulderAction:complete()
    if self.boulder == nil then return end
    
    local roll = 1
    if self.boulderSize == 1 then
        roll = 1
    elseif self.boulderSize == 2 then
        roll = ZombRand(3, 5)
    else
        roll = ZombRand(6, 8)
    end
    
    for i = 1, roll do
        self.boulder:getSquare():SpawnWorldInventoryItem("Base.Stone2", 0.0, 0.0, 0.0)
    end
    
    -- Remove the boulder from the world
    self.boulder:getSquare():transmitRemoveItemFromSquare(self.boulder)
    
    addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 10, 10);
    
    -- Reduce pickaxe condition
    if not self.character:isBuildCheat() and self.pickAxe then
        self.pickAxe:damageCheck(0, 2, false)
    end
    
    return true
end

function ISMineBoulderAction:useEndurance()
    if self.pickAxe then
        -- Fatigue amount scales based on boulder size (e.g. Small: 0.02, Medium: 0.04, Large: 0.06)
        local sizeMod = self.boulderSize * 0.02
        local weight = self.pickAxe:getWeight() or 3.0
        local fatigueWeapon = self.pickAxe:getFatigueMod(self.character) or 1.0
        local fatigueChar = self.character:getFatigueMod() or 1.0
        local endurMod = self.pickAxe:getEnduranceMod() or 1.0
        
        local use = weight * fatigueWeapon * fatigueChar * endurMod * sizeMod
        
        if CharacterStat and CharacterStat.ENDURANCE then
            self.character:getStats():remove(CharacterStat.ENDURANCE, use)
        else
            self.character:getStats():setEndurance(self.character:getStats():getEndurance() - use)
        end
    end
end

function ISMineBoulderAction:animEvent(event, parameter)
    if event == "PlaySwingSound" and self.pickAxe then
        self.character:playSound(self.pickAxe:getSwingSound())
    end
    if event == "PlayHitSound" and self.pickAxe then
        -- Add strain directly to arms and back to guarantee muscle fatigue
        local strain = self.boulderSize * 0.3
        self.character:addArmMuscleStrain(strain)
        self.character:addBackMuscleStrain(strain)
        
        self.character:playSound("CraftMineralDepositHit")
        self:useEndurance()
    end
end

function ISMineBoulderAction:new(character, boulder)
    local o = ISBaseTimedAction.new(self, character)
    o.boulder = boulder;
    
    local spriteName = nil
    if boulder.getSprite and boulder:getSprite() then
        spriteName = boulder:getSprite():getName()
    end
    if not spriteName and boulder.getSpriteName then
        spriteName = boulder:getSpriteName()
    end
    
    o.boulderSize = 1 -- 1: Small, 2: Medium, 3: Large
    if spriteName then
        local num = tonumber(string.match(spriteName, "boulders_(%d+)"))
        if num then
            if (num >= 8 and num <= 15) or (num >= 48 and num <= 55) then
                o.boulderSize = 1
            elseif (num >= 0 and num <= 7) or (num >= 40 and num <= 47) or (num >= 56 and num <= 63) then
                o.boulderSize = 2
            else
                o.boulderSize = 3
            end
        end
    end
    
    -- Mining time depends on boulder size (e.g. 200, 400, 600)
    o.maxTime = (o.boulderSize * 200) - (character:getPerkLevel(Perks.Strength) * 15);
    if character:isTimedActionInstant() then
        o.maxTime = 1;
    end
    
    o.spriteFrame = 0
    o.caloriesModifier = 8;
    o.pickAxe = character:getPrimaryHandItem();
    return o;
end
