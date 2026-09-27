local _, ns = ...

-- Presentation only. These sections deliberately have no tracking or saved data.
-- Registration order is the order of the tabs after the two implemented journals.
ns.FieldbookWishlistSections = {
    {
        id="atlas", title="Traveller’s Atlas", icon="Interface\\Icons\\INV_Misc_Map_01",
        wishlist="Build a personal record of caves, ruins, routes, crossings and useful places. Add expedition notes, connect discoveries across Fieldbook sections, and eventually share regional field reports.",
    },
    {
        id="angling", title="Angler’s Almanac", icon="Interface\\Icons\\Trade_Fishing",
        wishlist="Record fish and other catches alongside the waters and fishing spots where they were found. Build a personal catch history and share useful findings with other anglers.",
    },
    {
        id="merchants", title="Merchant’s Ledger", icon="Interface\\Icons\\INV_Misc_Coin_01",
        wishlist="Remember merchants, trainers and useful services encountered during exploration. Record observed goods, recipe sources, locations and access notes.",
    },
    {
        id="treasure", title="Treasure & Salvage", icon="Interface\\Icons\\INV_Misc_TreasureChest01a",
        wishlist="Record discovered chests, locked containers and salvage opportunities. Distinguish sightings from opened finds, with locations, observed contents and personal notes.",
    },
    {
        id="lore", title="Lore & Landmarks", icon="Interface\\Icons\\INV_Misc_Book_09",
        wishlist="Collect references to books, inscriptions, landmarks and noteworthy characters. Keep source-labelled notes, connect related discoveries and record mysteries worth revisiting.",
    },
}

function ns.RegisterFieldbookWishlistSections(shell)
    for _, definition in ipairs(ns.FieldbookWishlistSections) do
        local page=definition
        shell:RegisterSection(page.id,{
            title=page.title, icon=page.icon,
            build=function(content)
                local label=ns.FieldbookUI.Label
                content.title=label(content,page.title,48,-72,864,"GameFontNormalLarge")
                content.title:SetTextColor(1,0.82,0.14)
                content.heading=label(content,"Wishlist for future releases",48,-126,864,"GameFontNormal")
                content.heading:SetTextColor(1,0.82,0.14)
                content.wishlist=label(content,page.wishlist,48,-160,700,"GameFontHighlight")
                content.wishlist:SetWordWrap(true)
                content.wishlist:SetNonSpaceWrap(false)
                content.wishlist:SetSpacing(6)
            end,
        })
    end
end
