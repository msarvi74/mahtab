create or replace procedure prc_mahtab_ledgercalc_v2 as 
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/
  /*
  procedure Programmers Name:  sarvi
  Editor Name: 
  Release Date/Time:
  Edit Name: 
  Version: 1
  Description: new procedure for mahtab ledger calculation
  */ 
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/

v_lvl number;

begin
/* 
name: ساخت جدول درختواره گروه ها
stage: 1
*/ 
execute immediate 'truncate table stg_groups_balances';
--ebteda meghdar group hayee ke be account vasl hastand mohasebe mishavad va ba yek manfi ghableshan dar jadval rikhte mishavad
--dalil manfi be dalil in ast ke be rahati faghat ba jam zadan betavan mohasebe kard chera ke mahiate in hesab ha kam kardani ast
insert into stg_groups_balances (
 ID
,BALANCE
,LVL)
with group_tree(id,parent_id,zarib,lvl) as (
select id,parent_id,zarib,0 as lvl 
from alm_admin.mhtb_groups
where parent_id is null
union all 
select mg.id,mg.parent_id,mg.zarib,gt.lvl+1
from group_tree gt
join alm_admin.mhtb_groups mg
on mg.parent_id=gt.id
),
test_account as 
(select a.ex_account,b.balance_rial*a.ex_zarib as balance from alm_admin.mhtb_exaccount a join alm_admin.mhtb_balance_he b on a.ex_account=b.account)
select c.id,-sum(balance)*c.zarib as balance,c.lvl 
from test_account a join alm_admin.mhtb_exaccount b on a.ex_account=b.ex_account join group_tree c on b.group_id=c.id 
group by c.id,c.lvl,c.zarib;
commit;

--dar in marhale group hayee ke be gl vasl mishavand mohasebe mishavand
insert into stg_groups_balances (
 ID
,BALANCE
,LVL)
with group_tree(id,parent_id,zarib,lvl) as (
select id,parent_id,zarib,0 as lvl 
from alm_admin.mhtb_groups
where parent_id is null
union all 
select mg.id,mg.parent_id,mg.zarib,gt.lvl+1
from group_tree gt
join alm_admin.mhtb_groups mg
on mg.parent_id=gt.id
),test_gl as
(select a.group_id,a.gl,b.balance_rial*a.zarib as balance ,0 as depth from alm_admin.mhtb_group_gl a join alm_admin.mhtb_balance_he b on a.gl=b.kolcode||b.moeincode or a.gl=b.kolcode)
select c.id,sum(balance)*c.zarib as balance,c.lvl 
from test_gl a join alm_admin.mhtb_group_gl b on a.gl=b.gl and a.group_id=b.group_id join group_tree c on b.group_id=c.id 
group by c.id,c.lvl,c.zarib;
commit;


--peda kardane max omgh derakht group
select max(lvl) into v_lvl from stg_groups_balances;
--sakht roo be balaye derakhtvare group ha be hamrah balance ha
for i in reverse 0..v_lvl loop
insert into stg_groups_balances (
 ID
,BALANCE
,LVL)
with group_tree(id,parent_id,zarib,lvl) as (
select id,parent_id,zarib,0 as lvl 
from alm_admin.mhtb_groups
where parent_id is null
union all 
select mg.id,mg.parent_id,mg.zarib,gt.lvl+1
from group_tree gt
join alm_admin.mhtb_groups mg
on mg.parent_id=gt.id
)
select  a.parent_id,sum(b.balance),a.lvl -1 
from group_tree a join stg_groups_balances b on a.id=b.id and b.lvl=i 
group by a.parent_id,a.lvl ;
commit;
end loop;


/* 
name: ساخت درختواره مهتاب
stage: 2
*/ 
--dar in marhale ebteda barg haye mahtab sakhte mishavand
insert into tbl_mahtab_gap_ledger (
 LEDGER_CODE
,PARENT_CODE
,BALANCE
,NAME
,IFRS
,DEPTH)
with mahtab_tree (id,title,parent_id,ifrs,lvl)  as 
(
select id,title,parent_id,ifrs,0
from alm_admin.mhtb_mahtabtree 
where parent_id is null
union all
select mm.id,mm.title,mm.parent_id,mm.ifrs,mt.lvl+1
from mahtab_tree mt
join alm_admin.mhtb_mahtabtree mm
on mm.parent_id=mt.id
)
select a.id,a.parent_id,sum(c.balance) balance,a.title,a.ifrs,a.lvl 
from mahtab_tree a join alm_admin.mhtb_mahtabtree_group b on a.id=b.mahtabtree_id join stg_groups_balances c on b.group_id=c.id 
group by a.id,a.title,a.parent_id,a.ifrs,a.lvl ;
commit;

--insert kardane barg hayee ke be hesab ya group motasel naboodand ba meghdar 0
insert into tbl_mahtab_gap_ledger (
 LEDGER_CODE
,PARENT_CODE
,BALANCE
,NAME
,IFRS
,DEPTH)
with mahtab_tree (id,title,parent_id,ifrs,lvl)  as 
(
select id,title,parent_id,ifrs,0
from alm_admin.mhtb_mahtabtree 
where parent_id is null
union all
select mm.id,mm.title,mm.parent_id,mm.ifrs,mt.lvl+1
from mahtab_tree mt
join alm_admin.mhtb_mahtabtree mm
on mm.parent_id=mt.id
)
select id,parent_id,0 as balance,title,ifrs,lvl  
from mahtab_tree where id not in (select distinct parent_id from mahtab_tree where parent_id is not null) 
and id not in (select LEDGER_CODE from tbl_mahtab_gap_ledger);
commit;

--peyda kardane max omgh derakhtvare mahtab
select max(DEPTH) into v_lvl from tbl_mahtab_gap_ledger;
--sakht derakhtvare mahtab roo be bala
for i in reverse 0..v_lvl loop
insert into tbl_mahtab_gap_ledger (
 LEDGER_CODE
,PARENT_CODE
,BALANCE
,NAME
,IFRS
,DEPTH) 
with mahtab_tree (id,title,parent_id,ifrs,lvl)  as 
(
select id,title,parent_id,ifrs,0
from alm_admin.mhtb_mahtabtree 
where parent_id is null
union all
select mm.id,mm.title,mm.parent_id,mm.ifrs,mt.lvl+1
from mahtab_tree mt
join alm_admin.mhtb_mahtabtree mm
on mm.parent_id=mt.id
)
select a.id,a.parent_id,sum(b.balance) balance,a.title,a.ifrs,a.lvl 
from mahtab_tree a join tbl_mahtab_gap_ledger b on a.id=b.PARENT_CODE and b.DEPTH=i 
group by a.id,a.title,a.parent_id,a.ifrs,a.lvl,b.PARENT_CODE ;
commit;
end loop;


end;