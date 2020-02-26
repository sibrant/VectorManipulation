## Get start and end KP of areas intersecting a line
library(sf)
library(lwgeom)
library(stringr)

setwd("D:/OneDrive/Documents/Work/Deep/P3538_GridLink")

s.list = list.files(recursive=T, pattern = 'shp$')

#open line file
l = st_read(s.list[31])

#open area file
a = st_read(s.list[15])
a = a[,1]

#close open lines
a = st_cast(a, 'POLYGON')

#get rid of invalid polygons
a = st_make_valid(a)

#get crss lined up
a = st_transform(a, st_crs(l))

#calculate intersection of two files
i = st_intersection(a,l)

#split multilinestrings in separate pieces
i = st_cast(st_cast(i, "MULTILINESTRING"),"LINESTRING")

#convert to points, for first points this is very easy
#i.s = st_cast(i, 'POINT')

i.s = st_sf(st_sfc(st_point(st_coordinates(i[1,])[1,1:2])))
colnames(i.s) = 'geometry'
st_geometry(i.s) = 'geometry'

for (j in 2:nrow(i)) {
  i.t = st_sf(st_sfc(st_point(st_coordinates(i[j,])[1,1:2])))
  colnames(i.t) = 'geometry'
  st_geometry(i.t) = 'geometry'
  i.s = rbind(i.s, i.t)
} 


#now for the last points
i.e = st_sf(st_sfc(st_point(st_coordinates(i[1,])[nrow(st_coordinates(i[1,])),1:2])))
colnames(i.e) = 'geometry'
st_geometry(i.e) = 'geometry'

for (j in 2:nrow(i)) {
  i.t = st_sf(st_sfc(st_point(st_coordinates(i[j,])[nrow(st_coordinates(i[j,])),1:2])))
  colnames(i.t) = 'geometry'
  st_geometry(i.t) = 'geometry'
  i.e = rbind(i.e, i.t)
} 

#get same attributes as original file
i.s.t = i
i.s.t$geometry = i.s$geometry

i.s = i.s.t

st_crs(i.s) = st_crs(i)

rm(i.s.t)


i.e.t = i
i.e.t$geometry = i.e$geometry

i.e = i.e.t

st_crs(i.e) = st_crs(i)

rm(i.e.t)

####Now get KP information
source('Block123_SurveyReport/R/R_FunctionPointToLineStationing.R')

i.e = st_transform(i.e, st_crs(l))

#### calculate stationing for points
st.e = calculateStationing(st_zm(i.e), st_zm(l))

st.e = st_as_sf(st.e)

st.e$geometry = NULL

st.e$kpend = format(round((st.e$stationing)/1e3, digits=3), nsmall=3)

st.s = calculateStationing(st_zm(i.s), st_zm(l))

st.s = st_as_sf(st.s)

st.s$geometry = NULL

st.s$kpstart = format(round((st.s$stationing)/1e3, digits=3), nsmall=3)

#add kpend column to st start
st.s$kpend = st.e$kpend

#get length information
st.s$statend = st.e$stationing

st.s$arealength = st.s$statend - st.s$stationing

#some tidying up
st.s.sh = st.s[,c(1,8,9,11)]

st.s.sh = st.s.sh[order(st.s.sh$kpstart),]

columns = c('Seabed Morphology', 'KP Start', 'KP End', 'Length of intersection [m]')

colnames(st.s.sh) = columns


write.csv(st.s.sh, paste0('SeabedGeoology_Intersections_B123_', format(Sys.Date(), "%Y%m%d"), '.csv'), row.names = F)
