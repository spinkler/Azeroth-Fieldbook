local _, ns = ...

function ns.StyleConfirmButton(control)
    -- Clone the client's themed normal artwork: the legacy minimize
    -- texture does not carry the current close-button border.
    local disabled=control:CreateTexture(nil,"ARTWORK")
    disabled:SetAllPoints()
    local normal=control:GetNormalTexture()
    local atlas=normal and normal.GetAtlas and normal:GetAtlas()
    if atlas then
        disabled:SetAtlas(atlas)
    else
        disabled:SetTexture(normal and normal:GetTexture() or "Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        if normal then disabled:SetTexCoord(normal:GetTexCoord()) end
    end
    disabled:SetDesaturated(true)
    control:SetDisabledTexture(disabled)
    control.cover=control:CreateTexture(nil,"OVERLAY")
    control.cover:SetPoint("TOPLEFT",6,-6);control.cover:SetPoint("BOTTOMRIGHT",-6,6)
    local tick=control:CreateTexture(nil,"OVERLAY",nil,1)
    tick:SetPoint("CENTER");tick:SetSize(16,16)
    tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    tick:SetVertexColor(0.2,1,0.2)
    control.check=tick
end
