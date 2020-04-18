-- title:  Battle City: A Mini Remake
-- author: Isshiki
-- desc:   A mini remake of Battle City in Lua and TIC-80
-- script: lua
-- credits: BearThorne for autopiloting and collision detection

-- system
Game={
    mode=0,
    time=0,
    player_generation_location_x=10,
    player_generation_location_y=12,
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
    },
    bullets={},
    --tank_models={257,259,261,263,},
    player_model=200,
    dynamic_content_coordinates={
        {-- for the first stage
            {1,{minx=2,maxx=4}}, --for the first row
            {3,{minx=2,maxx=4}}, --for the third row
        },
    }
}

Stage={
    enemy_container={},
    enemy_count=1,
    finishing_timestamp=0,
    finished=false,
    tank_coordinates={},--1 for player
    --do not record bullets for now
}

local Movable={
    x=0,
    y=0,
    vx=0,
    vy=0,
    direction=0,
    rotate=0,
    size=0,-- as w always equals h
    explosion_timestamp=0,
    is_explosive=false,
}

function Movable:new(obj)
    local movable_object=obj or {}
    setmetatable(movable_object,self)
    self.__index=self
    return movable_object
end

function Movable:dir_to_rotate()
    if self.direction==1 then self.rotate=2
    elseif self.direction==2 then self.rotate=3
    elseif self.direction==3 then self.rotate=1
    elseif self.direction==0 then self.rotate=0 end
end
local function mapType(cell_x, cell_y)
    if mget(cell_x, cell_y) == 0+0  then return 0 end -- empty
    if mget(cell_x, cell_y) == 33+0 then return 1 end -- brick
    if mget(cell_x, cell_y) == 33+1 then return 2 end -- iron
    if mget(cell_x, cell_y) == 33+2 then return 3 end -- bush
    if mget(cell_x, cell_y) == 33+3 then return 4 end -- water
    if mget(cell_x, cell_y) == 33+4 then return 5 end -- bullet
    if mget(cell_x, cell_y) >= 170  then return 6 end -- tanks
end

local function isSolid(x,y)
    return mapType((x)//8,(y)//8)~=0 and mapType((x)//8,(y)//8)~=3
end

local function isExplodable(x,y)
    local result=mget((x)//8,(y)//8)
    return result>= 170 or result==33 end

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
local Bullet=Movable:new({
    size=8,
    speed=2,
    is_explosive=true,
    exploding=true,
    explodable_coordinates={},
})

function Bullet:new(obj)
    local bullet=obj or {}
    setmetatable(bullet,self)
    self.__index=self
    return bullet
end

function Movable:dir_to_speed()
    self.vx=Game.movement_patterns[self.direction+1].x*self.speed
    self.vy=Game.movement_patterns[self.direction+1].y*self.speed
end

function Bullet:explode()
    -- explode an adjacent tile of the same type
    for _,tile in pairs(self.explodable_coordinates) do
        mset((tile.x)//8, (tile.y)//8,0)
    end
end

function Bullet:update(id)
    if self:collision_ahead() then
        self.vx=0
        self.vy=0
        if self.explosion_timestamp==0 then --move to explode
        self.explosion_timestamp=Game.time end
    else spr(329,self.x,self.y,0,1,0,self.rotate,1,1) end

    if self.exploding==true then self:explode();self.exploding=false end
    if self.explosion_timestamp~=0 and Game.time-self.explosion_timestamp<20 then
        local offset1=self.size
        local offset2=4 -- to align different sprites
        if self.direction==1 then
            spr(321+Game.time%20//10*2,self.x-offset1+offset2,self.y,0,1,0,self.rotate,2,2)
        elseif self.direction==3 then
            spr(321+Game.time%20//10*2,self.x,self.y-offset1+offset2,0,1,0,self.rotate,2,2)
        elseif self.direction==0 then
            spr(321+Game.time%20//10*2,self.x-offset1+offset2,self.y-offset1,0,1,0,self.rotate,2,2)
        else
            spr(321+Game.time%20//10*2,self.x-offset1,self.y-offset1+offset2,0,1,0,self.rotate,2,2)
        end
    elseif Game.time-self.explosion_timestamp>=20 and self.explosion_timestamp~=0 then
        table.remove(Game.bullets,id) end
    self.x=self.x+self.vx
    self.y=self.y+self.vy
end

local Tank=Movable:new({
    id=0,
    lifetime=0,
    animation_time=2*60,
    shoot_interval_cd=1*60,
    shoot_interval=0.3*60,
    last_shoot=0,
    speed=1,
    flying_bullets=0,
    cd_mode=false,
    created_at=0,
    can_move=false,
    direction=0, -- rotate parameter for spr
    movement=Game.movement_patterns[math.random(1,4)],
    -- shooting_range=10,
    size=16, --both length or width
    tank_id=0,
})
function Tank:new(obj)
    local tank=obj or {}
    setmetatable(tank,self)
    self.__index=self
    return tank
end

local PlayerTank=Tank:new({x=Game.player_generation_location_x,
                            y=Game.player_generation_location_y,
                            id=Game.player_model,
                            control_sequence={},--to store key sequence
                            moving_v=false,
                            moving_h=false,
                            type="player"})
function Tank:timer()
    if self.created_at==0 then
        self.created_at=Game.time
    else self.lifetime=Game.time-self.created_at end
end

function Movable:tank_ahead()
    local other_x=0
    local other_y=0
    local tank_size=16
    local direction=self.direction
    local vx=Game.movement_patterns[direction+1].x*2 -- in case two tanks run toward each other
    local vy=Game.movement_patterns[direction+1].y*2

    local result=false

    for _,tank in pairs(Stage.tank_coordinates) do
        print("from x: "..self.x.." y: "..self.y,0,self.tank_id*9)
        if tank[1]~=self.tank_id then
            other_x=tank[2].x
            other_y=tank[2].y
            print("testing x: "..other_x.." y: "..other_y,100,self.tank_id*9)
            if self.direction==0 then
                if self.y+vy<=other_y+(tank_size-1) and not (self.x>other_x+(tank_size-1) or self.x+(tank_size-1)<other_x) then result=true end
            elseif self.direction==1 then
                if self.y+vy+(tank_size-1)>=other_y and not (self.x>other_x+(tank_size-1) or self.x+(tank_size-1)<other_x) then result=true end
            elseif self.direction==2 then
                if self.x+vx<=other_x+(tank_size-1) and not (self.y>other_y+(tank_size-1) or self.y+(tank_size-1)<other_y) then result=true end
            elseif self.direction==3 then
                if self.x+vx+(tank_size-1)>=other_x and not (self.y>other_y+(tank_size-1) or self.y+(tank_size-1)<other_y) then result=true end
            end
        end
    end
    return result
end

function Movable:register_coordinate()
    local coordinates={x=self.x,y=self.y}
    if self.type=="player" then
        local tank={self.tank_id,coordinates}
        table.remove(Stage.tank_coordinates,1)
        table.insert(Stage.tank_coordinates,1,tank)
    elseif self.type=="enemy" then
        for i,tank in pairs(Stage.tank_coordinates) do
            if tank[1]==self.tank_id then
                local enemy={self.tank_id,coordinates}
                table.remove(Stage.tank_coordinates,i)
                table.insert(Stage.tank_coordinates,i,enemy)
            end
        end
    end
end
function Movable:collision_ahead() --arrow key code
    local direction=self.direction
    local result_a=false
    local result_b=false
    local corner_a={x=self.x,y=self.y} --top left 0 and 2
    local corner_b={x=self.x+self.size-1,y=self.y} -- top right 0 and 3
    local corner_c={x=self.x,y=self.y+self.size-1} -- bottom left 2 and 1
    local corner_d={x=self.x+self.size-1,y=self.y+self.size-1} --bottom right 1 and 3
    local vx=Game.movement_patterns[direction+1].x
    local vy=Game.movement_patterns[direction+1].y
    if direction==0 or direction==2 then
        --facing up, test corner_a and corner_b
        local next_x=corner_a.x+vx
        local next_y=corner_a.y+vy
        if self.is_explosive and isExplodable(next_x,next_y) then
            local temp={x=next_x,y=next_y}
            self.exploding=true
            table.insert(self.explodable_coordinates, #self.explodable_coordinates+1,temp)
        end
        if next_x<0 or next_y<0 then return true end
        result_a=isSolid(next_x,next_y)
    else
        local next_x=corner_d.x+vx
        local next_y=corner_d.y+vy
        if self.is_explosive and isExplodable(next_x,next_y) then
            local temp={x=next_x,y=next_y}
            self.exploding=true
            table.insert(self.explodable_coordinates, #self.explodable_coordinates+1,temp)
        end
        if next_x>Game.screen_width or next_y>Game.screen_height then
            return true end
        result_a=isSolid(next_x,next_y)
    end

    if direction==0 or direction==3 then
        local next_x=corner_b.x+vx
        local next_y=corner_b.y+vy
        result_b=isSolid(next_x,next_y)
        if self.is_explosive and isExplodable(next_x,next_y) then
            local temp={x=next_x,y=next_y}
            self.exploding=true
            table.insert(self.explodable_coordinates, #self.explodable_coordinates+1,temp)
        end
        return result_a or result_b
    else local next_x=corner_c.x+vx
        local next_y=corner_c.y+vy
        result_b=isSolid(next_x,next_y)
        if self.is_explosive and isExplodable(next_x,next_y) then
            local temp={x=next_x,y=next_y}
            self.exploding=true
            table.insert(self.explodable_coordinates, #self.explodable_coordinates+1,temp)
        end
        return result_a or result_b
    end
end

function Tank:animate()
    -- visual effect
    if self.lifetime<=70 then --it takes 10*7 frames to finish
        spr(481+self.lifetime//10*2,self.x,self.y,0,1,0,self.rotate,2,2)

    elseif self.lifetime<3*60 then
        spr(self.id,self.x,self.y,6,1,0,self.rotate,2,2)
        spr(Game.time%2*2+289,self.x,self.y,0,1,0,self.rotate,2,2)

    else spr(self.id,self.x,self.y,6,1,0,self.rotate,2,2) end
    --id x y alpha scale flip rotate w h 
end

function PlayerTank:update()
    self:timer()
    self:animate()
    self:register_coordinate()
    if self.lifetime>self.animation_time then

        local temp_dir=0
        if btnp(0) then
            temp_dir=0
            table.insert(self.control_sequence,#self.control_sequence+1,temp_dir)
        elseif btnp(1) then
            temp_dir=1
            table.insert(self.control_sequence,#self.control_sequence+1,temp_dir)
        elseif btnp(2) then
            temp_dir=2
            table.insert(self.control_sequence,#self.control_sequence+1,temp_dir)
        elseif btnp(3) then
            temp_dir=3
            table.insert(self.control_sequence,#self.control_sequence+1,temp_dir)
        end
        
        if #self.control_sequence==0 then
            self.vx=0
            self.vy=0
        else
            self.direction=self.control_sequence[#self.control_sequence]
            self:dir_to_rotate()
            if (not self:collision_ahead()) and (not self:tank_ahead()) then
                self:dir_to_speed()
                self.x=self.x+self.vx
                self.y=self.y+self.vy
            end
        end
    
        for i=0,3 do
            if not btn(i) then
                for id,value in pairs(self.control_sequence) do
                    if value==i then table.remove(self.control_sequence,id) end
                end
            end
        end
        if btnp(4) then
            self:shoot()
        end
    end
end

local EnemyTank=Tank:new({id=385,type="enemy"})

function Tank:shoot()
    if self.flying_bullets>2 then self.cd_mode=true end

    if self.cd_mode then
        if Game.time-self.last_shoot>self.shoot_interval_cd then
            self.cd_mode=false

            local temp={}
            if self.direction==0 then
                temp={
                    x=self.x+5,
                    y=self.y,
                    direction=self.direction
                }
            elseif self.direction==1 then
                temp={
                    x=self.x+3,
                    y=self.y+15,
                    direction=self.direction
                }
            elseif self.direction==2 then
                temp={
                    x=self.x,
                    y=self.y+3,
                    direction=self.direction
                }
            elseif self.direction==3 then
                temp={
                    x=self.x+15,
                    y=self.y+5,
                    direction=self.direction
                }
            end
            local bullet=Bullet:new(temp)
            bullet:dir_to_rotate()
            bullet:dir_to_speed()
            table.insert(Game.bullets,#Game.bullets+1,bullet)
            self.last_shoot=Game.time
            self.flying_bullets=1
        end
    elseif Game.time-self.last_shoot>self.shoot_interval then
        local temp={}
        if self.direction==0 then
            temp={
                x=self.x+5,
                y=self.y,
                direction=self.direction
            }
        elseif self.direction==1 then
            temp={
                x=self.x+3,
                y=self.y+15,
                direction=self.direction
            }
        elseif self.direction==2 then
            temp={
                x=self.x,
                y=self.y+3,
                direction=self.direction
            }
        elseif self.direction==3 then
            temp={
                x=self.x+15,
                y=self.y+5,
                direction=self.direction
            }
        end
        local bullet=Bullet:new(temp)
        bullet:dir_to_rotate()
        bullet:dir_to_speed()
        table.insert(Game.bullets,#Game.bullets+1,bullet)
        self.last_shoot=Game.time
        --if Game.time-self.last_shoot>1*60 then self.flying_bullets=self.flying_bullets+1 end
        self.flying_bullets=self.flying_bullets+1
    end
end

function EnemyTank:new(obj)
    local enemy=obj or {}
    setmetatable(enemy,self)
    self.__index=self
    return enemy
end

function EnemyTank:selectpath()
    local h_blocked=false
    local v_blocked=false
    if self.possible_directions[1]==1 or self.possible_directions[2]==1 then h_blocked=true end --0 1
    if self.possible_directions[3]==1 or self.possible_directions[4]==1 then v_blocked=true end --2 3

    if v_blocked and h_blocked then
        local unblocked_ways={}
        for key,dir in pairs(self.possible_directions) do
            if dir==0 then -- log the unblocked ways
                table.insert(unblocked_ways,#unblocked_ways+1,key)
            end
        end
        if #unblocked_ways==2 then
            local option=math.random(1,2)
            self.direction=unblocked_ways[option]-1
        elseif #unblocked_ways==1 then
            self.direction=unblocked_ways[1]-1
        end
    elseif self.direction==0 or self.direction==1 then
        self.direction=math.random(2,3)
    else self.direction=math.random(0,1)
    end
end

function EnemyTank:update()
    self:timer()
    self:animate()
    self:register_coordinate()
    if self.lifetime>self.animation_time then
        if self:collision_ahead() or self:tank_ahead() then
            self.vx=0;self.vy=0
            self.possible_directions[self.direction+1]=1
            self:selectpath()
            self:dir_to_speed();self:dir_to_rotate()
        else
            self.x=self.x+self.vx
            self.y=self.y+self.vy
            self.possible_directions={0,0,0,0}
        end

        if Game.time-self.created_at>2*60 then
            self:shoot()
        end
    end
end

local function create_enemy()
    if Game.time%120==0 and #Stage.enemy_container~=Stage.enemy_count then
        local temp_dir=math.random(0,3)
        local temp_x=Game.movement_patterns[temp_dir+1].x
        local temp_y=Game.movement_patterns[temp_dir+1].y
        local enemy=EnemyTank:new({
            y=10,
            x=math.random(22*8,24*8),
            vx=temp_x,
            vy=temp_y,
            direction=temp_dir,
            possible_directions={0,0,0,0},
            created_at=Game.time,
            last_shoot=0,
            tank_id=#Stage.enemy_container+2,
        })
        enemy:dir_to_rotate()
        table.insert(Stage.enemy_container,#Stage.enemy_container+1,enemy)
        local coordinate={enemy.tank_id,{x=enemy.x,y=enemy.y}}
        table.insert(Stage.tank_coordinates,#Stage.tank_coordinates+1,coordinate)
    end
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

local function content_generator()
    for _,row in pairs(Game.dynamic_content_coordinates[Game.current_stage]) do
            for y=row[2].minx,row[2].maxx do
                spr(35,row[1]*8,y*8,0)
            end
    end
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

        if Game.player_count==0 then  -- once only, create player tank
            Game.player=PlayerTank:new()
            local coordinate={Game.player.tank_id,{x=Game.player.x,y=Game.player.y}}
            table.insert(Stage.tank_coordinates,#Stage.tank_coordinates+1,coordinate)
            Game.player_count=Game.player_count+1
        else Game.player:update() end --WARNING call a method using : instead of dot
        
        for id,bullet in pairs(Game.bullets) do
            bullet:update(id)
        end

        create_enemy()

        for id,enemy in pairs(Stage.enemy_container) do
            enemy:update(id)
        end

        if #Stage.enemy_container==0 and Game.time-Stage.finishing_timestamp>30 and Stage.finished then
            Game.mode=3
        end

        content_generator()

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