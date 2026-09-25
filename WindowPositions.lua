local _, ns = ...
local positions = {}
ns.WindowPositions = positions
local db, events
local frames = {}
local windows, tracked = {}, {}

local function public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function finite(value)
    return public(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function shown(frame)
    local value=frame:IsShown()
    return public(value) and value==true
end

local function applyDefault(frame, registration)
    frame:ClearAllPoints()
    if type(registration.default) == "function" then
        registration.default(frame)
    else
        local point, relative, relativePoint, x, y = unpack(registration.default)
        -- A report can arrive before the book has been built. Once it exists,
        -- centered fallback dialogs use it as their origin too.
        if point == "CENTER" and (not relative or relative == UIParent)
            and AzerothFieldbookBestiary and frame ~= AzerothFieldbookBestiary then
            relative, relativePoint = AzerothFieldbookBestiary, "CENTER"
        end
        frame:SetPoint(point, relative, relativePoint, x, y)
    end
end

function positions:Save(frame, key)
    key = key or (frames[frame] and frames[frame].key)
    if not db or not key then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    local scale, parentScale = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not finite(left) or not finite(top) or not finite(scale) or scale <= 0
        or not finite(parentScale) or parentScale <= 0 then return end
    -- UIParent coordinates keep the title in place even for scaled windows,
    -- children inheriting the book's scale, and windows that change height.
    if type(db.windowPositions) ~= "table" then db.windowPositions = {} end
    db.windowPositions[key] = { left = left * scale / parentScale, top = top * scale / parentScale }
    if frames[frame] then frames[frame].moved = true end
    local sharedKey = frames[frame] and frames[frame].sharedKey
    if sharedKey and key == frames[frame].key then
        local shared = sharedKey()
        if shared then self:Save(frame, shared) end
    end
end

-- Showing, hiding and resizing a default window must not detach it from the
-- book. Only explicit drags (or restored user positions) become screen anchors.
function positions:SaveIfMoved(frame, key)
    if frames[frame] and frames[frame].moved then self:Save(frame, key) end
end

function positions:Restore(frame, key)
    key = key or (frames[frame] and frames[frame].key)
    local saved = db and type(db.windowPositions) == "table" and db.windowPositions[key]
    if type(saved) ~= "table" or not finite(saved.left) or not finite(saved.top) then return false end
    local scale, parentScale = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not finite(scale) or scale <= 0 or not finite(parentScale) or parentScale <= 0 then return false end
    local left, top = saved.left, saved.top
    local width = frame.GetWidth and frame:GetWidth()
    local height = frame.GetHeight and frame:GetHeight()
    local screenWidth = UIParent.GetWidth and UIParent:GetWidth()
    local screenHeight = UIParent.GetHeight and UIParent:GetHeight()
    if finite(width) and finite(screenWidth) and screenWidth > 0 then
        left = math.max(0, math.min(left, math.max(0, screenWidth-width*scale/parentScale)))
    end
    if finite(height) and finite(screenHeight) and screenHeight > 0 then
        top = math.max(math.min(height*scale/parentScale, screenHeight), math.min(top, screenHeight))
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * parentScale / scale, top * parentScale / scale)
    if frames[frame] then frames[frame].moved = true end
    return true
end

function positions:SaveVisible()
    for frame in pairs(frames) do
        if shown(frame) then self:SaveIfMoved(frame) end
    end
end

function positions:RestoreAll(resetMissing)
    for frame, registration in pairs(frames) do
        if not self:Restore(frame) and resetMissing then
            registration.moved = false
            applyDefault(frame, registration)
        end
    end
end

function positions:Initialize(settings)
    db = settings
    if type(db.windowPositions) ~= "table" then db.windowPositions = {} end
    self:RestoreAll(true)
    if not events then
        events = CreateFrame("Frame")
        events:RegisterEvent("PLAYER_LOGOUT")
        events:SetScript("OnEvent", function() self:SaveVisible() end)
    end
end

function positions:Reset()
    if not db then return end
    db.windowPositions = {}
    self:RestoreAll(true)
end

-- Compare all addon windows in UIParent coordinates. Never move existing
-- neighbours to make room; the opening window must fit around them.
function positions:AvoidWindowOverlap(frame)
    local book = AzerothFieldbookBestiary
    local parentScale = UIParent:GetEffectiveScale()
    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    if not finite(parentScale) or parentScale <= 0 or not finite(screenWidth)
        or not finite(screenHeight) or screenWidth <= 0 or screenHeight <= 0 then return end
    local function rectangle(window)
        local left, top = window:GetLeft(), window:GetTop()
        local width, height, scale = window:GetWidth(), window:GetHeight(), window:GetEffectiveScale()
        if not finite(left) or not finite(top) or not finite(width) or not finite(height)
            or not finite(scale) or scale <= 0 or width <= 0 or height <= 0 then return end
        local ratio = scale / parentScale
        return {frame=window,left=left*ratio, top=top*ratio, width=width*ratio, height=height*ratio, ratio=ratio}
    end
    local box = rectangle(frame)
    if not box then return end
    -- An oversized dialog cannot be made visible by moving it alone.
    local fit = math.min(1, screenWidth/box.width, screenHeight/box.height)
    if fit < 1 then
        local scale=frame:GetScale()
        if not finite(scale) or scale<=0 then return end
        frame:SetScale(scale*fit)
        box = rectangle(frame)
        if not box then return end
    end
    local function clamp(left, top)
        return math.max(0, math.min(left, screenWidth-box.width)),
            math.max(box.height, math.min(top, screenHeight))
    end
    local left, top = clamp(box.left, box.top)
    local obstacles, seen = {}, {}
    local function addObstacle(window)
        if not window or window==frame or seen[window] or not shown(window) then return end
        seen[window]=true
        if window.IsVisible then
            local visible=window:IsVisible()
            if not public(visible) or visible==false then return end
        end
        if window.GetAlpha then
            local alpha=window:GetAlpha()
            if not finite(alpha) or alpha==0 then return end
        end
        local other=rectangle(window)
        if other then obstacles[#obstacles+1]=other end
    end
    addObstacle(book)
    for _, window in ipairs(windows) do addObstacle(window) end
    local main
    for _,other in ipairs(obstacles) do if other.frame==book then main=other;break end end
    local function overlap(x, y)
        local area=0
        for _, other in ipairs(obstacles) do
            area=area+math.max(0, math.min(x+box.width, other.left+other.width)-math.max(x, other.left))
                * math.max(0, math.min(y, other.top)-math.max(y-box.height, other.top-other.height))
        end
        return area
    end
    local alwaysAnchor=main and frame.afbPreferBookEdge==true and (not db or db.alwaysAnchorToMain~=false)
    if frame.afbPinned~=true and (alwaysAnchor or overlap(left, top) > 0) then
        -- Cross edge coordinates from every neighbour, so avoiding one window
        -- does not merely place the dialog on top of the next one.
        local xs, ys, seenX, seenY = {}, {}, {}, {}
        local function candidate(x,y)
            x,y=clamp(x,y)
            if not seenX[x] then xs[#xs+1]=x;seenX[x]=true end
            if not seenY[y] then ys[#ys+1]=y;seenY[y]=true end
        end
        candidate(left,top);candidate(0,screenHeight);candidate(screenWidth,0)
        for _, other in ipairs(obstacles) do
            candidate(other.left-box.width,other.top+box.height)
            candidate(other.left+other.width,other.top-other.height)
            candidate(other.left,other.top)
            candidate(other.left+other.width-box.width,other.top-other.height+box.height)
        end
        local function touches(x,y,other,side)
            local vertical=math.min(y,other.top)-math.max(y-box.height,other.top-other.height)
            local horizontal=math.min(x+box.width,other.left+other.width)-math.max(x,other.left)
            if side=="left" then return vertical>0 and math.abs(x+box.width-other.left)<0.01 end
            if side=="right" then return vertical>0 and math.abs(x-other.left-other.width)<0.01 end
            if side=="bottom" then return horizontal>0 and math.abs(y-other.top+other.height)<0.01 end
            return horizontal>0 and math.abs(y-box.height-other.top)<0.01
        end
        local function priorityAt(x,y)
            if not main or frame.afbPreferBookEdge~=true then return 0 end
            if alwaysAnchor then
                local rule=frame.afbAnchorRule
                if rule=="right" then
                    if touches(x,y,main,"right") then return 0 end
                    for _, other in ipairs(obstacles) do
                        if other.frame~=book and other.left+other.width>main.left+main.width
                            and touches(x,y,other,"right") then return 1 end
                    end
                elseif rule=="filters" then
                    if touches(x,y,main,"left") then return 0 end
                    if touches(x,y,main,"bottom") then return 1 end
                    for _, other in ipairs(obstacles) do
                        if other.frame~=book and other.left<main.left and touches(x,y,other,"left") then return 2 end
                    end
                elseif rule=="pages" then
                    if touches(x,y,main,"right") then return 0 end
                    if touches(x,y,main,"left") then return 1 end
                end
            end
            for _, side in ipairs({"left","right","top","bottom"}) do
                if touches(x,y,main,side) then return alwaysAnchor and 3 or 0 end
            end
            return alwaysAnchor and 4 or 1
        end
        local bestArea, bestPriority, bestDistance
        for _, x in ipairs(xs) do for _, y in ipairs(ys) do
            local area = overlap(x, y)
            -- A free position touching the launching book wins over a nearer
            -- unrelated window. Screen bounds and avoiding overlap still win.
            local priority=priorityAt(x,y)
            local preferredLeft,preferredTop=box.left,box.top
            if main and frame.afbAlignBookBottom==true then
                preferredLeft,preferredTop=clamp(main.left+main.width,main.top-main.height+box.height)
            end
            local distance = (x-preferredLeft)^2+(y-preferredTop)^2
            if not bestArea or area < bestArea or (area == bestArea and
                (priority < bestPriority or (priority == bestPriority and distance < bestDistance))) then
                left, top, bestArea, bestPriority, bestDistance = x, y, area, priority, distance
            end
        end end
    end
    if math.abs(left-box.left)<0.01 and math.abs(top-box.top)<0.01 then return end
    -- Opening the book can otherwise drag its already-visible default dialogs
    -- along with it, invalidating their rectangles (including pinned Notes).
    for _, other in ipairs(obstacles) do
        local relative=other.frame
        local visited={}
        while relative and relative~=UIParent and not visited[relative] do
            visited[relative]=true
            local _, anchor=relative:GetPoint()
            if anchor==frame then
                other.frame:ClearAllPoints()
                other.frame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",other.left/other.ratio,other.top/other.ratio)
                break
            end
            if type(anchor)~="table" and type(anchor)~="userdata" then break end
            relative=anchor
        end
    end
    frame:ClearAllPoints()
    local registration = frames[frame]
    if main and registration and not registration.moved and frame.afbPinned~=true then
        frame:SetPoint("TOPLEFT", book, "TOPLEFT", (left-main.left)/box.ratio, (top-main.top)/box.ratio)
    else
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left/box.ratio, top/box.ratio)
    end
end

function positions:Track(frame)
    if tracked[frame] then return end
    tracked[frame]=true;windows[#windows+1]=frame
    frame:SetClampedToScreen(true)
    if frame.SetClampRectInsets then frame:SetClampRectInsets(0,0,0,0) end
    frame:HookScript("OnShow",function(self)
        if not frames[self] then positions:AvoidWindowOverlap(self) end
        if C_Timer and C_Timer.After then
            C_Timer.After(0,function()
                if shown(self) then positions:AvoidWindowOverlap(self) end
            end)
        end
    end)
end

function positions:Register(frame, key, sharedKey, defaultPosition)
    if frames[frame] then return end
    if ns.WindowFocus then ns.WindowFocus:Register(frame) end
    frames[frame] = { key = key, default = defaultPosition or { frame:GetPoint() }, sharedKey = sharedKey }
    self:Track(frame)
    frame:SetClampedToScreen(true)
    if frame.SetClampRectInsets then frame:SetClampRectInsets(0, 0, 0, 0) end
    frame:HookScript("OnDragStop", function(self) positions:Save(self) end)
    frame:HookScript("OnHide", function(self) positions:SaveIfMoved(self) end)
    frame:HookScript("OnShow", function(self)
        local registration = frames[self]
        if not registration.moved and self.afbPinned~=true then
            applyDefault(self, registration)
        end
        positions:AvoidWindowOverlap(self)
    end)
    if not self:Restore(frame) then applyDefault(frame, frames[frame]) end
end
