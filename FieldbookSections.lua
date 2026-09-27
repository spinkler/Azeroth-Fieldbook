local _, ns = ...

-- Presentation only. These sections deliberately have no tracking or saved data.
-- Registration order is the order of the tabs after the four implemented journals.
ns.FieldbookWishlistSections = {
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
            help="|cffffd100Wishlist for future releases|r\n"..page.wishlist..
                "\n\nThis section is a preview of planned features. It does not collect or save data yet.\n\nUse the tabs on the right to browse other sections. The Options cog opens the shared Fieldbook settings.",
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
