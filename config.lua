Config = {}

Config.debug = true

Config.functions = {
    toggleHud    = function(bool)
        exports["compas_ghost"]:compasshow(bool)
        TriggerEvent('ax-status:toggle', bool)
    end,

    toggleTextUi = function(text)
        if not text then
            vRP.close_textui()
            return
        end

        vRP.show_textui({ text })
    end,

    notify       = function(text, type)
        vRP.sendNotify({ text, type })
    end
}
