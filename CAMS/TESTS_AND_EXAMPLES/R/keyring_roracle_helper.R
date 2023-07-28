# script to add keys to keyring and make a RORacle helper function

library(keyring)

# store all connections from yaml file

con_names = c('apsd','maps','cams_garfo','fso','bgaluardi','qmdbs','cams','dmis')

if(!('apsd_ma' %in% keyring_list()$keyring)) {
	keyring_create('apsd_ma')
}

for(i in con_names){

vals = config::get(value = i, file = "~/config.yml")
	
	key_set_with_value(key = 'apsd_ma',
										 service = i,
										 password = vals$pwd,
										 username = vals$uid)		
	
}


# Store info for webserver
key_set_with_value(key = "apsd_ma",
									 service = "nersfile",
									 password = .rs.askForPassword("Password: "),
									 username = 'bgaluardi')

# Store DSN name - only actually need the password here. DSN for all schema on DB
key_set_with_value(key = "apsd_ma",
									 service = "dsn",
									 password = .rs.askForPassword("Password: "))

# database name
key_set_with_value(key = "apsd_ma",
									 service = "dbname",
									 password = "NERO_STATS.WORLD") # NERO_STATS.WORLD

# Store GARFO Database Name
key_set_with_value(key = "apsd_ma",
									 service = "dbname",
									 password = 'NERO.WORLD')

# Git PAT
key_set_with_value(key = "apsd_ma",
									 service = "github",
									 password = .rs.askForPassword("Password: "),
									 username = .rs.askForPassword("Username: "))



# ROracle login function (redundant)
roracle_login <- function(key_name, key_service) {

	if (keyring::keyring_is_locked(key_name)) {
	stop("keyring must be unlocked to use odbc_login")
}

  ROracle::dbConnect(
	drv = ROracle::Oracle()
	, username = as.character(keyring::key_list(key_service, key_name)$username)
	, password = keyring::key_get(service = key_service
								, username = as.character(keyring::key_list(key_service, key_name)$username)
								, keyring = key_name)  
	, dbname = "NERO.world"
)


}

# test the function

keyring::keyring_unlock("apsd_ma")

# con_maps <- apsdFuns::roracle_login(key_name = 'apsd_ma', key_service = 'maps')

# 
bcon = roracle_login(key_name = 'apsd_ma',
										 key_service = 'maps'
										 )
