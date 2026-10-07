        local function applyIllustrationInk(texture,asset,left,right,top,bottom)
            -- Render cropped artwork directly; cropped native ink masks smear
            -- their edge samples on this client.
            texture:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\" .. asset)
            texture:SetTexCoord(left,right,top,bottom)
            texture:SetDesaturated(false)
            addBackgroundLayer(texture,1,1,1,true)
        end
        -- Quiet illustration on the paper, below all interactive content.
        book.gnollIllustration=book:CreateTexture(nil,"BACKGROUND",nil,3)
        book.gnollIllustration:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\BestiaryGnoll.png")
        -- Full image is 360 x 440 at (-58,-16); keep it left of the divider.
        book.gnollIllustration:SetSize(296,418)
        book.gnollIllustration:SetPoint("BOTTOMLEFT",book,"BOTTOMLEFT",6,6)
        book.gnollIllustration:SetTexCoord(64/360,1,0,1-22/440)
        book.gnollIllustration:SetAlpha(0.33)
        applyIllustrationInk(book.gnollIllustration,"BestiaryGnoll.png",64/360,1,0,1-22/440)
        book.koboldIllustration=book:CreateTexture(nil,"BACKGROUND",nil,3)
        book.koboldIllustration:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\BestiaryKobold.png")
        book.koboldIllustration:SetSize(334,378)
        book.koboldIllustration:SetPoint("BOTTOMRIGHT",book,"BOTTOMRIGHT",-22,6)
        book.koboldIllustration:SetTexCoord(0,334/360,0,1-62/440)
        book.koboldIllustration:SetAlpha(0.33)
        applyIllustrationInk(book.koboldIllustration,"BestiaryKobold.png",0,334/360,0,1-62/440)
        -- The larger moonkin sits behind the foreground murloc.
        local moonkin=book:CreateTexture(nil,"BACKGROUND",nil,2)
        moonkin:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\BestiaryMoonkinSketch.png")
        moonkin:SetSize(430,500)
        moonkin:SetPoint("BOTTOMLEFT",book,"BOTTOMLEFT",330,38)
        moonkin:SetAlpha(0.28)
        addBackgroundLayer(moonkin,1,1,1,true)
        book.moonkinIllustration=moonkin
        if type(book.CreateMaskTexture)=="function" and type(moonkin.AddMaskTexture)=="function" then
            local mask=book:CreateMaskTexture(nil,"BACKGROUND")
            mask:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\BestiaryMoonkinMurlocMask.png")
            mask:SetAllPoints(moonkin)
            moonkin:AddMaskTexture(mask)
            book.moonkinMurlocMask=mask
        end
        -- Preview sketch beside the left margin of the right pane.
        local murloc=book:CreateTexture(nil,"BACKGROUND",nil,3)
        murloc:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\BestiaryMurlocSketch.png")
        murloc:SetSize(186,310)
        -- Trim transparent padding without stretching the creature.
        murloc:SetTexCoord(99/512,388/512,17/512,498/512)
        murloc:SetPoint("BOTTOMLEFT",book,"BOTTOMLEFT",318,6)
        murloc:SetAlpha(0.23)
        addBackgroundLayer(murloc,1,1,1,true)
        book.murlocIllustration=murloc
        local murlocFades={}
        for i=0,63 do
            local t=i/63
            local strip=book:CreateTexture(nil,"BACKGROUND",nil,4)
            strip:SetPoint("BOTTOMLEFT",book,"BOTTOMLEFT",318,6+i)
            strip:SetSize(186,1)
            strip:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.png")
            strip:SetAlpha(1-t*t*t*(t*(6*t-15)+10))
            addBackgroundLayer(strip,0.504,0.504,0.48888)
            murlocFades[#murlocFades+1]=strip
        end
        local function updateMurlocFade()
            local width,height=book:GetWidth()-8,book:GetHeight()-15
            if width<=0 or height<=0 then return end
            local x=318-6
            for i,strip in ipairs(murlocFades) do
                local y=i-1
                strip:SetTexCoord(x/width,(x+186)/width,1-(y+1)/height,1-y/height)
            end
        end
        book:HookScript("OnSizeChanged",updateMurlocFade)
        updateMurlocFade()
        book.murlocEdgeFades=murlocFades
        -- A small angular prairie dog completes the foreground doodles.
        local prairieDog=book:CreateTexture(nil,"BACKGROUND",nil,3)
        prairieDog:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\BestiaryPrairieDogSketch.png")
        prairieDog:SetSize(113.33,170)
        prairieDog:SetTexCoord(200/256,70/256,37/256,232/256)
        prairieDog:SetPoint("BOTTOM",book,"BOTTOM",69,12)
        prairieDog:SetAlpha(0.28)
        addBackgroundLayer(prairieDog,1,1,1,true)
        book.prairieDogIllustration=prairieDog
        local prairieFades={}
        for i=0,23 do
            local progress=i/23
            local strip=book:CreateTexture(nil,"BACKGROUND",nil,4)
            strip:SetPoint("BOTTOM",book,"BOTTOM",69,12+i)
            strip:SetSize(113.33,1)
            strip:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.png")
            strip:SetAlpha(1-progress*progress*progress*(progress*(6*progress-15)+10))
            addBackgroundLayer(strip,0.504,0.504,0.48888)
            prairieFades[#prairieFades+1]=strip
        end
        local function updatePrairieFade()
            local paperWidth,paperHeight=book:GetWidth()-8,book:GetHeight()-15
            if paperWidth<=0 or paperHeight<=0 then return end
            local x=book:GetWidth()/2+69-113.33/2-6
            for i,strip in ipairs(prairieFades) do
                local y=6+i-1
                strip:SetTexCoord(x/paperWidth,(x+113.33)/paperWidth,
                    1-(y+1)/paperHeight,1-y/paperHeight)
            end
        end
        book:HookScript("OnSizeChanged",updatePrairieFade)
        updatePrairieFade()
        book.prairieDogEdgeFades=prairieFades
        book.koboldFades={}
        -- Mask only the kobold silhouette, keeping surrounding dragon lines.
        book.dragonIllustration={}
        local dragon=book:CreateTexture(nil,"BACKGROUND",nil,0)
        dragon:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\BestiaryDragon.png")
        -- Shift the full illustration 202 pixels right, cropping at the paper edge.
        dragon:SetSize(302,360)
        dragon:SetPoint("TOPRIGHT",book,"TOPRIGHT",-2,-162)
        dragon:SetTexCoord(0,302/540,0,1)
        dragon:SetAlpha(0.33)
        applyIllustrationInk(dragon,"BestiaryDragon.png",0,302/540,0,1)
        book.dragonIllustration[1]=dragon
        -- A shallow 12-pixel fade softens the dragon's cropped right edge.
        local dragonEdge={}
        for i=1,12 do
            local strip=book:CreateTexture(nil,"BACKGROUND",nil,1)
            strip:SetPoint("TOPRIGHT",book,"TOPRIGHT",-2-(i-1),-162);strip:SetSize(1,360)
            strip:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.png")
            strip:SetAlpha(1-(i-1)/11);addBackgroundLayer(strip,0.504,0.504,0.48888)
            dragonEdge[i]=strip;book.dragonIllustration[#book.dragonIllustration+1]=strip
        end
        local function updateDragonFade()
            local width,height=book:GetWidth()-8,book:GetHeight()-15
            if width<=0 or height<=0 then return end
            for i,strip in ipairs(dragonEdge) do
                local x=book:GetWidth()-2-i-6
                strip:SetTexCoord(x/width,(x+1)/width,153/height,513/height)
            end
        end
        book:HookScript("OnSizeChanged",updateDragonFade);updateDragonFade()
        if type(book.CreateMaskTexture)=="function" and type(dragon.AddMaskTexture)=="function" then
            local mask=book:CreateMaskTexture()
            mask:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\BestiaryKoboldSilhouetteMask.png")
            mask:SetSize(960,740)
            mask:SetPoint("BOTTOMRIGHT",book,"BOTTOMRIGHT",-20,-40)
            dragon:AddMaskTexture(mask)
            book.dragonKoboldMask=mask
        end
        -- Sample the same parchment beneath the illustration. These background
        -- strips soften the cropped left/bottom edges without covering controls.
        local gnollFades={}
        local fadeWidth,steps=28,28
        local function addGnollFade(x,y,width,height,alpha,right)
            local strip=book:CreateTexture(nil,"BACKGROUND",nil,4)
            strip:SetPoint("BOTTOMLEFT",book,"BOTTOMLEFT",x,y)
            strip:SetSize(width,height)
            strip:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.png")
            strip:SetAlpha(alpha)
            addBackgroundLayer(strip,0.504,0.504,0.48888)
            gnollFades[#gnollFades+1]={texture=strip,x=x,y=y,width=width,height=height,right=right}
            if right then book.koboldFades[#book.koboldFades+1]=strip end
        end
        for i=1,steps do
            local offset=(i-1)*fadeWidth/steps
            local alpha=1-(i-1)/(steps-1)
            addGnollFade(6+offset,6,fadeWidth/steps,418,alpha)
            addGnollFade(6,6+offset,296,fadeWidth/steps,alpha)
            addGnollFade(22+offset,6,fadeWidth/steps,378,alpha,true)
            addGnollFade(22,6+offset,334,fadeWidth/steps,alpha,true)
        end
        local function updateGnollFadeCoords()
            local width,height=book:GetWidth()-8,book:GetHeight()-15
            if width<=0 or height<=0 then return end
            for _,fade in ipairs(gnollFades) do
                local left=fade.right and book:GetWidth()-fade.x-fade.width or fade.x
                fade.texture:ClearAllPoints()
                fade.texture:SetPoint("BOTTOMLEFT",book,"BOTTOMLEFT",left,fade.y)
                local x,y=left-6,fade.y-6
                fade.texture:SetTexCoord(x/width,(x+fade.width)/width,
                    1-(y+fade.height)/height,1-y/height)
            end
        end
        book:HookScript("OnSizeChanged",updateGnollFadeCoords)
        updateGnollFadeCoords()
        book.gnollCornerFade=ui.IllustrationCornerFade(book,shell,6)
