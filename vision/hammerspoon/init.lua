-- Basic window tiling and ROI markers using Hammerspoon
local win = require('hs.window')
local screen = require('hs.screen')
local geometry = require('hs.geometry')
local drawing = require('hs.drawing')

local configDir = hs.fs.currentDir() .. "/vision/config/rois.json"

local function loadJSON(path)
  local f = io.open(path, 'r')
  if not f then return {} end
  local content = f:read('*a'); f:close()
  local ok, obj = pcall(hs.json.decode, content)
  if ok then return obj end
  return {}
end

local overlays = {}

local function clearOverlays()
  for _, o in ipairs(overlays) do o:delete() end
  overlays = {}
end

local function drawROI(frame, color)
  local rect = drawing.rectangle(frame)
  rect:setStroke(true)
  rect:setFill(false)
  rect:setStrokeColor(color or {red=1,green=0,blue=0,alpha=0.8})
  rect:setStrokeWidth(2)
  rect:bringToFront(true)
  rect:show()
  table.insert(overlays, rect)
end

local function anchorWindows()
  local rois = loadJSON(configDir)
  clearOverlays()
  for pane, cfg in pairs(rois) do
    local title = cfg.window_title_contains
    local w = win.get("" .. title)
    if w then
      -- tile to left half by default
      local scr = w:screen()
      local f = scr:frame()
      w:setFrame(geometry.rect(f.x, f.y, f.w/2, f.h))
      local r = cfg.roi
      local roiFrame = geometry.rect(w:frame().x + r.x, w:frame().y + r.y, r.w, r.h)
      drawROI(roiFrame)
    end
  end
end

hs.hotkey.bind({"cmd","alt","ctrl"}, "R", function()
  anchorWindows()
end)

hs.alert.show("Hammerspoon Vision ROI helper loaded. Hotkey: ⌘⌥⌃R")

