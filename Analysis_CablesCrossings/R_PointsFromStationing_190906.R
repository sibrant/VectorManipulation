library(sf)

setwd("D:/OneDrive/Documents/Work/Deep/P3538_GridLink/Block123_SurveyReport/R")
source('R_FunctionLineStationingToPoint.R')
source('R_FunctionUpdateKPs.R')


#get list of shapefiles
s.list = list.files('../../',recursive=T, pattern = 'shp$')

#open line file
l_old = st_read(paste0('../../',s.list[10]))
l_new = (st_read(paste0('../../',s.list[23])))

#define KP points
p = c(340,692,889,1022,1396,1692,2191,2259,3967,4954,5149,5627,7094,9553,12122,12716,13650,14144,14326,15118,15287,16005,16757,17643,19960)

p = seq(0,25000, 100)

#run point on line creation
pts = pointOnLine(l_old, 13650)
result = pointOnLine(l,p)

test = updateKP(l_old, l_new, seq(0, as.numeric(st_length(l_old)), 100))

st_write(res.sf, 'PointsFromStationing_2.shp', delete_dsn = T)

updateKP(l_old, l_new, c(15000, 15670, 12000))
