local _, ns = ...

-- All seven section slots now have implementations. Keep the extension point
-- for registration callers without retaining a duplicate Lore placeholder.
ns.FieldbookWishlistSections = {}

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
