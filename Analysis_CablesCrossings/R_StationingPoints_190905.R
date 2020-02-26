# load packages
library(maptools)
library(sf)

setwd("D:/OneDrive/Documents/Work/Deep/P3538_GridLink/Block123_SurveyReport/r")

source('R_FunctionPointToLineStationing.R')

#get list of shapefiles
s.list = list.files('../../',recursive=T, pattern = 'shp$')

# load points
p = st_read(paste0('../../',s.list[3]))

#  load lines
l = st_read(paste0('../../',s.list[36]))
# l1 = st_read(paste0('../',s.list[8]))
# l2 = st_read(paste0('../',s.list[10]))
# l = rbind(l1,l2)
l$cable = c('GridLink HVDC_Rev2')



#make sure CRSs are completely similar
p = st_transform(p, st_crs(l))

#### calculate stationing for points
st = calculateStationing(p, l)

st.sf = st_as_sf(st)

#create correct KPs
st.sf$kp = format(round((st.sf$stationing)/1e3, digits=3), nsmall=3)

st.sf$stationing = NULL

#write nice offset from line
st.sf$distlr = paste0(st.sf$leftright, format(round(st.sf$distance, digits=1), nsmall=1))

st.sf$leftright = NULL



#write nice dimensions
#for mbes data add height
#st.sf$THeight = 0.3

st.sf$dims = paste0(format(round(st.sf$LENGTH..m.,1), nsmall=1), ' x ', format(round(st.sf$WIDTH..m.,1), nsmall=1),
                    ' x ', format(round(st.sf$HEIGHT..m.,1), nsmall=1))

#extract coordinates
coords = st_coordinates(st.sf)

st.sf$coordx = coords[,1]

st.sf$coordy = coords[,2]

rm(coords)

#get proper cable name
st.sf$cable[st.sf$nearest_line_id == 1] <- 'GridLink HVDC'
st.sf$cable[st.sf$nearest_line_id == 2] <- 'GJ1 HVAC'

#add correct point geometry from original point file
st.sf$geometry = p$geometry


st_write(st.sf, paste0('GridLink_B01_GeoBoundaries_Stationing_', format(Sys.Date(), "%Y%m%d"), '.shp'), delete_dsn = T)

st.sf$geometry = NULL

write.csv(st.sf, paste0('GridLink_B01_ContactsMMT_Stationing_', format(Sys.Date(), "%Y%m%d"), '.csv'))


# #filter object >10 m either side
# st.sf.flt = st.sf[st.sf$cable == 'GJ1 FO' & st.sf$distance < 10 & st.sf$leftright == '-' |
#                 st.sf$cable == 'GJ1 HVAC' & st.sf$distlr < 10 & st.sf$leftright == '+',]

##write nice table for report straightaway
st.sh = st.sf[,c(1,38,39,35,36,40,7,37)]

st.sh$coordx = round(st.sh$coordx, digits=0)
st.sh$coordy = round(st.sh$coordy, digits=0)
st.sh$Name = gsub('SSS', 'S', st.sh$Name)
st.sh$Name = gsub('MBES', 'M', st.sh$Name)
st.sh$Name = gsub('contact_', '', st.sh$Name)

st.sh = st.sh[order(st.sh$kp),]

colnames(st.sh) = c('Contact ID', 'Easting','Northing','KP','DCC', 'Nearest Cable', 'Classification' ,'Dimensions [L x B x H m]')

write.csv(st.sh, paste0('GJ1_Contacts_Stationing_PrettyTable_', format(Sys.Date(), "%Y%m%d"), '.csv'))

##stats
library(dplyr)
library(tools)
library(stringr)

stat = st.sf %>% st_set_geometry(NULL) %>%
  {tolower(.$CLASSIFICA)} %>%
  { str_replace(tolower(.$CLASSIFICA), " - hazard|_hazard", "") } %>%
  #mutate(CLASS = toTitleCase(tolower(CLASSIFICA))) %>%
  group_by(CLASSIFICA) %>%
  summarize(n())

#some renaming

