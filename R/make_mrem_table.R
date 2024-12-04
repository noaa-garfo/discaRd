#'  Build MREM KALL adjustment table
#'make a table for yourself since ITD won't let you make a View... ----
#' Make MREM adjustment table on the fly
#' This currently lives at GARFO as a VIew. Thus, it is not ported to NEFSC via TTS. NEFSC IT goons do not allow Oracle View creation so the code can't simply be shared in a normal fashion. This function is the work around. It will generate a MREM KALL adjustment table in the users worksapce. This is needed when pulling data for a CAMS discard diagnostic run.
#'
#' @param con database connection
#'
#' @return
#' @export
#'
#' @examples
make_mrem_table <- function(con){

  mrem = tbl(acon, sql("
with cams_landings as (
SELECT
    l.CAMSID,
l.DOCID,
l.VTRSERNO,
s.RECORD_SAIL,
s.RECORD_LAND,
s.DATE_TRIP,
l.DLR_DATE,
l.YEAR,
l.MONTH,
l.WEEK,
l.DLRID,
l.DLR_CFLIC,
l.PERMIT,
l.DLR_STID,
l.PERMIT_STATE_FED,
s.GF,
s.LOBSTER_CLASS,
s.MAIN_SPP_GRP,
s.MAIN_PORT_GRP,
l.STATE,
l.PORT,
l.BHC,
s.VTR_TRIPCATG,
s.VTR_CREW,
s.N_SUBTRIP,
l.SUBTRIP,
s.VTR_DEPTH,
s.VTR_IMGID,
l.DLR_RPTID,
l.DLR_DOCN,
l.DLR_UTILCD,
l.DLR_SOURCE,
l.DLR_TONCL,
l.FZONE,
s.LAT_DD,
s.LON_DD,
s.VTR_ACTIVITY,
s.VTR_ACTIVITY_DESC,
l.VTR_CATCHID,
l.VTR_DLRID,
l.VTR_DISCARD,
--l.HULLID,
s.VES_LEN,
s.VES_GTONS,
l.ITIS_TSN,
l.ITIS_GROUP1,
i.DLR_NESPP3 NESPP3,
l.DLR_MKT,
l.DLR_GRADE,
l.DLR_DISP,
l.DLR_CATCH_SOURCE,
l.LNDLB,
l.LIVLB,
l.VALUE,
l.LANDING_SOURCE,
l.STATUS,
l.REC,
l.NEMAREA,
l.AREA,
l.AREA_HERR,
s.FMCODE,
l.NEGEAR,
l.VTR_MESH,
l.MESH_CAT,
s.VTR_GEAR_SIZE,
s.VTR_GEAR_QTY,
l.AREA_SOURCE,
l.AREA_IMP_METHOD,
l.AREA_PROP,
l.GEAR_SOURCE,
l.GEAR_IMP_METHOD,
l.NEGEAR_PROP,
l.MESH_SOURCE,
l.MESH_IMP_METHOD,
l.MESH_PROP,
l.SECTID,
s.ACTIVITY_CODE_1,
s.ACTIVITY_CODE_2,
s.EM,
s.REDFISH_EXEMPTION,
s.CLOSED_AREA_EXEMPTION,
s.SNE_SMALLMESH_EXEMPTION,
s.XLRG_GILLNET_EXEMPTION,
s.EXEMPT_7130,
s.TRIPCATEGORY,
s.ACCESSAREA,
l.REGION,
s.GEARTYPE,
l.DATE_RUN
FROM
    cams_garfo.CAMS_LAND l
LEFT JOIN
    cams_garfo.CAMS_SUBTRIP s
    ON l.camsid = s.camsid
    AND l.subtrip = s.subtrip
LEFT JOIN
    (select distinct itis_tsn, dlr_nespp3 from cams_garfo.cfg_itis) i
    ON l.itis_tsn = i.itis_tsn
)

, legal as (
    SELECT VTRSERNO
    , camsid||'_'||subtrip as cams_subtrip
    , ITIS_TSN
    , sum(case when (dlr_mkt <> 'X2' or dlr_mkt is null) then livlb else 0 end) as legal
    , sum(case when dlr_mkt = 'X2' then livlb else 0 end) as sublegal
    FROM cams_landings
    WHERE EM = 'MREM'
     group by VTRSERNO
     , camsid||'_'||subtrip
    , ITIS_TSN
)

, match as(
    select vtrserno
    , cams_subtrip
    , itis_tsn
    , legal
    , sublegal
    ,legal + sublegal  as TOTAL
    FROM legal

    )

 ,final as (
     select a.vtrserno
     , a.cams_subtrip
      ,a.itis_tsn
      ,a.legal
      ,a.sublegal
      , case when a.legal > 0 and a.sublegal > 0 then nvl(a.legal/a.TOTAL,0) else 0 end as PERCENT_LEGAL
      , SUM(a.legal) OVER(PARTITION BY a.cams_subtrip) as kall_mrem_adj
      , SUM(a.total) OVER(PARTITION BY a.cams_subtrip) as kall
      FROM match a
      )

  Select
    VTRSERNO
    , CAMS_SUBTRIP
    , ITIS_TSN,LEGAL
    , SUBLEGAL
    , PERCENT_LEGAL
    , KALL_MREM_ADJ
    , KALL
  , case when kall > 0 then KALL_MREM_ADJ/KALL else 1 end as KALL_MREM_ADJ_RATIO
  FROM final
  WHERE ITIS_TSN in ('164712',
                   '164727',
                   '164744',
                   '172877',
                   '172905',
                   '172909',
                   '172873',
                   '164791',
                   '166774')

                   "))

mrem = mrem |>
  collect()

mrem
}
