

select a.*
, case when a.negear IN ('054', '057') then 'lg'
  else a.mesh_cat end as meshgroup
from maps.cams_catch a
/


select *
from cams_catch
where nespp3 = 800
and gearcode is null
and geartype = 'Unknown'
/



select *
--distinct mesh_cat
from cams_catch
where geartype = 'Otter Trawl, Twin'
and mesh_cat = 'SM'
/

select *
from cams_catch
WHERE geartype = 'Sink, Anchor, Drift Gillnet'
AND mesh_cat = 'MM'
/

select *
from cams_catch
WHERE geartype = 'Otter Trawl'
AND mesh_cat = 'XL'


/
UPDATE bg_cams_catch a
SET meshgroup = 'LM'
WHERE a.negear IN ('054', '057') 
/

-- these are probably divers and not likely dredge. Adding them to dredge would have anegligible effect on KALL
UPDATE bg_cams_catch a
SET a.geartype = 'Scallop Dredge'
WHERE a.nespp3 = '800' 
AND a.geartype = 'Unknown'
AND a.gearcode IS NULL	
/

-- this would just change the name from 'unknown' to 'other'
UPDATE bg_cams_catch a
SET a.geartype = 'Other'
WHERE a.geartype = 'Unknown'
AND a.gearcode IS NULL	
/

-- I'm not sure this substitution is valid... 
UPDATE bg_cams_catch
SET meshgroup = 'lg'
WHERE geartype = 'Otter Trawl, Twin'
/                
/*UPDATE bg_cams_catch_mock
SET geartype = 'Otter Trawl'
WHERE geartype = 'Otter Trawl, Twin'*/
/                

-- our table now has MM and LM but no SM mesh.. 
UPDATE bg_cams_catch
SET meshgroup = 'lg'
WHERE geartype = 'Sink, Anchor, Drift Gillnet'
AND meshgroup = 'sm'
/   

-- nothing in our tables for this substitution

UPDATE bg_cams_catch_ta_mock
SET meshgroup = 'lg'
WHERE geartype = 'Otter Trawl'
AND meshgroup = 'xlg'



;

 select a.*
        , ta.sectid
        , ta.activity_code_1
        , ta.activity_code_2
        , ta.activity_code_3
        , permit_EFP_1
        , permit_EFP_2
        , permit_EFP_3
        , permit_EFP_4
        , redfish_exemption
        , closed_area_exemption
        , sne_smallmesh_exemption
        , xlrg_gillnet_exemption
        from 
          MAPS.CFDERS_VTR_IMPUTED a,
          MAPS.STG_TRIP_ATTR ta
        WHERE
        a.CAMSID = ta.CAMSID
/

select a.*
, b.gearnm
, b.GEARCODE
from MAPS.CFDERS_VTR_IMPUTED a, vtr.vlgear b
where a.negear = b.negear


