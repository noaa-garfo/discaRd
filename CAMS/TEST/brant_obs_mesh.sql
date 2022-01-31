/*
Brants OBS  mesh size code from 2016 discard review

ben galuardi

12/17/20

*/

create table maps.BG_OBS_MESH_MOCK as

SELECT * FROM (
SELECT distinct
  g.link3
  ,g.codmsize
  ,g.codlinerusd
  ,g.linermsize
  ,CASE WHEN ROUND(NVL(g.linermsize,g.codmsize)/25.4,2) >=5.75 THEN 'LM'
      WHEN ROUND(NVL(g.linermsize,g.codmsize)/25.4,2) BETWEEN 3.99 AND 5.74 THEN 'MM'
      WHEN ROUND(NVL(g.linermsize,g.codmsize)/25.4,2) <3.99 THEN 'SM'
      END  meshsize_abb
  ,'OBOTGH' source
FROM 
  obdbs.obotgh@nova g
WHERE 
  g.year BETWEEN 2010 AND 2016
UNION ALL
--ASM TRAWL
SELECT distinct
  g.link3
  ,g.codmsize
  ,g.codlinerusd
  ,g.linermsize
  ,CASE WHEN ROUND(LEAST(NVL(g.linermsize,g.codmsize),NVL(g.codmsize,g.linermsize))/25.4,2) >=5.75 THEN 'LM'
      WHEN ROUND(LEAST(NVL(g.linermsize,g.codmsize),NVL(g.codmsize,g.linermsize))/25.4,2) BETWEEN 3.99 AND 5.74 THEN 'MM'
      WHEN ROUND(LEAST(NVL(g.linermsize,g.codmsize),NVL(g.codmsize,g.linermsize))/25.4,2) <3.99 THEN 'SM'
      END  meshsize_abb
  ,'ASMOTGH' source
FROM 
  obdbs.asmotgh@nova g
WHERE 
  g.year BETWEEN 2018 AND 2019
UNION ALL
-- TWIN TRAWL MESHSIZE
SELECT distinct
  h.link3
  ,LEAST(NVL(g.codmsizes,codmsizep),NVL(g.codmsizep,g.codmsizes)) codmsize
  ,DECODE(GREATEST(NVL(g.codlinerusds,codlinerusdp),NVL(g.codlinerusdp,g.codlinerusds)),'0','0','1') codlinerusd
  ,LEAST(NVL(g.linermsizes,linermsizep),NVL(g.linermsizep,g.linermsizes)) linermsize
  ,CASE WHEN ROUND(LEAST(NVL(LEAST(NVL(g.linermsizes,linermsizep)
  ,NVL(g.linermsizep,g.linermsizes))
  ,LEAST(NVL(g.codmsizes,codmsizep)
  ,NVL(g.codmsizep,g.codmsizes)))
  ,NVL(LEAST(NVL(g.codmsizes,codmsizep) , NVL(g.codmsizep,g.codmsizes))
         , LEAST(NVL(g.linermsizes,linermsizep) ,NVL(g.linermsizep,g.linermsizes)))
                        )/25.4,2) >=5.75 THEN 'LM'
      WHEN ROUND(LEAST(NVL(LEAST(NVL(g.linermsizes,linermsizep),NVL(g.linermsizep,g.linermsizes)),LEAST(NVL(g.codmsizes,codmsizep),NVL(g.codmsizep,g.codmsizes))),NVL(LEAST(NVL(g.codmsizes,codmsizep),NVL(g.codmsizep,g.codmsizes)),LEAST(NVL(g.linermsizes,linermsizep),NVL(g.linermsizep,g.linermsizes))))/25.4,2) BETWEEN 3.99 AND 5.74 THEN 'MM'
      WHEN ROUND(LEAST(NVL(LEAST(NVL(g.linermsizes,linermsizep),NVL(g.linermsizep,g.linermsizes)),LEAST(NVL(g.codmsizes,codmsizep),NVL(g.codmsizep,g.codmsizes))),NVL(LEAST(NVL(g.codmsizes,codmsizep),NVL(g.codmsizep,g.codmsizes)),LEAST(NVL(g.linermsizes,linermsizep),NVL(g.linermsizep,g.linermsizes))))/25.4,2) <3.99 THEN 'SM'
      END  meshsize_abb
  ,'OBTTG' source
FROM 
  obdbs.obtth@nova h
  ,obdbs.obttg@nova g
WHERE 
  h.link4 = g.link4
AND h.year BETWEEN 2018 AND 2019
)
;

select * from maps.BG_OBS_MESH_MOCK

;

grant all on maps.BG_OBS_MESH_MOCK to apsd;
grant all on maps.BG_OBS_MESH_MOCK to dmis;
grant all on maps.BG_OBS_MESH_MOCK to bgaluardi;