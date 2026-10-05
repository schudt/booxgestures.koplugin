local Device = require("device")

if not Device:isAndroid() then
    return { disabled = true }
end

local android = require("android")
local ffi = require("ffi")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local BOTTOM_SETTING = "boox_bottom_gestures_disabled"
local TOP_SETTING = "boox_top_gestures_disabled"
local SIDE_SETTING = "boox_side_gestures_disabled"
local LIGHT_SETTING = "boox_light_popup_suppressed"
local BOTTOM_ACTION = "com.onyx.action.BOTTOM_GESTURE_ENABLE"
local TOP_ACTION = "com.onyx.action.TOP_GESTURE_ENABLE"
local SIDE_ACTION = "com.onyx.action.SIDE_GESTURE_ENABLE"

local BooxGestures = WidgetContainer:extend{
    name = "booxgestures",
    is_doc_only = false,
}

function BooxGestures:isBottomDisabled()
    return G_reader_settings:isTrue(BOTTOM_SETTING)
end

function BooxGestures:isTopDisabled()
    return G_reader_settings:isTrue(TOP_SETTING)
end

function BooxGestures:isSideDisabled()
    return G_reader_settings:isTrue(SIDE_SETTING)
end

function BooxGestures:apply(action_name, disabled)
    local ok, sent = pcall(function()
        return android.jni:context(android.app.activity.vm, function(jni)
            local env = jni.env
            local intent_class = env[0].FindClass(env, "android/content/Intent")
            local constructor = env[0].GetMethodID(
                env,
                intent_class,
                "<init>",
                "(Ljava/lang/String;)V"
            )
            local action = env[0].NewStringUTF(env, action_name)
            local intent = env[0].NewObject(env, intent_class, constructor, action)
            local key = env[0].NewStringUTF(env, "args_enable")
            local put_extra = env[0].GetMethodID(
                env,
                intent_class,
                "putExtra",
                "(Ljava/lang/String;Z)Landroid/content/Intent;"
            )

            env[0].CallObjectMethod(
                env,
                intent,
                put_extra,
                key,
                ffi.new("bool", not disabled)
            )
            jni:callVoidMethod(
                android.app.activity.clazz,
                "sendBroadcast",
                "(Landroid/content/Intent;)V",
                intent
            )

            local exception = env[0].ExceptionOccurred(env)
            if exception ~= nil then
                env[0].ExceptionDescribe(env)
                env[0].ExceptionClear(env)
                env[0].DeleteLocalRef(env, exception)
            end
            env[0].DeleteLocalRef(env, key)
            env[0].DeleteLocalRef(env, intent)
            env[0].DeleteLocalRef(env, action)
            env[0].DeleteLocalRef(env, intent_class)
            return exception == nil
        end)
    end)
    return ok and sent
end

function BooxGestures:setGestureDisabled(setting, action, disabled, label, notify)
    if not self:apply(action, disabled) then
        if notify then
            UIManager:show(InfoMessage:new{
                text = _("Could not change ") .. label .. _(" gestures."),
            })
        end
        return false
    end

    G_reader_settings:saveSetting(setting, disabled)
    if notify then
        UIManager:show(InfoMessage:new{
            text = disabled and label .. _(" gestures disabled")
                or label .. _(" gestures enabled"),
            timeout = 2,
        })
    end
    return true
end

function BooxGestures:init()
    local SilentLight = require("silentlight")
    self.silent_light = SilentLight:new(android, function()
        G_reader_settings:saveSetting(LIGHT_SETTING, false)
        UIManager:show(InfoMessage:new{
            text = _("Silent BOOX light control failed. Restored normal light control."),
            timeout = 3,
        })
    end)
    if G_reader_settings:isTrue(LIGHT_SETTING) then
        self:setLightPopupSuppressed(true)
    end
    self.ui.menu:registerToMainMenu(self)
    self:apply(BOTTOM_ACTION, self:isBottomDisabled())
    self:apply(TOP_ACTION, self:isTopDisabled())
    self:apply(SIDE_ACTION, self:isSideDisabled())
end

function BooxGestures:setLightPopupSuppressed(enabled)
    if enabled and not self.silent_light:enable() then
        G_reader_settings:saveSetting(LIGHT_SETTING, false)
        UIManager:show(InfoMessage:new{
            text = _("Silent BOOX light control is unavailable on this device."),
        })
        return false
    end
    if not enabled then self.silent_light:disable() end
    G_reader_settings:saveSetting(LIGHT_SETTING, enabled)
    return true
end

function BooxGestures:onRequestSuspend()
    if self:isBottomDisabled() then
        self:apply(BOTTOM_ACTION, false)
    end
    if self:isTopDisabled() then
        self:apply(TOP_ACTION, false)
    end
    if self:isSideDisabled() then
        self:apply(SIDE_ACTION, false)
    end
end

function BooxGestures:onResume()
    if self:isBottomDisabled() then
        self:apply(BOTTOM_ACTION, true)
    end
    if self:isTopDisabled() then
        self:apply(TOP_ACTION, true)
    end
    if self:isSideDisabled() then
        self:apply(SIDE_ACTION, true)
    end
end

function BooxGestures:stopPlugin()
    if self.silent_light then self.silent_light:disable() end
    local bottom_ok = self:apply(BOTTOM_ACTION, false)
    local top_ok = self:apply(TOP_ACTION, false)
    local side_ok = self:apply(SIDE_ACTION, false)
    return bottom_ok and top_ok and side_ok
end

function BooxGestures:addToMainMenu(menu_items)
    menu_items.boox_system_gestures = {
        text = _("BOOX controls"),
        sorting_hint = "device",
        sub_item_table = {
            {
                text = _("Suppress BOOX light popup in KOReader"),
                checked_func = function()
                    return G_reader_settings:isTrue(LIGHT_SETTING)
                end,
                callback = function()
                    self:setLightPopupSuppressed(not G_reader_settings:isTrue(LIGHT_SETTING))
                end,
            },
            {
                text = _("Disable BOOX top gestures in KOReader"),
                checked_func = function()
                    return self:isTopDisabled()
                end,
                callback = function()
                    self:setGestureDisabled(
                        TOP_SETTING,
                        TOP_ACTION,
                        not self:isTopDisabled(),
                        _("BOOX top"),
                        true
                    )
                end,
            },
            {
                text = _("Disable BOOX bottom gestures in KOReader"),
                checked_func = function()
                    return self:isBottomDisabled()
                end,
                callback = function()
                    self:setGestureDisabled(
                        BOTTOM_SETTING,
                        BOTTOM_ACTION,
                        not self:isBottomDisabled(),
                        _("BOOX bottom"),
                        true
                    )
                end,
            },
            {
                text = _("Disable BOOX side gestures in KOReader"),
                checked_func = function()
                    return self:isSideDisabled()
                end,
                callback = function()
                    self:setGestureDisabled(
                        SIDE_SETTING,
                        SIDE_ACTION,
                        not self:isSideDisabled(),
                        _("BOOX side"),
                        true
                    )
                end,
            },
        },
    }
end

return BooxGestures
