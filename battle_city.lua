-- title:  Battle City: A Mini Remake
-- author: Isshiki
-- desc:   A mini remake of Battle City in Lua and TIC-80
-- script: lua
-- credits: BearThorne for autopiloting and collision detection

-- system
Game={
    mode=0,
    time=0,
    screen_rows=17,
    screen_columns=30,
    screen_width=240,
    screen_height=136,
    player_count=0,--if there is a player
    player=nil,
    enemy_number={5,10,15,20},
    current_stage=1,
    stage_count=4,
    ingame=0,
    stage={},
    hiscore={0,0,0,0},
    sprites={
        player={normal=0,enchanced=0},
        enemy={level1=0,level2=0,level3=0,level4=0},
        effects={},
    },
    movement_patterns={ --possible movement
        {x=0,y=-1}, --up
        {x=0,y=1},  --down
        {x=-1,y=0}, --left
        {x=1,y=0}   --right
    },
    map_location={
        {x=00,y=0},
        {x=30,y=0},
        {x=60,y=0},
        {x=90,y=0},
        {x=120,y=0},
    }
}

local function mapType(cell_x, cell_y)
    if mget(cell_x, cell_y) == 0+0 then return 0 end -- empty
    if mget(cell_x, cell_y) == 33+0 then return 1 end -- brick
    if mget(cell_x, cell_y) == 33+1 then return 2 end -- iron
    if mget(cell_x, cell_y) == 33+2 then return 3 end -- bush
    if mget(cell_x, cell_y) == 33+3 then return 4 end -- water
    if mget(cell_x, cell_y) == 33+4 then return 5 end -- bullet
end

local function isSolid(x,y)
    print(mapType((x)//8,(y)//8)~=0 and mapType((x)//8,(y)//8)~=3 and "failed" or "passed",0,88)
    print("cellx "..(x//8).."celly"..(y//8),0,97)
    print("x "..x.."y"..y,0,106)
    return mapType((x)//8,(y)//8)~=0 and mapType((x)//8,(y)//8)~=3
end

local function hitByBullet(x,y)
    return mapType(x,y)==5
end

local function enemy_updater(stage) -- tables are passed by reference
    for id,enemy in pairs(stage.enemy_container) do

        local temp_x=enemy.x+enemy.movement.x --next move
        local temp_y=enemy.x+enemy.movement.y

        if isSolid(temp_x,temp_y) then
            enemy.movement=Game.movement_patterns[math.random(1,4)]
        else enemy.x=temp_x;enemy.y=temp_y end

        if hitByBullet(enemy.x,enemy.y) then
            table.remove(stage.enemy_container,id) end

        spr(385,enemy.x*16,enemy.y*16,0)
    end
end

local function stage_builder(current_stage)
    local stage_coordinate=Game.map_location[current_stage]
    local stagex=stage_coordinate.x
    local stagey=stage_coordinate.y
    for x=0,Game.screen_columns-1 do
        for y=0,Game.screen_rows-1 do
            local mirror_x=x+stagex
            local mirror_y=y+stagey
            local tile=mget(mirror_x,mirror_y)        
            mset(x,y,tile) --draw the map for the current stage
        end
    end
end

-- classes
local function newBullet(x,y,direction)
    return {
        x=x,
        y=y,
        vx=2,
        vy=3,
        update=function(self)
            spr(329,self.x,self.y)
        end,
        hit=function(self)
            spr(321,self.x,self.y)
        end,
    }
end
local Tank={
    id=257,
    lifetime=999,
    shoot_interval=5,
    created_at=Game.time,
    direction=Game.time%3; -- rotate parameter for spr
    x=0,
    y=0,
    vx=0,
    vy=0,
    movement=Game.movement_patterns[math.random(1,4)],
    -- shooting_range=10,
    size=16, --both length or width
}
function Tank:new(obj)
    local tank=obj or {}
    setmetatable(tank,self)
    self.__index=self
    return tank
end

function Tank:shoot()
    newBullet(self.x,self.y,self.direction)
end

function Tank:rotate()
    return true
end

function Tank:hit()
    spr(Game.timer%2*289)
    spr(Game.timer%2*291)
end

PlayerTank=Tank:new({create_location_x=10,
                    create_location_y=15,
                    rotate=0,
                    moving_v=false,
                    moving_h=false,})
function PlayerTank:generator()
    Game.player = Game.player + 1
end

function PlayerTank:collision_ahead() --arrow key code
    local direction=self.direction
    local x=Game.movement_patterns[direction+1].x
    local y=Game.movement_patterns[direction+1].y
    local next_x=self.x+x
    local next_y=self.y+y
    rect(next_x,next_y,8,8,4)
    print("mx:"..x.."; my:"..y,0,3)
    print("cx: "..self.x.."; cy: "..self.y,0,11)
    print("mget id: "..mget(self.x+x,self.y+y),0,20)
    print(isSolid(next_x,next_y) and "solid" or "not solid",0,29)
    return isSolid(next_x,next_y) or
            next_x<0 or -- boundaries
            next_y<0 or
            next_x>Game.screen_width or
            next_y>Game.screen_height
end

function PlayerTank:dir_to_rotate()
    if self.direction==1 then self.rotate=2
    elseif self.direction==2 then self.rotate=3
    elseif self.direction==3 then self.rotate=1
    elseif self.direction==0 then self.rotate=0 end
end

function PlayerTank:update()
    if (btn(1) or btn(0)) and self.moving_h==false then
        if btnp(0) then
            self.vy=-1
            self.direction=0
            self.moving_v=true
        elseif btnp(1) then
            self.vy=1
            self.direction=1
            self.moving_v=true end

        if self:collision_ahead() then self.vy=0 end
    else self.vy=0;self.moving_v=false end

    if (btn(2) or btn(3)) and self.moving_v==false then
        if btnp(2) then
            self.vx=-1
            self.direction=2
            self.moving_h=true
        elseif btnp(3) then
            self.vx=1
            self.direction=3
            self.moving_h=true end
        if self:collision_ahead() then self.vx=0 end
    else self.vx=0;self.moving_h=false end

    print(self.vy,8,65);print(self.vx,0,65)
    self:dir_to_rotate()
    self.x=self.x+self.vx
    self.y=self.y+self.vy
    local result=self:collision_ahead() and "can't pass" or "passed"
    print("check"..result,0,38)
    print("vx:"..self.vx.." vy:"..self.vy,0,47)
    -- visual effect
    if self.lifetime<30 then
        for i=0,8 do
            spr(481+i,self.x,self.y) end
    elseif self.lifetime<90 then
        spr(257,self.x,self.y,6,1,0,self.rotate,2,2)
        spr(Game.time%2*289,self.x,self.y,6,1,0,self.rotate,2,2)
    else spr(257,self.x,self.y,6,1,0,self.rotate,2,2)
        rectb(self.x,self.y,1,1,4)
        --id x y alpha scale flip rotate w h
    end
end

local function newTank(model)
    return {
        id=model or 257,
        shoot_interval=5,
        created_at=Game.time,
        direction=Game.time%3; -- rotate parameter for spr
        x,
        y,
        vx=0,
        vy=0,
        movement=Game.movement_patterns[math.random(1,4)],
        -- shooting_range=10,
        size=16, --both length or width
        shoot = function(self)
            newBullet(self.x,self.y,self.direction)
        end,
        rotate=function(self)
            return true
        end,
        hit=function(self)
            
            spr(Game.timer%2*289)
            spr(Game.timer%2*291)
        end
    }
end

local function newEnemy (model)
    local enemy = newTank(model)
    enemy.create_location_x=math.random(22,28)
    enemy.create_location_y=0 -- somewhere around the top right corner
    enemy.vx=1
    enemy.vy=1
    enemy.autopilot = function(self)
        return self
    end
    enemy.autoshoot = function(self)
        return self
    end
    return enemy
end

local function newStage(stage_number)
    return {
        results={0,0,0,0,0}, -- number of model 1, 2, 3, 4 and sum
        points=0,
        timer=0,
        enemy_count=0,
        enemy_container={},
        enemy_created=0,
        enemy_left=Game.enemy_number[stage_number],
        enemy=Game.enemy_number[stage_number], --number of rivals for each stage
    }
end

function TIC()
    if Game.mode==0 then
        cls(0)
        spr(129+0,18+32*0,20,0,4) --B
        spr(129+1,18+32*1,20,0,4) --A
        spr(129+2,18+32*2,20,0,4) --T
        spr(129+3,18+32*3,20,0,4) --T
        spr(129+4,18+32*4,20,0,4) --L
        spr(129+5,18+32*5,20,0,4) --E
        --  id,x,y,alpha,scale
        spr(145+0,18+32*0,54,0,4) --C
        spr(145+1,18+32*1,54,0,4) --I
        spr(145+2,18+32*2,54,0,4) --T
        spr(145+3,18+32*3,54,0,4) --Y
        print("Mini Remake",18,88,15,0,2)
        --     text,x,y,color,fixed,scale
        spr(161+0,18+20*0,108,0,1) --[
        spr(Game.time%60//30*(161+1),18+20*1,108,0,1) --z
        spr(161+2,18+20*2,108,0,1) --]
        -- start
        if btn(4) then Game.mode = 1 end
    elseif Game.mode==1 then
        --cls(3)          -- wipe out previous map
        --stage_builder(Game.current_stage) -- draw new map for each stage
        --map()
        Game.mode=2
    elseif Game.mode==2 then --game
        cls()
        map(Game.map_location[Game.current_stage].x, --static content
            Game.map_location[Game.current_stage].y)
            --[[
        if Game.ingame==0 then
            Game.stage=newStage(Game.current_stage)
            Game.ingame=1 end

        if Game.stage.timer==0 then -- once only, setup timer
            Game.stage.timer=Game.time end--]]

        if Game.player_count==0 then  -- once only, create player tank
            Game.player=PlayerTank:new()
            Game.player_count=Game.player_count+1
        else Game.player:update() end --WARNING call a method using : instead of dot
        --[[
        if Game.stage.enemy_created~=Game.stage.enemy and
        (Game.time-Game.stage.timer)//120==0 then
            local enemy=newEnemy(358+Game.time%2*2) --random
            table.insert(Game.stage.enemy_container,#Game.stage.enemy_container+1,enemy)
            Game.stage.enemy_count=Game.stage.enemy_count+1
        end
        enemy_updater(Game.stage)
        if Game.stage.enemy_left==0 then
            Game.mode=2
        end
        --]]
    elseif Game.mode==3 then --summary page
        cls()
        print("HI-SCORE")
        print(Game.hiscore)
        print("STAGE")
        print(Game.current_stage)
        print(Game.hiscore[Game.current_stage])
        for i=0,3 do
            local points = 100*(i+1)*Game.stage.results[i]
            spr() -- tank icon
            print(points)
            print("PTS")
            Game.stage.points=Game.stage.points+points
            Game.stage.results[4]=Game.stage.results[4]+Game.stage.results[i]
        end
        print("TOTAL")
        print(Game.stage.points)
        print(Game.stage.results[4])

        spr(161+0,18+20*0,108,0,1) --[
        spr(Game.time%60//30*(161+1),18+20*1,108,0,1) --z
        spr(161+2,18+20*2,108,0,1) --]
        if btn(4) and Game.current_stage~=Game.stage_count then
            --Game.current_stage=Game.current_stage+1
            Game.mode=1
        else Game.mode=0 end
    end
    Game.time=Game.time+1
end
