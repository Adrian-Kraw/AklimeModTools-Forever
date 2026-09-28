-- ColorizerSkins_MicroMenu.lua: micro menu skin definitions for the colorizer.

local C = AklimeMod_Colorizer
local D = C.defaults
local function T(tex,r,g,b,a) if tex then tex:SetDesaturation(1); tex:SetVertexColor(r,g,b,a or 1) end end
local function R(tex) if tex then C.Restore(tex) end end
local function col(k,ck) return C:GetColor(k,ck) end

local function microColors()
    return {
        btn_normal_color    = { label="Normal",    r=D.main.r, g=D.main.g, b=D.main.b, a=1, order=1 },
        btn_highlight_color = { label="Highlight", r=1,        g=1,        b=1,        a=1, order=2 },
        btn_pushed_color    = { label="Pressed",   r=D.main.r, g=D.main.g, b=D.main.b, a=1, order=3 },
    }
end

local function applyMicro(key, btn, nc, hc, pc)
    if not btn then return end
    local nr,ng,nb,na = col(key,"btn_normal_color")
    local hr,hg,hb,ha = col(key,"btn_highlight_color")
    local pr,pg,pb,pa = col(key,"btn_pushed_color")
    local nt = btn:GetNormalTexture()
    local ht = btn:GetHighlightTexture()
    local pt = btn:GetPushedTexture()
    for _,tex in pairs({ nt,ht,pt }) do if tex then tex:SetDesaturation(1) end end
    T(nt, nr,ng,nb,na); T(ht, hr,hg,hb,ha); T(pt, pr,pg,pb,pa)
end

local function removeMicro(btn)
    if not btn then return end
    for _,tex in pairs({ btn:GetNormalTexture(), btn:GetHighlightTexture(), btn:GetPushedTexture() }) do
        if tex then tex:SetDesaturation(0); tex:SetVertexColor(1,1,1,1) end
    end
end

-- ============================================================
-- Character micro button portrait. Re-tints the hover textures so they stay themed.
-- ============================================================
C:Register("microChar", {
    label  = "Character Info",
    group  = "Micro Menu",
    colors = microColors(),
    apply = function(self)
        local nr,ng,nb,na = col("microChar","btn_normal_color")
        local hr,hg,hb,ha = col("microChar","btn_highlight_color")
        local pr,pg,pb,pa = col("microChar","btn_pushed_color")
        local portrait = CharacterMicroButton.Portrait
        local function applyColor(r,g,b,a) T(portrait, r,g,b,a) end
        hooksecurefunc(CharacterMicroButton, "OnEnter",    function() applyColor(hr,hg,hb,ha) end)
        hooksecurefunc(CharacterMicroButton, "OnLeave",    function()
            if CharacterMicroButton:GetButtonState()=="NORMAL" then applyColor(nr,ng,nb,na)
            else applyColor(pr,pg,pb,pa) end
        end)
        hooksecurefunc(CharacterMicroButton, "OnMouseDown",function() applyColor(pr,pg,pb,pa) end)
        hooksecurefunc(CharacterFrame,       "OnShow",     function() applyColor(pr,pg,pb,pa) end)
        hooksecurefunc(CharacterFrame,       "OnHide",     function()
            if MouseIsOver(CharacterMicroButton) then applyColor(hr,hg,hb,ha)
            else applyColor(nr,ng,nb,na) end
        end)
        applyColor(nr,ng,nb,na)
    end,
    remove = function(self) R(CharacterMicroButton.Portrait) end,
})

-- ============================================================
-- All other micro buttons -- identical structure
-- ============================================================
local microButtons = {
    { key="microProfession", label="Professions",             btn="ProfessionMicroButton"    },
    { key="microSpells",     label="Talents & Spellbook",     btn="PlayerSpellsMicroButton"  },
    { key="microAchieve",    label="Achievements",            btn="AchievementMicroButton"   },
    { key="microQuest",      label="Quest Log",               btn="QuestLogMicroButton"      },
    { key="microHousing",    label="Housing Dashboard",       btn="HousingMicroButton"       },
    { key="microGuild",      label="Guild & Communities",     btn="GuildMicroButton",  emblem=true },
    { key="microLFD",        label="Group Finder",            btn="LFDMicroButton"           },
    { key="microCollect",    label="Warband Collections",     btn="CollectionsMicroButton"   },
    { key="microEJ",         label="Adventure Guide",         btn="EJMicroButton"            },
    { key="microStore",      label="Shop",                    btn="StoreMicroButton"         },
    { key="microMenu",       label="Game Menu",               btn="MainMenuMicroButton"      },
}

local microKeys = { "microChar" }
for _, def in ipairs(microButtons) do
    local key   = def.key
    local bname = def.btn
    local hasEmblem = def.emblem
    table.insert(microKeys, key)
    C:Register(key, {
        label  = def.label,
        group  = "Micro Menu",
        colors = microColors(),
        apply = function(self)
            local btn = _G[bname]
            if not btn then return end
            local nr,ng,nb,na = col(key,"btn_normal_color")
            local hr,hg,hb,ha = col(key,"btn_highlight_color")
            local pr,pg,pb,pa = col(key,"btn_pushed_color")
            local nt,ht,pt = btn:GetNormalTexture(), btn:GetHighlightTexture(), btn:GetPushedTexture()
            for _,tex in pairs({ nt,ht,pt }) do if tex then tex:SetDesaturation(1) end end
            T(nt, nr,ng,nb,na); T(ht, hr,hg,hb,ha); T(pt, pr,pg,pb,pa)
            if hasEmblem and btn.Emblem then T(btn.Emblem, nr,ng,nb,na) end
        end,
        remove = function(self)
            local btn = _G[bname]
            if not btn then return end
            for _,tex in pairs({ btn:GetNormalTexture(), btn:GetHighlightTexture(), btn:GetPushedTexture() }) do
                if tex then tex:SetDesaturation(0); tex:SetVertexColor(1,1,1,1) end
            end
            if hasEmblem and btn.Emblem then R(btn.Emblem) end
        end,
    })
end

table.insert(AklimeMod_Colorizer.groupOrder, {
    label = "Micro Menu",
    keys  = microKeys,
})