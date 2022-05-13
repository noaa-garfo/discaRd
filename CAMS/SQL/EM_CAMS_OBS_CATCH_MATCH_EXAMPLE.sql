/*

    Match an EM table with CAMS_OBS_CATCH using gear-mesh-area startificaiton.. 
    
    WHERE WILL THIS BREAK??
    
    B. Galuardi
    
    5/13/22


*/

-- run from APSD for now. 

with em19 as (
    SELECT b.*
    ,  b.secgearfish||'-'||b.meshgroup||'-'||b.area as em_strata
    , i.itis_tsn
    , i.dlr_sppname
    FROM (
     select a.*
     , case when mesh_cat is null then 'NA' 
            when mesh_cat = 'ELM' then 'XL'
            else mesh_cat end as meshgroup
     from APSD.GF_EM_FINAL a
     where fishing_year = 2019
    ) b
    left join (select * from cams_garfo.cfg_nespp3_itis) i
    on b.nespp3 = i.dlr_nespp3
    ORDER BY vtr_land
)
, cams as (
 select d.*
 , d.secgear_mapped||'-'||d.MESHGROUP2||'-'||d.area as cams_strata
     from (
         select c.*
         , case when meshgroup = 'na' then 'NA' else meshgroup end as meshgroup2
         from maps.cams_obs_catch c
        -- where docid = 5217880
    ) d

)

select round(sum(e.pounds), 1) as EM_DISCARD
, e.stock_id
, e.itis_tsn
, e.dlr_sppname
, e.em_strata
, c.cams_strata
, c.docid
, cams_subtrip
from cams c, em19 e
where GF = 1
and c.docid = e.docid
and c.cams_strata  = e.em_strata
and disposition  = 'DISCARD'
and e.ITIS_TSN is not null
--and c.docid = 5217880
group by c.docid
,  c.cams_strata
, c.cams_subtrip
, e.stock_id
, e.nespp3
, e.em_strata
, e.itis_tsn
, e.dlr_sppname

order by docid, cams_subtrip, EM_STRATA
;

-- example of one trip with three subtrips

select *
from maps.cams_obs_catch
where docid = 5217880
;

-- now try matching the above to discards.. 


with em19 as (
    SELECT b.*
    ,  b.secgearfish||'-'||b.meshgroup||'-'||b.area as em_strata
    , i.itis_tsn
    , i.dlr_sppname
    , s.discard_source
    FROM (
     select a.*
     , case when mesh_cat is null then 'NA' 
            when mesh_cat = 'ELM' then 'XL'
            else mesh_cat end as meshgroup
     from APSD.GF_EM_FINAL a
     where fishing_year = 2019
    ) b
    left join (select * from cams_garfo.cfg_nespp3_itis) i
    on b.nespp3 = i.dlr_nespp3
    
--    left join (SELECT * FROM APSD.GF_EM_AUDIT_SELECTION_ARCH) s -- add discard source for EM trip
--    on b.docid = s.docid
    
    ORDER BY b.vtr_land
)
, cams as (
 select d.*
 , d.secgear_mapped||'-'||d.MESHGROUP2||'-'||d.area as cams_strata
     from (
         select c.*
         , case when meshgroup = 'na' then 'NA' else meshgroup end as meshgroup2
         from maps.cams_obs_catch c
        -- where docid = 5217880
    ) d

)

, emd as ( select round(sum(e.pounds), 1) as EM_DISCARD
    , e.stock_id
    , e.itis_tsn
    , e.dlr_sppname
    , e.em_strata
    , c.cams_strata
    , c.docid
    , c.vtrserno
    , c.camsid
    , cams_subtrip
    from cams c, em19 e
    where GF = 1
    and c.docid = e.docid
    and c.cams_strata  = e.em_strata
    and disposition  = 'DISCARD'
    and e.ITIS_TSN is not null
    --and c.docid = 5217880
    group by c.docid
    ,  c.cams_strata
    , c.cams_subtrip
    , e.stock_id
    , e.nespp3
    , e.em_strata
    , e.itis_tsn
    , e.dlr_sppname
    , c.vtrserno
    , c.camsid
    
    order by docid, cams_subtrip, EM_STRATA
)


select  e.cams_subtrip
, e.EM_DISCARD
, e.itis_tsn as EM_ITIS
, e.em_strata 
, e.stock_id
 , s.discard_source
 , g.*
from cams_garfo.cams_discard_example_gf2019 g
left join (select * from emd) e
    on (g.camsid = e.camsid and g.vtrserno = e.vtrserno and g.species_itis = e.itis_tsn)

where EM_STRATA is not null
and g.camsid = '242648_20200312045800_24264820031117'
order by g.vtrserno, species_itis


;

grant select on cams_garfo.cams_discard_example_gf2019 to apsd

/
 with tab as (
   SELECT b.*
    ,  b.secgearfish||'-'||b.meshgroup||'-'||b.area as em_strata
    , i.itis_tsn
    , i.dlr_sppname
    , s.discard_source
    FROM (
     select a.*
     , case when mesh_cat is null then 'NA' 
            when mesh_cat = 'ELM' then 'XL'
            else mesh_cat end as meshgroup
     from APSD.GF_EM_FINAL a
     where fishing_year = 2019
     and a.disposition  = 'DISCARD'
    ) b
    left join (select * from cams_garfo.cfg_nespp3_itis) i
    on b.nespp3 = i.dlr_nespp3
    left join (SELECT * FROM APSD.GF_EM_AUDIT_SELECTION_ARCH) s -- add discard source for EM trip
    on b.docid = s.docid
    
    ORDER BY b.vtr_land
    )
    
 select count(distinct(discard_source))
 , dlr_sppname
 , docid
 from tab
 group by docid, dlr_sppname

/
24264820032416