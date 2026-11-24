local _,ns=...
local codec={}
ns.ComparisonCodec=codec

-- Compress independently bounded blocks. The client inflater has no per-call
-- output limit. Reject a bad block before asking it to inflate the next one.
local BLOCK=4096
function codec.Available(api)
    return api and type(api.CompressString)=="function" and type(api.DecompressString)=="function"
        and type(api.EncodeBase64)=="function" and type(api.DecodeBase64)=="function"
end
local function result(fn,input)
    local ok,value=pcall(fn,input)
    if ok and ns.SharingReport.Public(value) and type(value)=="string" and #value>0 then return value end
end

-- All three comparison streams and both report schemas start with a character
-- other than Z. Their original wire representation is always a valid fallback.
function codec.Pack(api,text,chunk)
    if #text<=chunk or not codec.Available(api) then return text end
    local parts={"Z",tostring(#text),":"}
    for pos=1,#text,BLOCK do
        local block=text:sub(pos,pos+BLOCK-1)
        local binary=result(api.CompressString,block)
        local encoded=binary and #binary<#block and result(api.EncodeBase64,binary)
        if encoded and #encoded<#block then
            parts[#parts+1]=#encoded..":"..encoded
        else
            parts[#parts+1]="0:"..block
        end
    end
    local packed=table.concat(parts)
    if math.ceil(#packed/chunk)<math.ceil(#text/chunk) then return packed end
    return text
end

local function lengthAt(text,pos)
    local digits=text:sub(pos,pos+7):match("^(%d+):")
    if digits then return tonumber(digits),pos+#digits+1 end
end
function codec.Unpack(api,text,limit)
    if #text>limit then return end
    if text:sub(1,1)~="Z" then return text end
    if not codec.Available(api) then return end
    local total,pos=lengthAt(text,2)
    if not total or total>limit or total<=#text then return end
    local blocks={}
    for offset=1,total,BLOCK do
        local expected=math.min(BLOCK,total-offset+1)
        local size,start=lengthAt(text,pos)
        if not size or size>=expected then return end
        local block
        if size==0 then
            block=text:sub(start,start+expected-1)
            pos=start+expected
        else
            if start+size-1>#text or size%4==1 then return end
            local encoded=text:sub(start,start+size-1)
            if not encoded:match("^[A-Za-z0-9+/]+=?=?$") then return end
            if encoded:sub(-1)=="=" and size%4~=0 then return end
            local binary=result(api.DecodeBase64,encoded)
            block=binary and result(api.DecompressString,binary)
            pos=start+size
        end
        if not block or #block~=expected then return end
        blocks[#blocks+1]=block
    end
    if pos==#text+1 then return table.concat(blocks) end
end
