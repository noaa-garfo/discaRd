/*
    
    Convert names for first part of table creation process.. 
    
    make catch table
    
    Will need to check subsequent steps for naming compatibility
    
    6/1/21
    
    B. Galuardi

*/

SELECT a.camsid
, a.docid
, a.vtrserno
, a.VTR_AREA
, a.VTR_CAREA
, a.record_land
--, a.DLR_STATE
--, a.FISHING_YEAR
--, a.LINK1
, substr(a.DLR_NESPP4, 1,3) as NESPP3
, a.DLR_NESPP4
, a.DLR_SPECIES_ITIS
, a.DLR_LIVLB as POUNDS
, a.VTR_MESH
--, a.MONTH
, a.PERMIT 
--, a.sector_id
--, a.activity_code_1
--, a.activity_code_2
--, a.activity_code_3
--, permit_EFP_1
--, permit_EFP_2
--, permit_EFP_3
--, permit_EFP_4
--, redfish_exemption
--, closed_area_exemption
--, sne_smallmesh_exemption
--, xlrg_gillnet_exemption
, extract(year from a.record_land) as year
, extract(month from a.record_land) as month
--, a.YEAR||a.ID yearid
, b.gearnm
, b.GEARCODE
, b.NEGEAR
, b.NEGEAR2
--,  (CASE WHEN (month IN (1,2,3,4,5,6)) then 1 
--          WHEN (month IN (7,8,9,10,11,12)) then 2 
--        END) as halfofyear
        , (CASE WHEN vtr_area < 600 THEN 'N'
                WHEN vtr_area >= 600 THEN 'S'
                ELSE 'Other'
                END) as region
,  (case when vtr_area in (511, 512, 513, 514, 515, 521, 522, 561) 
                then 'N' 
                 when vtr_area  NOT IN (511, 512, 513, 514, 515, 521, 522, 561)
               then 'S'
                 else 'Unknown' end)  as stockarea 
, (CASE WHEN negear IN ('070') THEN 'Beach Seine'
			    WHEN negear IN ('020', '021') THEN 'Handline'
  			   	WHEN negear IN ('010') THEN 'Longline'
				WHEN negear IN ('170', '370') THEN 'Mid-water Trawl, Paired and Single'
				WHEN negear IN ('350','050') THEN 'Otter Trawl'
				WHEN negear IN ('057') THEN 'Otter Trawl, Haddock Separator'
				WHEN negear IN ('054') THEN 'Otter Trawl, Ruhle'
				WHEN negear IN ('053') THEN 'Otter Trawl, Twin'
				WHEN negear IN ('181') THEN 'Pots+Traps, Fish'
				WHEN negear IN ('186') THEN 'Pots+Traps, Hagfish'
				WHEN negear IN ('120','121', '123') THEN 'Purse Seine'
				WHEN negear IN ('132') THEN 'Scallop Dredge'
				WHEN negear IN ('052') THEN 'Scallop Trawl'
				WHEN negear IN ('058') THEN 'Shrimp Trawl'
				WHEN negear IN ('100', '105','110', '115','116', '117','500') THEN 'Sink, Anchor, Drift Gillnet'
				WHEN negear NOT IN 
				('070','020', '021','010','170','370','350','050','057','054','053','181',
				'186','120','121', '123','132','052','058','100', '105', '110','115','116', '117','500') THEN 'Other' 
				WHEN negear IS NULL THEN 'Unknown'
				END) as  geartype
,                 
(CASE WHEN vtr_mesh < 5.5 AND negear IN ('050','054','057','100','105','115','116','117','350','500') THEN 'sm'
	  WHEN vtr_mesh BETWEEN 5.5 AND 7.99 AND negear IN ('050','054','057','100','105','115','116','117','350','500') THEN 'lg'
	  WHEN vtr_mesh >= 8 AND negear IN ('050','054','057','100','105','115','116','117','350','500') THEN 'xlg'
	  ELSE NULL
	  END)  as meshgroup
--,  (CASE WHEN activity_code_1 NOT LIKE 'SES%' THEN 'all'
--			    WHEN activity_code_1 LIKE 'SES-SCG%' THEN 'GEN'
--  			   	WHEN activity_code_1 LIKE 'SES-SAA%' THEN 'LIM'
--                WHEN activity_code_1 LIKE 'SES-SCA%' THEN 'LIM'
--                WHEN activity_code_1 LIKE 'SES-RSA%' THEN 'LIM'
--                WHEN activity_code_1 LIKE 'SES-SWE%' THEN 'LIM'
--				ELSE 'all'
--				END) as tripcategory   
--, (CASE WHEN activity_code_1 NOT LIKE 'SES%'
--                    OR activity_code_1 LIKE 'SES-PWD%' 
--                THEN 'all'
--			    WHEN activity_code_1 LIKE 'SES-SAA%' 
--                 OR activity_code_1 LIKE 'SES%DM%'                  
--                  OR activity_code_1 LIKE 'SES%HC%'
--                   OR activity_code_1 LIKE   'SES%1S%'
--                   OR activity_code_1 LIKE   'SES%2S%'
--                    OR activity_code_1 LIKE  'SES%ET%'
--                     OR activity_code_1 LIKE 'SES%NS%'
--                     OR activity_code_1 LIKE 'SES%MA%'
--                     OR activity_code_1 LIKE 'SES%EF%'
--                     OR activity_code_1 LIKE 'SES%NH%'
--                     OR activity_code_1 LIKE 'SES%NW%'
--                     OR activity_code_1 LIKE 'SES%NN%'
----                  OR activity_code_1 LIKE 'SES-RSA-DM%'                  
----                  OR activity_code_1 LIKE 'SES-RSA-HC%'
----                   OR activity_code_1 LIKE   'SES-RSA-1S%'
----                   OR activity_code_1 LIKE   'SES-RSA-2S%'
----                    OR activity_code_1 LIKE  'SES-RSA-ET%'
----                     OR activity_code_1 LIKE 'SES-RSA-NS%'
----                     OR activity_code_1 LIKE 'SES-RSA-MA%'
----                     OR activity_code_1 LIKE 'SES-RSA-EF%'
----                     OR activity_code_1 LIKE 'SES-RSA-NH%'
----                     OR activity_code_1 LIKE 'SES-RSA-NW%'
----                     OR activity_code_1 LIKE 'SES-RSA-NN%'
--                     THEN 'AA'
--  			   	WHEN activity_code_1 LIKE 'SES-SCA-OP%'
--                     OR activity_code_1 LIKE 'SES-RSA-OP%'
--                     OR activity_code_1 LIKE 'SES-RSA-XX%'
--                     OR activity_code_1 LIKE 'SES-SWE-OP%'
--                      OR activity_code_1 LIKE 'SES-SCG-OP%'
--                      OR activity_code_1 LIKE 'SES-SCG-SN%'
--                      OR activity_code_1 LIKE 'SES-SCG-NG%'
--                      THEN 'OPEN'
--				ELSE 'all'
--				END) as accessarea              
    FROM (
        select a.*
--        , ta.sector_id
--        , ta.activity_code_1
--        , ta.activity_code_2
--        , ta.activity_code_3
--        , permit_EFP_1
--        , permit_EFP_2
--        , permit_EFP_3
--        , permit_EFP_4
--        , redfish_exemption
--        , closed_area_exemption
--        , sne_smallmesh_exemption
--        , xlrg_gillnet_exemption
        from 
          maps.cfders_vtr_apportionment a
--          , apsd.cams_trip_attribute ta
--        WHERE
--        a.camsid = ta.camsid
      ) a
  
--FROM apsd.dmis_all_years  a 
    LEFT OUTER JOIN vtr.vlgear b
    ON a.VTR_GEAR = b.GEARCODE