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
    assert(animation["type"] ~= nil and animation["type"] == "animation", "expected type animation");

    animation["lastUpdate"] = animation["lastUpdate"] + dt;

    while animation["lastUpdate"] > animation["speed"] do
        animation["frame"] = (animation["frame"]) % (animation["size"]) + 1;
        animation["lastUpdate"] = animation["lastUpdate"] - animation["speed"];
    end

    print(animation["frame"]);

    return animation;
end

return fortnite;