-- Bases installed from older recipes created player_vehicles before these columns existed.
-- Adds whatever is missing on start so the queries in main.lua don't fail.
local requiredColumns = {
    coords = 'TEXT DEFAULT NULL',
}

MySQL.ready(function()
    for column, definition in pairs(requiredColumns) do
        local exists = MySQL.scalar.await([[
            SELECT 1 FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'player_vehicles' AND COLUMN_NAME = ?
        ]], { column })

        if not exists then
            MySQL.query.await(('ALTER TABLE `player_vehicles` ADD COLUMN `%s` %s'):format(column, definition))
            lib.print.info(('Added missing column player_vehicles.%s'):format(column))
        end
    end
end)
