--whose json?
local bump = require "lib/bump";
json = require "lib/json";
local animation = require "lib/animation";

local drawHitboxes = true   
local drawPos = false
local lastBeat = 0;
local doBeat = true
local lastBeatDist = 0

local game = {
    baseGravity = 0.4,
    jumpGravity = 0.2,
    beatOffset = 0.15, -- do beat actions this many seconds sooner
    
    gravity = nil,
    mode = "game",
    bumpWorld = nil,
    sfx = nil,
    bpm = nil,
    currentSong = {
        fp = nil, -- file path of the song
        source = nil, -- the Source object
        spb = nil, -- seconds per beat
    }, 
    scene = {
        meta = {
            name = nil, -- name of the scene
            start = {x = 0, y = 0}, -- player starting position
            song = nil -- file path of music for this scene
        },
        collision = nil, -- the collision rectangles
        background = nil, -- background image
        foreground = nil, -- foreground image
        objects = nil, -- table containing moving/interactible objects
        scale = 0.3
    }
}

local controls = {
    game = {
        a = {hold = function(dt) 
            move(dt, -1);
        end},
        d = {hold = function(dt) move(dt, 1) end},
        space = {down = function() jump() end, up = function() game.gravity = game.baseGravity end}
    },
    cutscene = {
        escape = skip_cutscene
    },
    menu = {
        
    }
}

local camera = {
    x = 200,
    y = 0
}

local player = {
    maxSpeed = {x = 3, y = 8},
    slidingSpeed = {up = 5, down = 2},
    groundAcceleration = 0.4,
    airAcceleration = 0.2,
    groundDeceleration = 0.5,
    airDeceleration = 0.1,
    jumpVelocity = 5.5,
    doubleJumpVelocity = 4.5,
    wallJumpAngle = {x = 0.6, y = 0.75},
    slidingGracePeriod = 10,
    scale = 0.2,

    width = 0,
    height = 0,
    position = {x = 320, y = 100},
    speed = {x = 0, y = 0},
    moving = false,
    isGrounded = true,
    doubleJump = true,
    slidingTime = 0,
    slidingSide = 0,

    get_rect = function(self)
        return {self.position.x, self.position.y, self.position.x + self.width, self.position.y + self.height}
    end,
}

local noWallSlide = {
    ["1-0"] = {["3"] = true},
    ["1-1"] = {["2"] = true}
}

function move(dt, dir)
    local accelConstant = player.isGrounded and player.groundAcceleration or player.airAcceleration
    player.speed.x = player.speed.x + dir * accelConstant, player.maxSpeed.x
    player.moving = true;
end

function playSound(name)
    local sfx = love.audio.newSource("assets/sound/effect/" .. game.sfx[name], "static")
    sfx:play()
end

function jump()
    if player.isGrounded then
        player.speed.y = 0 - player.jumpVelocity
        game.gravity = game.jumpGravity
        playSound("jump")
    elseif player.slidingTime > 0 then
        player.speed.y = 0 - player.jumpVelocity * player.wallJumpAngle.y
        player.speed.x = player.slidingSide * player.jumpVelocity * player.wallJumpAngle.x
        game.gravity = game.jumpGravity
        playSound("walljump")
    elseif player.doubleJump then
        player.speed.y = 0 - player.doubleJumpVelocity
        player.doubleJump = false
        game.gravity = game.jumpGravity
        playSound("doublejump")
    end
end

function loadScene(name)
    local rawMeta = love.filesystem.read("assets/scenes/" .. name .. "/meta.json");
    local rawCollisions = love.filesystem.read("assets/scenes/" .. name .. "/collision.json");
    local rawObjects = love.filesystem.read("assets/scenes/" .. name .. "/object.json");
    game.scene["meta"] = json.decode(rawMeta);
    game.scene["collision"] = json.decode(rawCollisions);
    game.scene["objects"] = json.decode(rawObjects);
    game.scene["background"] = love.graphics.newImage("assets/scenes/" .. name .. "/background.png")
    game.scene["foreground"] = love.graphics.newImage("assets/scenes/" .. name .. "/foreground.png")
    game.bumpWorld = bump.newWorld()
    local doTheTHing = {}
    for i, v in pairs(game.scene["objects"]) do
        game.scene["objects"][i]["deltaBeat"] = 0;
        game.scene["objects"][i]["moving"] = false;
        game.scene["objects"][i]["rectIndex"] = 1
        local startPos = game.scene["objects"][i]["rects"][1];
        game.scene["objects"][i]["position"] = startPos;
        game.scene["objects"][i]["dtMoving"] =0;
        game.scene["objects"][i]["movingPlayer"] = false;
        game.scene["objects"][i]["type"] = "object";
        game.scene["objects"][i]["visible"] = true;
        if game.scene["objects"][i]["sprite"] ~= nil then
            game.scene["objects"][i]["sprite"] = love.graphics.newImage(game.scene["objects"][i]["sprite"])
        end
        if game.scene["objects"][i]["speed"] == "offbeat" then
            doTheTHing[i] = game.scene["objects"][i]
        end
        game.bumpWorld:add(v, startPos[1] * game.scene.meta.scale, startPos[2] * game.scene.meta.scale, (startPos[3] * game.scene.meta.scale)-(startPos[1] * game.scene.meta.scale), (startPos[4] * game.scene.meta.scale)-(startPos[2] * game.scene.meta.scale))
    end
    player.position.x = game.scene.meta.start.x * game.scene.meta.scale;
    player.position.y = game.scene.meta.start.y * game.scene.meta.scale;
    pRect = player:get_rect()
    game.bumpWorld:add("player", pRect[1], pRect[2], pRect[3]-pRect[1], pRect[4]-pRect[2])
    for i, rect in ipairs(game.scene.collision) do
        game.bumpWorld:add((i + 1) .. "", rect[1] * game.scene.meta.scale, rect[2] * game.scene.meta.scale, (rect[3] * game.scene.meta.scale)-(rect[1] * game.scene.meta.scale), (rect[4] * game.scene.meta.scale)-(rect[2] * game.scene.meta.scale))
    end

    game.currentSong.fp = game.scene.meta.song
    game.currentSong.spb = 60 / game.bpm[game.currentSong.fp]
    game.currentSong.source = love.audio.newSource("assets/sound/music/" .. game.currentSong.fp, "stream")
    game.currentSong.source:setLooping(true)

    for i, obj in ipairs(doTheTHing) do
        obj.speed = game.currentSong.spb * obj.bpm / 2
    end

    game.currentSong.source:play()
end

function initPlayer()
    player["animation"] = animation.createAnimationController("player");
    player.animation.state = "idle";
    player.width = player.animation.meta.width * player.scale;
    player.height = player.animation.meta.width * player.scale;
end

function love.load()
    local rawSFX = love.filesystem.read("assets/sound/effects.json");
    local rawBPM = love.filesystem.read("assets/sound/bpm.json");
    game.sfx = json.decode(rawSFX)
    game.bpm = json.decode(rawBPM)
    game.gravity = game.baseGravity
    initPlayer();
    loadScene("1-P");
end

function beatUpdate()
    for i,v in pairs(game.scene.objects) do
        if v.deltaBeat >= v.bpm then
            if v.offset > 0 then
                v.offset = v.offset - 1;
            else
                local nextIndex = ((v.rectIndex) % #(v.rects)) + 1;

                if type(v.rects[v.rectIndex]) == "string" and type(v.rects[nextIndex]) ~= "string" then
                    local startPos = v.rects[nextIndex];
                    game.bumpWorld:add(v, startPos[1] * game.scene.meta.scale, startPos[2] * game.scene.meta.scale, (startPos[3] * game.scene.meta.scale)-(startPos[1] * game.scene.meta.scale), (startPos[4] * game.scene.meta.scale)-(startPos[2] * game.scene.meta.scale));
                    v.visible = true;
                    v.rectIndex = nextIndex;
                    v.deltaBeat = 0;
                elseif type(v.rects[v.rectIndex]) ~= "string" and type(v.rects[nextIndex]) == "string" then
                    game.bumpWorld:remove(v);
                    v.visible = false;
                    v.rectIndex = nextIndex;
                    v.deltaBeat = 0;
                elseif type(v.rects[v.rectIndex]) ~= "string" and type(v.rects[nextIndex]) ~= "string" then
                    v.moving = true;
                    v.deltaBeat = 0;
                    v.dtMoving = 0
                end
            end
        end

        v.deltaBeat = v.deltaBeat + 1;
    end
end

function moveObject(dt)
    for i,v in pairs(game.scene.objects) do
        if v.moving then
            local nextIndex = ((v.rectIndex) % #(v.rects)) + 1;

            if v.dtMoving >= v.speed then
                v.dtMoving = 0;
                v.rectIndex = nextIndex;
                v.moving = false;
                v.position = v.rects[v.rectIndex];
                game.bumpWorld:update(v, v.position[1] * game.scene.meta.scale, v.position[2] * game.scene.meta.scale, (v.position[3] * game.scene.meta.scale)-(v.position[1] * game.scene.meta.scale), (v.position[4] * game.scene.meta.scale)-(v.position[2] * game.scene.meta.scale))
                return;
            end

            local dx = v.rects[nextIndex][1]-v.rects[v.rectIndex][1];
            local dy = v.rects[nextIndex][2]-v.rects[v.rectIndex][2];
            if v.movingPlayer then
                player.position.x = player.position.x + (dx * (dt/v.speed) * game.scene.meta.scale)
                player.position.y = player.position.y + (dy * (dt/v.speed) * game.scene.meta.scale)


                local actualX, actualY, cols, len = game.bumpWorld:move("player", player.position.x, player.position.y)

                player.position.x = actualX
                player.position.y = actualY
            end
            v.position = {v.rects[v.rectIndex][1] + (dx * (v.dtMoving/v.speed)), v.rects[v.rectIndex][2] + (dy * (v.dtMoving/v.speed)), v.rects[v.rectIndex][3] + (dx * (v.dtMoving/v.speed)), v.rects[v.rectIndex][4] + (dy * (v.dtMoving/v.speed))}
            game.bumpWorld:update(v, v.position[1] * game.scene.meta.scale, v.position[2] * game.scene.meta.scale, (v.position[3] * game.scene.meta.scale)-(v.position[1] * game.scene.meta.scale), (v.position[4] * game.scene.meta.scale)-(v.position[2] * game.scene.meta.scale))
            v.dtMoving = v.dtMoving + dt;
        end

        v.movingPlayer = false;
    end
end

function love.update(dt)
    for key, actions in pairs(controls[game.mode]) do
        if actions.hold ~= nil and love.keyboard.isDown(key) then
            actions.hold(dt)
        end
    end

    local songPos = game.currentSong.source:tell("seconds") + game.beatOffset
    local beatDist = songPos % game.currentSong.spb
    if beatDist > game.currentSong.spb * 0.5 then
        beatDist = 1 - beatDist
    end

    if beatDist > lastBeatDist and doBeat then
        beatUpdate()
        doBeat = false
    elseif beatDist < lastBeatDist then
        doBeat = true
    end

    lastBeatDist = beatDist

    player.speed.y = player.speed.y + game.gravity

    if math.abs(player.speed.x) > player.maxSpeed.x then
        player.speed.x = player.maxSpeed.x * (player.speed.x > 0 and 1 or -1)
    end
    if player.slidingTime >= player.slidingGracePeriod - 1 then
        if player.speed.y > player.slidingSpeed.down then
            player.speed.y = player.slidingSpeed.down
        elseif player.speed.y < 0 - player.slidingSpeed.up then
            player.speed.y = 0 - player.slidingSpeed.up
        end
    else
        if math.abs(player.speed.y) > player.maxSpeed.y then
            player.speed.y = player.maxSpeed.y * (player.speed.y > 0 and 1 or -1)
        end
    end

    player.position.x = player.position.x + player.speed.x * dt * 100
    player.position.y = player.position.y + player.speed.y * dt * 100

    if player.speed.y > 0 then 
        game.gravity = game.baseGravity
    end

    if not player.moving then
        local decelConstant = player.isGrounded and player.groundDeceleration or player.airDeceleration
        player.speed.x = player.speed.x + decelConstant * (player.speed.x > 0 and -1 or 1)
        if math.abs(player.speed.x) < decelConstant * 1.5 then
            player.speed.x = 0
        end
    end

    local actualX, actualY, cols, len = game.bumpWorld:move("player", player.position.x, player.position.y)

    player.position.x = actualX
    player.position.y = actualY

    local playWallGrab = false
    player.isGrounded = false
    for i = 1, len do
        local col = cols[i]
        if col.normal.y == -1 then
            if player.speed.y > game.gravity * 1.5 then
                playSound("land")
            end

            player.isGrounded = true
            player.doubleJump = true

            if col.other["type"] ~= nil and col.other["type"] == "object" then
                col.other.movingPlayer = true;
            end
        end
        
        if col.normal.x ~= 0 then
            if not (noWallSlide[game.scene.meta.name] and noWallSlide[game.scene.meta.name][col.other]) then
                if math.abs(player.speed.x) > player.airAcceleration * 1.5 then
                    playWallGrab = true
                end
            
                player.slidingSide = col.normal.x
                player.slidingTime = player.slidingGracePeriod
            end
            player.speed.x = 0
        end
        if col.normal.y ~= 0 then
            player.speed.y = 0
        end
    end

    if player.slidingTime > 0 then
        player.slidingTime = player.slidingTime - 1
    end

    if player.isGrounded then
        player.sliding = false
        playWallGrab = false

        if player.speed.x ~= 0 then
            player.animation.state = player.speed.x > 0 and "walkright" or "walkleft";
        else
            player.animation.state = "idle";
        end
    else
        if player.slidingTime > 5 then
            player.animation.state = player.slidingSide == 1 and "wallslideleft" or "wallslideright"
        else
            if player.speed.y > 0 then
                player.animation.state = "fall";
            else
                if player.doubleJump then
                    player.animation.state = "jump";
                else
                    player.animation.state = "doublejump";
                end
            end
        end
    end

    moveObject(dt);

    animation.updateController(player["animation"], dt);
    local foo = playWallGrab and playSound("wallgrab")
    player.moving = false
end

function updateCameraPos(scale)
    local centerX = player.position.x + (player.width/2);
    local centerY = player.position.y + (player.height/2);
    local width = love.graphics.getWidth()/scale;
    local height = love.graphics.getHeight()/scale;
    camera.x = centerX - (width/2);
    camera.y = centerY - (height/2);

    if camera.x + width > game.scene.background:getWidth() * game.scene.meta.scale then
        camera.x = (game.scene.background:getWidth() *  game.scene.meta.scale) - width;
    elseif camera.x < 0 then
        camera.x = 0;
    end

    if (camera.y + height) > (game.scene.background:getHeight() * game.scene.meta.scale) then
        camera.y = (game.scene.background:getHeight() * game.scene.meta.scale) - height;
    elseif camera.y < 0 then
        camera.y = 0;
    end

end

function drawForeground()
    love.graphics.setColor(255,255, 255);
    love.graphics.draw(game.scene.foreground, 1, 1, 0, game.scene.meta.scale, game.scene.meta.scale);
end

function drawBackground()
    love.graphics.setColor(255,255, 255);
    love.graphics.draw(game.scene.background, 1, 1, 0, game.scene.meta.scale, game.scene.meta.scale);
end

function drawPlayer()
    love.graphics.setColor(255,255, 255);
    love.graphics.draw(animation.getControllerSprite(player.animation), player.position.x, player.position.y, 0, player.scale, player.scale);
end

function drawHitbox()
    love.graphics.setColor(255, 0, 0)
    if drawHitboxes then
        local pRect = player:get_rect()
        love.graphics.rectangle("line", pRect[1], pRect[2], pRect[3]-pRect[1], pRect[4]-pRect[2])
        for i, rect in ipairs(game.scene.collision) do
            love.graphics.rectangle("line", rect[1] * game.scene.meta.scale, rect[2] * game.scene.meta.scale, (rect[3] * game.scene.meta.scale)-(rect[1] * game.scene.meta.scale), (rect[4] * game.scene.meta.scale)-(rect[2] * game.scene.meta.scale))
            love.graphics.print(i + 1, (rect[1] + 4) * game.scene.meta.scale, (rect[2] + 2) * game.scene.meta.scale )
        end

        for i,object in ipairs(game.scene.objects) do
            if object.visible then
                local rect = object.position;
                love.graphics.rectangle("line", rect[1] * game.scene.meta.scale, rect[2] * game.scene.meta.scale, (rect[3] * game.scene.meta.scale)-(rect[1] * game.scene.meta.scale), (rect[4] * game.scene.meta.scale)-(rect[2] * game.scene.meta.scale))
            end
        end
    end
end

function drawMousePos(scale)
    love.graphics.setColor(255,255,255,255);
    
    if drawPos then
        x, y = love.mouse.getPosition( );
        gX = (camera.x + x) * (1/game.scene.meta.scale);
        gY = (camera.y + y) * (1/game.scene.meta.scale);

        love.graphics.print("(" .. gX .. " " .. gY .. ")", (camera.x + x)/scale, camera.y + y/scale);
    end
end

function drawObjects()
    for i,object in ipairs(game.scene.objects) do
        if object.visible and object.sprite ~= nil then

            love.graphics.draw(object.sprite, object.position[1] * game.scene.meta.scale, object.position[2] * game.scene.meta.scale, 0, game.scene.meta.scale, game.scene.meta.scale);
        end
    end
end

function love.draw()
    local scale = love.graphics.getHeight() / 1080;

    if scale < 1 then
        scale = 1
    end

    if scale > 1 then
        love.graphics.scale(scale, scale)
    end

    updateCameraPos(scale);

    love.graphics.translate(-camera.x, -camera.y);
    drawBackground();
    drawObjects();
    drawPlayer();
    drawForeground();
    drawHitbox();
    drawMousePos(scale);
    love.graphics.translate(camera.x, camera.y);
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end

    local actions = controls[game.mode][key]
    if actions ~= nil and actions.down ~= nil then
        actions.down()
    end
end

function love.keyreleased(key)
    local actions = controls[game.mode][key]
    if actions ~= nil and actions.up ~= nil then
        actions.up()
    end
end