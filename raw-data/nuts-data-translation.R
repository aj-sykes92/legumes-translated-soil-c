library(rgdal)

# read in Lvl. 2 NUTS regions in WGS84 projection and check
nuts_fname <- find_onedrive("GIS data repository", "ref-nuts-2016-20m/NUTS_RG_20M_2016_4326_LEVL_2.shp/NUTS_RG_20M_2016_4326_LEVL_2.shp")
Shp_nuts <- shapefile(nuts_fname)
plot(Shp_nuts)
Shp_nuts@proj4string
unique(Shp_nuts@data$NUTS_ID)

# write to 
write_rds(Shp_nuts, "raw-data/nuts-shapefiles/nuts-lvl2-wgs84.rds")

# odd one out --- Ukraine --- no NUTS file
countries_fname <- find_onedrive("GIS data repository", "Country shapefile/countries.shp")
Shp_ukraine <- shapefile(countries_fname) %>%
  subset(FAO == "Ukraine")

# write to
write_rds(Shp_ukraine, "raw-data/nuts-shapefiles/ukraine-country-wgs84.rds")
