local ffi = require("ffi")

local SilentLight = {}
SilentLight.__index = SilentLight

function SilentLight:new(android, on_failure)
    return setmetatable({ android = android, on_failure = on_failure }, self)
end

local function clearException(env)
    local exception = env[0].ExceptionOccurred(env)
    if exception == nil then return false end
    env[0].ExceptionClear(env)
    env[0].DeleteLocalRef(env, exception)
    return true
end

function SilentLight:call(light_type, value)
    local android = self.android
    local ok, success = pcall(function()
        return android.jni:context(android.app.activity.vm, function(jni)
            local env = jni.env
            local class = env[0].FindClass(env, "android/onyx/hardware/DeviceController")
            local failed = clearException(env)
            if class == nil then return false end
            if failed then
                env[0].DeleteLocalRef(env, class)
                return false
            end
            local name = light_type and "setLightValue" or "checkCTM"
            local signature = light_type and "(III)V" or "()Z"
            local method = env[0].GetStaticMethodID(env, class, name, signature)
            failed = clearException(env)
            local result = false
            if method ~= nil and not failed then
                if light_type then
                    local args = ffi.new("jvalue[3]")
                    args[0].i, args[1].i, args[2].i = light_type, value, 0
                    env[0].CallStaticVoidMethodA(env, class, method, args)
                    result = true
                else
                    result = env[0].CallStaticBooleanMethodA(env, class, method, nil) ~= 0
                end
                if clearException(env) then result = false end
            end
            env[0].DeleteLocalRef(env, class)
            return result
        end)
    end)
    return ok and success
end

function SilentLight:enable()
    if self.originals then return true end
    -- Types 7/6 are brightness/warmth only on BOOX CTM devices.
    if not self:call() then return false end
    local android = self.android
    if type(android.setScreenBrightness) ~= "function"
        or type(android.setScreenWarmth) ~= "function" then
        return false
    end
    self.originals, self.wrappers = {}, {}
    for name, light_type in pairs({ setScreenBrightness = 7, setScreenWarmth = 6 }) do
        local original = android[name]
        self.originals[name] = original
        local wrapper = function(value)
            if type(value) == "number" and self:call(light_type, math.floor(value)) then
                return
            end
            self:disable()
            if self.on_failure then self.on_failure() end
            return original(value)
        end
        self.wrappers[name] = wrapper
        android[name] = wrapper
    end
    return true
end

function SilentLight:disable()
    if not self.originals then return end
    for name, original in pairs(self.originals) do
        if self.android[name] == self.wrappers[name] then
            self.android[name] = original
        end
    end
    self.originals, self.wrappers = nil, nil
end

return SilentLight
