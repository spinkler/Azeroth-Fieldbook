"""Regression for the October 2026 audit; synthetic production Lua/UI paths."""
from ui_test_harness import new_ui_client
lua=new_ui_client(['Scrollbars.lua','SharingReport.lua','BestiaryJournal.lua','Sharing.lua','SharingWindow.lua'])
lua.execute(r'''
local S=ns.SharingReport
local peers,wire,delayed={},{},{}
local function peer(name,id)
 local db={};local j=ns.CreateBestiaryJournal(db,function() return nil end)
 db.bestiary.points.earned=5
 if id then local e=j:Ensure(id,false,'Creature '..id);e.category='Humanoid';e.levelMin=8;e.levelMax=8;e.locations.Elwynn=true end
 local p={j=j,db=db,online=true};peers[name]=p
 local env={ready=true,addonVersion=buildVersion,character=name,now=function() return now end,blocked=function() return false end,
 send=function(prefix,message,channel,target)
  if not peers[target].online then delayed[#delayed+1]={sender=name,prefix=prefix,message=message,channel=channel,target=target};return true end
  wire[#wire+1]={sender=name,prefix=prefix,message=message,channel=channel,target=target};return true
 end}
 p.e=ns.CreateSharing(j,env);return p
end
local alice=peer('Alice Sunstrider',42);local bob=peer('Bob Stonewell');local carol=peer('Carol Stormwind',43)
local ui=ns.CreateSharingWindow(bob.j,bob.e)
local function pump(n)
 for _=1,n do
  now=now+1
  for _,p in pairs(peers) do if p.online then p.e:Tick() end end
  local queue=wire;wire={}
  for _,m in ipairs(queue) do local p=peers[m.target];if p.online then p.e:Receive(m.prefix,m.message,m.channel,m.sender) end end
 end
end
assert(alice.e:Start(assert(S.Capture(alice.j,42)),'Bob Stonewell',{}));pump(8)
local f=AzerothFieldbookReceive
assert(f:IsShown() and f.accept:IsEnabled())
f.accept.scripts.OnClick()
local quote=alice.e:GetOutgoing().cost
alice.online=false
f:Hide();pump(1)
assert(carol.e:Start(assert(S.Capture(carol.j,43)),'Bob Stonewell',{}));pump(8)
assert(#bob.e:GetIncoming()==2)
assert(bob.e:GetIncoming()[1].sender=='Alice Sunstrider' and bob.e:GetIncoming()[1].state=='accepted')
assert(bob.e:GetIncoming()[2].sender=='Carol Stormwind' and bob.e:GetIncoming()[2].state=='pending')
assert(bob.j:PreviewReport(bob.e:GetIncoming()[2].report,'Carol Stormwind'), 'Second offer is valid and ready to accept')
assert(f:IsShown(), 'A new pending offer must be reachable')
for _,item in ipairs(bob.e:GetIncoming()) do print('queue '..item.sender..' state='..item.state) end
ui:OpenIncoming()
assert(f.from:GetText()=='Offered by Carol Stormwind' and f.accept:IsEnabled(), 'Pending offer must take priority over retained consent')
ui:OpenIncoming()
assert(f.from:GetText()=='Offered by Carol Stormwind' and f.accept:IsEnabled())
f.accept.scripts.OnClick();pump(12)
assert(bob.j.entries[43])
alice.online=true
for _,m in ipairs(delayed) do peers[m.target].e:Receive(m.prefix,m.message,m.channel,m.sender) end
pump(12)
assert(bob.j.entries[42])
local spent=alice.db.bestiary.points.spent
for _,m in ipairs(delayed) do peers[m.target].e:Receive(m.prefix,m.message,m.channel,m.sender) end
pump(12)
assert(alice.db.bestiary.points.spent==spent and spent==quote)
''')
