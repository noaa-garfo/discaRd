-- !preview conn <- ROracle::dbConnect( drv = ROracle::Oracle(), username = dw_apsd$uid, password = dw_apsd$pwd,  dbname = "NERO.world")


select a.*
    from (
 select o.link3
            , link1
            , vtrserno
            , extract(year from dateland) as year
            , o.month
            , o.obsrflag
            , o.area as obs_area
            , o.negear as obs_gear
            , o.geartype
            , round(o.meshsize, 0) as obs_mesh
            , o.meshgroup
            , substr(nespp4, 1, 3) as NESPP3
            , SUM(case when catdisp = 0 then o.livewt else 0 end) as discard
            , SUM(case when catdisp = 1 then o.livewt else 0 end) as obs_haul_kept
        
            from (
			    select * from maps.cams_obdbs_2017
                union all
                select * from maps.cams_obdbs_2018
                union all
                select * from maps.cams_obdbs_2019
				union all
                select * from maps.cams_obdbs_2020
                union all
                select * from maps.cams_obdbs_2021
            )
            o
          group by  o.link3
            , link1
            , vtrserno
            , o.month
            , o.obsrflag
            , o.area 
            , o.geartype
            , o.negear 
            , round(o.meshsize, 0)
            , o.meshgroup
            , substr(nespp4, 1, 3)
            , extract(year from dateland)