-- ColorizerSkins_ActionBars.lua: action bar skin definitions for the colorizer.

local C = AklimeMod_Colorizer
local function T(tex,r,g,b,a) if tex then tex:SetDesaturation(1); tex:SetVertexColor(r,g,b,a or 1) end end
local function R(tex) if tex then C.Restore(tex) end end
local function col(k,ck) return C:GetColor(k,ck) end

local actionBarDefs = {
    { key="actionBar1", label="Action Bar 1", prefix="ActionButton",          count=12,
      extra = function(r,g,b,a)
          for _,tex in pairs({ MainActionBar.EndCaps.LeftEndCap, MainActionBar.BorderArt, MainActionBar.EndCaps.RightEndCap }) do T(tex,r,g,b,a) end
          for _,v in pairs({ MainActionBar:GetChildren() }) do
              if type(v)=="table" and v.Center then
                  for _,k in ipairs({ "TopEdge","Center","BottomEdge" }) do T(v[k],r,g,b,a) end
              end
          end
      end,
      extraR = function()
          for _,tex in pairs({ MainActionBar.EndCaps.LeftEndCap, MainActionBar.BorderArt, MainActionBar.EndCaps.RightEndCap }) do R(tex) end
          for _,v in pairs({ MainActionBar:GetChildren() }) do
              if type(v)=="table" and v.Center then
                  for _,k in ipairs({ "TopEdge","Center","BottomEdge" }) do R(v[k]) end
              end
          end
      end,
    },
    { key="actionBar2", label="Action Bar 2", prefix="MultiBarBottomLeftButton",  count=12 },
    { key="actionBar3", label="Action Bar 3", prefix="MultiBarBottomRightButton",  count=12 },
    { key="actionBar4", label="Action Bar 4", prefix="MultiBarRightButton",         count=12 },
    { key="actionBar5", label="Action Bar 5", prefix="MultiBarLeftButton",          count=12 },
    { key="actionBar6", label="Action Bar 6", prefix="MultiBar5Button",             count=12 },
    { key="actionBar7", label="Action Bar 7", prefix="MultiBar6Button",             count=12 },
    { key="actionBar8", label="Action Bar 8", prefix="MultiBar7Button",             count=12 },
    { key="petBar",     label="Pet Bar",      prefix="PetActionButton",             count=10 },
    { key="stanceBar",  label="Stance Bar",   prefix="StanceButton",               count=10 },
}

local barKeys = {}
for _, def in ipairs(actionBarDefs) do
    local key, pfx, cnt = def.key, def.prefix, def.count
    local extra, extraR = def.extra, def.extraR
    table.insert(barKeys, key)
    C:Register(key, {
        label  = def.label,
        group  = "Action Bars",
        colors = { main = { label="Main", r=0.22, g=0.22, b=0.22, a=1, order=1 } },
        apply = function(self)
            local mr,mg,mb,ma = col(key,"main")
            for i=1,cnt do T(_G[pfx..i.."NormalTexture"], mr,mg,mb,ma) end
            if extra then extra(mr,mg,mb,ma) end
        end,
        remove = function(self)
            for i=1,cnt do R(_G[pfx..i.."NormalTexture"]) end
            if extraR then extraR() end
        end,
    })
end

table.insert(AklimeMod_Colorizer.groupOrder, {
    label = "Action Bars",
    keys  = barKeys,
})