
return function()
    -- Migrate the old hex rank HUD to the shared HUD.
    for _, player in pairs(game.players) do
        local hud = player.gui.center["hex-rank-hud"]
        if hud and hud.valid then
            hud.destroy()
        end
    end
end
