"""A6: bounded rows with full history, stable page anchor and hidden catch-up."""
from ledger_test_harness import new_ledger
lua=new_ledger(True)
lua.execute("""
    AzerothFieldbookLedgerDB={};balance=1000
    function GetMoney() return balance end
    t:Money();c:CashFlow();read=c.panels.cashFlow.read
    for _,count in ipairs({100,1000,5001}) do
        local texts,keys={},{}
        for i=1,count do texts[i]='Transaction '..i;keys[i]={id=i} end
        read:SetTransactions('All totals',texts,keys)
        assert(#read.transactionRows==25)
        print('Cash Flow rows for '..count..' records: '..#read.transactionRows)
        local objectsBefore=#objects
        local visited={}
        repeat
            for i=read.first,math.min(#texts,read.first+24) do visited[i]=true end
            if read.first+24>=#texts then break end
            read:TurnPage(1)
        until false
        for i=1,count do assert(visited[i],'older entry inaccessible') end
        assert(#objects==objectsBefore,'paging allocated more widgets')
        read:TurnPage(-1) -- Use a scrollable page, not a final one-row page.
        read:SetVerticalScroll(35)
        local anchor=keys[read.first]
        table.insert(keys,1,{id=0});table.insert(texts,1,'New income')
        read:SetTransactions('Updated totals',texts,keys)
        assert(keys[read.first]==anchor and read:GetVerticalScroll()==35)
        read.first=1;read.keys=nil
    end
    local render=read.SetTransactions;local renders=0
    function read:SetTransactions(...) renders=renders+1;return render(self,...) end
    shell:ShowSection('other');local before=#objects
    balance=balance+5;t:Money()
    assert(#AzerothFieldbookLedgerDB.cashFlow.entries==1)
    assert(renders==0 and #objects==before)
    shell:ShowSection('merchants')
    assert(renders>0 and #read.transactions==1)
    assert(read.transactionRows[1]:IsShown())
""")
print('PASS: A6 <=25 rows for 100/1000/5001 entries, complete paging, anchor, hidden updates/reopen')
