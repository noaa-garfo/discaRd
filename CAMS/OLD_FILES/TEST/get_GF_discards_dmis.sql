select round(sum(POKGMASS_DISCARD)) POKGMASS_DISCARD
,round(sum(CODGMSS_DISCARD)) CODGMSS_DISCARD
,round(sum(CODGBE_DISCARD)) CODGBE_DISCARD
,round(sum(CODGBW_DISCARD)) CODGBW_DISCARD
,round(sum(FLDSNEMA_DISCARD)) FLDSNEMA_DISCARD
,round(sum(FLWGB_DISCARD)) FLWGB_DISCARD
,round(sum(FLWGMSS_DISCARD)) FLWGMSS_DISCARD
,round(sum(PLAGMMA_DISCARD)) PLAGMMA_DISCARD
,round(sum(YELCCGM_DISCARD)) YELCCGM_DISCARD
,round(sum(HADGBW_DISCARD)) HADGBW_DISCARD
,round(sum(WITGMMA_DISCARD)) WITGMMA_DISCARD
,round(sum(HALGMMA_DISCARD)) HALGMMA_DISCARD
,round(sum(YELGB_DISCARD)) YELGB_DISCARD
,round(sum(FLGMGBSS_DISCARD)) FLGMGBSS_DISCARD
,round(sum(HKWGMMA_DISCARD)) HKWGMMA_DISCARD
,round(sum(REDGMGBSS_DISCARD)) REDGMGBSS_DISCARD
,round(sum(HADGM_DISCARD)) HADGM_DISCARD
,round(sum(OPTGMMA_DISCARD)) OPTGMMA_DISCARD
,round(sum(WOLGMMA_DISCARD)) WOLGMMA_DISCARD
,round(sum(FLWSNEMA_DISCARD)) FLWSNEMA_DISCARD
,round(sum(HADGBE_DISCARD)) HADGBE_DISCARD

,round(sum(YELSNE_DISCARD)) YELSNE_DISCARD

from apsd.dmis_all_years
where fishing_year = 2019


;
left join (
    select distinct(nespp3) as nespp3
    , stock_id
    , comname
    from fso.v_obSpeciesStockArea 
    where stock_id not like 'OTHER'
    group by stock_id, comname
) s
on a.
where fishing_year = 2019
group by nespp3
;

select *
from apsd.dmis_all_years
where fishing_year = 2019

;



select listagg(column_name,'  ')  within group (order by column_name) as column_name
from apsd.dmis_all_years
where table_name = 'FLWGMSS_DISCARD' 