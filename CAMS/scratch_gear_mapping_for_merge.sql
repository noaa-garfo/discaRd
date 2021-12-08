select * from obs_cams_prorate


/

select meshgroup
, negear
, geartype
, ROUND(MESHSIZE,2)
, count(*)
from bg_obdbs_tables_5_&year
where meshgroup is not null
and negear in (115, 116, 117)
group by 
meshgroup
, ROUND(MESHSIZE, 2)
, negear
, geartype
order by  negear, meshgroup desc
/

select distinct(negear)
, geartype
from bg_obdbs_tables_5_&year
/

select *
from apsd.master_gear
/

select distinct(negear)
, meshgroup
from 
bg_cams_obs_catch

/

-- look at mesh size vs meshgroup in DLR_VTR

select --negear
--, dlr_negear
vtr_mesh
, mesh_cat
, negear
, count(*)
from maps.dlr_vtr
where negear in (100, 115, 116, 117)
and status = 'MATCH'
group by mesh_cat
, negear
, vtr_mesh
order by vtr_mesh

/

-- look at top level obs table for gear 
select  negear
, obs_source
, gearcat
, count(distinct(link3))
--*
from bg_obdbs_tables_1_&year
where negear in (115, 116, 117)
--and gearcat = 'GG'
group by negear
, obs_source
, gearcat
/

--look at OBHAU
select * from obdbs.obhau@nova
where year = 2019
and negear in (115, 116, 117)
/

select geartype
, meshgroup
, obs_gear
, count(distinct(link1))
from apsd.obs_cams_prorate
where obs_gear in (115, 116,117)
and year = 2019
group by geartype
, meshgroup
, obs_gear
/

select distinct(substr(obs_gear,1,2)) as negear2
, obs_gear
from apsd.obs_cams_prorate
group by obs_gear

/ 
-- get link1 from obs prorate table where negear is 116 117
--- get CAMSID for those obs link1
-- get catch info for those CMASIDs

select count(distinct(camsid))
, negear
, gearnm
, mesh_cat
from
maps.cams_catch
    where camsid in (
    select distinct(camsid) camsid
    from maps.match_obs
        where obs_link1 in(
            select distinct(link1) as link1
            from apsd.obs_cams_prorate
            where obs_gear in (115, 116, 117)
            and year = 2019
        )
)
group by gearnm
, mesh_cat
, negear

/

select * from obdbs.obgear@NOVA o
/
select o.negear as obs_negear
, o.gearnm
, v.negear as vl_negear
, o.secgearfish
from obdbs.obgear@NOVA o
left join(
    select * from maps.cfg_vlgear 
) v
on o.negear = v.negear

/

select distinct(secgearfish_2)
, obs_negear
, gearnm
, vtr_negear
--, vtr_gear_code
--, secgearfish
from
(
    select o.negear as obs_negear
    , o.gearnm
    , v.negear as vtr_negear
    , v.vtr_gear_code
    , o.secgearfish
    , coalesce(o.secgearfish, v.vtr_gear_code) as secgearfish_2
    from obdbs.obgear@NOVA o
        left join(
            select * from maps.cfg_fvtr_gear
        ) v
        on o.negear = v.negear
    
        left join(
            select * from maps.cfg_vlgear 
        ) vl
        on o.negear = vl.negear
)
order by obs_negear
/

-- look at gearcat in opbdbs tables.. 

select *
from obdbs.obtrp@NOVA
where year = 2019
/

-- see all gearcode from cams_catch

select distinct(gearcode)
, gearnm
, vtr_gear_code
from maps.cams_catch c
left join (
  select * from maps.cfg_fvtr_gear
) vl
on c.GEARCODE = vl.vtr_gear_code
order by gearcode
/

/*   Use new gear mapping table */



