-- apparently there is obdbs info on sector after all... 

select *
from obdbs.sectorcat2019@nova

;

select *
from obdbs.sectorhau2019@nova

;

select *
from obdbs.sectortrp2019@nova

;

select * --distinct(stock_id)
from fso.t_observer_mortality_ratio 

;

select *
from fso.v_obSpeciesStockArea

;

select *
from apsd.em_t_observer_data_output
where fishing_year = 2019

;

--does not exist.. 
--select *
--from fso.t_observer_data_output_2019

;

select *
from fso.t_observer_species_itis


