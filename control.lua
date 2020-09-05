local generated = require("generated")

script.on_load(function()
  commands.add_command("mapshot", "screenshot the whole map", mapshot)
end)

-- All settings of the mod.
local params = {}

function updateParams(idx)
  -- settings.player[xxx] does contain the value at the beginning of the game,
  -- while get_player_settings contains the current value.
  local s = settings.get_player_settings(game.get_player(idx))
  params.prefix = s["prefix"].value
  params.tilemin = s["tilemin"].value
  params.tilemax = s["tilemax"].value
  params.resolution = s["resolution"].value
  params.jpgquality = s["jpgquality"].value
end

function mapshot(evt)
  updateParams(evt.player_index)
  -- Name of this screenshot.
  local name = "seed" .. game.default_map_gen_settings.seed .. "-" .. evt.tick
  if evt.parameter ~= nil and #evt.parameter > 0 then
    name = evt.parameter
  end

  -- Where to store the files.
  local prefix = params.prefix .. name .. "/"

  game.player.print("Mapshot '" .. prefix .. "' ...")

  -- Determine map min & max world coordinates based on existing chunks.
  local world_min = { x = 2^30, y = 2^30 }
  local world_max = { x = -2^30, y = -2^30 }
  for chunk in game.surfaces["nauvis"].get_chunks() do
    world_min.x = math.min(world_min.x, chunk.area.left_top.x)
    world_min.y = math.min(world_min.y, chunk.area.left_top.y)
    world_max.x = math.max(world_max.x, chunk.area.right_bottom.x)
    world_max.y = math.max(world_max.y, chunk.area.right_bottom.y)
  end
  game.player.print("Map: (" .. world_min.x .. ", " .. world_min.y .. ")-(" .. world_max.x .. ", " .. world_max.y .. ")")

  -- Range of tiles to render, in power of 2.
  local tile_range_min = math.log(params.tilemin, 2)
  local tile_range_max = math.log(params.tilemax, 2)

  -- Size of a tile, in pixels.
  local render_size = params.resolution

  -- Write metadata.
  game.write_file(prefix .. "mapshot.json", game.table_to_json({
    tile_size = math.pow(2, tile_range_max),
    render_size = render_size,
    world_min = world_min,
    world_max = world_max,
    player = game.player.position,
    zoom_min = 0,
    zoom_max = tile_range_max - tile_range_min,
  }))

  -- Create the serving html.
  game.write_file(prefix .. "index.html", generated.html)

  -- Generate all the tiles.
  for tile_range = tile_range_max, tile_range_min, -1 do
    local tile_size = math.pow(2, tile_range)
    local render_zoom = tile_range_max - tile_range
    gen_layer(tile_size, render_size, world_min, world_max, prefix .. "zoom_" .. render_zoom .. "/")
  end

  game.player.print("Mapshot done.")
end

function gen_layer(tile_size, render_size, world_min, world_max, prefix)
  -- Zoom. We want to have render_size pixels represent tile_size world unit.
  -- A zoom of 1.0 means that 32 pixels represent 1 world unit. A zoom of 2.0 means 64 pixels per world unit.
  local zoom = render_size / 32 / tile_size

  local tile_min = { x = math.floor(world_min.x / tile_size), y = math.floor(world_min.y / tile_size) }
  local tile_max = { x = math.floor(world_max.x / tile_size), y = math.floor(world_max.y / tile_size) }

  game.player.print("Tile size " .. tile_size .. ": " .. (tile_max.x - tile_min.x + 1) * (tile_max.y - tile_min.y + 1) .. " tiles to generate")

  for tile_y = tile_min.y, tile_max.y do
    for tile_x = tile_min.x, tile_max.x do
      local top_left = { x = tile_x * tile_size, y = tile_y * tile_size }
      game.take_screenshot{
        position = {
          x = top_left.x + tile_size / 2,
          y = top_left.y + tile_size / 2,
        },
        resolution = {render_size, render_size},
        zoom = zoom,
        path = prefix .. "tile_" .. tile_x .. "_" .. tile_y .. ".jpg",
        show_gui = false,
        show_entity_info = true,
        quality = params.jpgquality,
        daytime = 0,
        water_tick = 0,
      }
    end
  end
end