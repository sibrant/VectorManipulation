library(sf)
library(dplyr)
library(lwgeom)
library(tools)

setwd("D:/OneDrive/Documents/Work/Deep/P3538_GridLink/Block123_SurveyReport")

s.list = list.files('../', pattern='shp$', recursive = T)

s.list

#merge morphology datasets
l1 = st_read(paste0('../',s.list[16]))
l1= st_make_valid(l1)
l1[66,]$Class <- 'Ripples'
l2 = st_read(paste0('../',s.list[17]))
l2 = st_make_valid(l2)
l3 = st_read(paste0('../',s.list[18]))
l3 = st_make_valid(l3)
l3 = l3[2]

ltmp = rbind(l1, l3)

ltmp2 = st_difference(ltmp,st_union(l2))

l = rbind(l2, ltmp2)
l = st_make_valid(l)
l$Class = toTitleCase(tolower(l$Class))

lmerge = l %>% 
  group_by(Class) %>%
  summarise(do_union=T)

mapview(lmerge)

st_write(lmerge, 'B123_SeabedMorphology_190910.shp')

#merge geology datasets

l1 = st_read(paste0('../',s.list[19]))
l1= st_make_valid(l1)
l1 = l1[,2]
l2 = st_read(paste0('../',s.list[20]))
l2 = st_make_valid(l2)
l2 = l2[,2]
l3 = st_read(paste0('../',s.list[21]))
l3 = st_make_valid(l3)
l3 = l3[,2]

ltmp = rbind(l1, l3)

ltmp2 = st_difference(ltmp,st_union(l2))

l = rbind(l2, ltmp2)
l = st_make_valid(l)
l$Lithology = toupper(l$Lithology)

lmerge = l %>% 
  group_by(Lithology) %>%
  summarise(do_union=T)

mapview(lmerge)

st_write(lmerge, 'B123_SeabedGeology_190910.shp')

