local fortnite = {};

fortnite.loadAnimation = function(name)
    assert(type(name) == "string", "name expected string, got " .. type(name));
    local animation = {
        type = "animation",
        playing = false,
        lastUpdate = 0,
        frame = 1
    };
    local content = love.filesystem.read("assets/anim/" .. name .. "/meta.json");
    local meta = json.decode(content);
    if meta == nil then return; end
    
    for i,v in pairs(meta) do
        animation[i] = v;
    end

    if animation["speed"] == nil then
        animation["speed"] = 500;
    end
    
    local frames = {};
    for i=1, animation.size, 1 do
        local frame = love.graphics.newImage("assets/anim/" .. name .. "/" .. i .. ".png");
        table.insert(frames, frame);
    end


    animation["frames"] = frames;

    return animation;
end

fortnite.updateAnimation = function(animation, dt)
    assert(animation ~= nil and animation["type"] ~= nil and animation["type"] == "animation", "expected type animation");

    animation["lastUpdate"] = animation["lastUpdate"] + dt;

    while animation["lastUpdate"] > animation["speed"] do
        animation["frame"] = (animation["frame"]) % (animation["size"]) + 1;
        animation["lastUpdate"] = animation["lastUpdate"] - animation["speed"];
    end

    return animation;
end

fortnite.createAnimationController = function(name)
    local controller = {
        state = nil,
        switch = nil,
        type="animationController"
    };
    assert(type(name) == "string", "name expected string, got " .. type(name));
    local content = love.filesystem.read("assets/anim/controllers/" .. name .. ".json");
    local meta = json.decode(content);
    if meta == nil then
        return nil;
    end

    for i, v in pairs(meta) do
        local animation = fortnite.loadAnimation(v);
        
        if animation ~= nil then
            if controller.state == nil then
                controller.state = i;
            end
    
            controller[i] = animation;
        end
    end

    return controller;
end

fortnite.updateController = function(controller, dt)
    assert(controller ~= nil and controller["type"] ~= nil and controller["type"] == "animationController", "expected type animationController");
    local state = controller["state"];
    local switch = controller["switch"];

    if switch ~= nil and controller[state]["frame"] == 1 then
        controller[state]["lastUpdate"] = 0
        controller["state"] = switch;
        state = switch;
        controller["switch"] = nil;
    end

    fortnite.updateAnimation(controller[state], dt);
end

fortnite.getControllerSprite = function(controller)
    assert(controller ~= nil and controller["type"] ~= nil and controller["type"] == "animationController", "expected type animationController");
    local state = controller["state"];
    local animation = controller[state];
    local frame = animation["frame"];
    local sprite = animation["frames"][frame];
    return sprite;
end

return fortnite;