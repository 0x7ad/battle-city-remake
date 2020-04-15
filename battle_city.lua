-- title:  Battle City Remake
-- author: Isshiki
-- desc:   A mini remake of Battle City in Lua and TIC-80
-- script: lua
-- credits: BearThorne for autopiloting and collision detection

-- system
local function mapType(x, y)
    if mget(x, y) == 33+0 then return 1 end -- brick
    if mget(x, y) == 33+1 then return 2 end -- iron
    if mget(x, y) == 33+2 then return 3 end -- bush
    if mget(x, y) == 33+3 then return 4 end -- water
    if mget(x, y) == 33+4 then return 5 end -- bullet
end

local function isSolid(x,y)
    return mapType(x,y)~=2
end

local function hitByBullet(x,y)
    return mapType(x,y)==5
end

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
end

local function newPlayer ()
    local player = newTank() --257 by default
    player.create_location_x = 10
    player.create_location_y = 15
    player.creation = function(self)
        Game.player = Game.player + 1
    end
    player.collision_check_h = function(self)
        return isSolid(self.x+self.vx,self.y+self.vy) or
        isSolid(self.x+(self.size-1)+self.vx,self.y+self.vy) or
        isSolid(self.x+self.vx,self.y+(self.size-1)+self.vy) or
        isSolid(self.x+(self.size-1)+self.vx,
                self.y+(self.size-1)+self.vy)
    end
    --todo
    player.collision_check_v = function(self)
        return isSolid(self.x+self.vx,self.y+self.vy) or
        isSolid(self.x+(self.size-1)+self.vx,self.y+self.vy) or
        isSolid(self.x+self.vx,self.y+(self.size-1)+self.vy) or
        isSolid(self.x+(self.size-1)+self.vx,
                self.y+(self.size-1)+self.vy)
    end

    player.update = function(self)
        if btn(2) then self.vx=-1; self.direction=3 --move and rotate
        elseif btn(3) then self.vx=1; self.direction=1 end
        if btn(0) then self.vy=-1; self.direction=0
        elseif btn(1) then self.vy=1; self.direction=2 end
        if self.collision_check_h() then self.vx = 0 end
    end
end

local function newStage(stage_number)
    return {
        results={0,0,0,0,0}, -- number of model 1, 2, 3, 4 and sum
        points=0,
        timer=0,
        enemy_container={},
        enemy_created=0,
        enemy_left=Game.enemy_number[stage_number],
        enemy=Game.enemy_number[stage_number], --number of rivals for each stage
    }
end

local function enemy_updater(stage)
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

Game={
    mode=0,
    time=0,
    player=0,--if there is a player
    enemy_number={5,10,15,20},
    stage=0,
    hiscore={0,0,0,0},
    movement_patterns={ --possible movement
        {x=0,y=-1}, --up
        {x=0,y=1},  --down
        {x=-1,y=0}, --left
        {x=1,y=0}   --right
    }
}

function TIC()
    if Game.mode==0 then
        cls()
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
    elseif Game.mode==1 then --game
        cls()          -- wipe out previous map
        map(0,0,30,17) -- draw new map for each stage
        local stage=newStage(Game.stage)

        if stage.timer==0 then -- once only, setup timer
            stage.timer=Game.time end

        if Game.player==0 then  -- once only, create player tank
            Player=newPlayer()
        else Player.update() end

        if stage.enemy_created~=stage.enemy and
        (Game.time-stage.timer)//120==0 then
            local enemy=newEnemy(358+Game.time%2*2) --random
            table.insert(stage.enemy_container,#stage.enemy_container+1,enemy)
            stage.enemy_count=stage.enemy_count+1
        end
        enemy_updater()
        if stage.enemy_left==0 then
            Game.mode=2
        end

    elseif Game.mode==2 then --summary page
        cls()
        print("HI-SCORE")
        print(Game.hiscore)
        print("STAGE")
        print(Game.stage)
        print(Game.hiscore[Game.stage])
        for i=0,3 do
            local points = 100*(i+1)*stage.results[i]
            spr() -- tank icon
            print(points)
            print("PTS")
            stage.points=stage.points+points
            stage.results[4]=stage.results[4]+stage.results[i]
        end
        print("TOTAL")
        print(stage.points)
        print(stage.results[4])

        spr(161+0,18+20*0,108,0,1) --[
        spr(Game.time%60//30*(161+1),18+20*1,108,0,1) --z
        spr(161+2,18+20*2,108,0,1) --]
        if btn(4) and Game.stage~=4 then
            Game.stage=Game.stage+1
            Game.mode=1
        else Game.mode=0 end
    end
    Game.time = Game.time + 1
end
