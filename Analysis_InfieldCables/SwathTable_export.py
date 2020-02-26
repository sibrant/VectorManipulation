#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test for SwathGraph class

Created on Tue Nov 14 2017
Last Modified on Tue Nov 14 2017
@author: J Vicente Perez
"""
import os

os.chdir('D:\OneDrive\Documents\Work\LeagueGeophysics\HKN\swath\SwathProfiler-master\Test')

import SwathProf as sp 
import praster as p
import pandas as pd
import numpy as np
import re
import math

        
in_dem = "../SampleData/gisdata/Bathy_2x2.tif"
in_shp = "../SampleData/gisdata/HKN_IC_ETRS-25831.shp"
name_fld = "IcID"

# Set width of buffer zone
width = 100
# Set number of sample lines within this buffer zone
n_lines = 50
# Set sample distance along line
ssize = 2

#open files
lines, names = sp.read_line_shapefile(in_shp, name_fld)
dem = p.open_raster(in_dem)

####Crosslines generation

#make crosslines
line = lines[35]

kps = np.append(np.arange(0., line.length, ssize), line.length)

xl = sp.xlines(line, kps, width)

#create shapefile
import fiona
from shapely.geometry import mapping

schema = {
    'geometry': 'LineString',
    'properties': {'kp': 'float'},
}

with fiona.open('xlines.shp', 'w', 'ESRI Shapefile', schema) as c:
    ## If there are multiple geometries, put the "for" loop here
    for idx,val in enumerate(xl):
        c.write({'geometry': mapping(val),
                 'properties': {'kp': kps[idx]},})

#run the terrain analysis per line    
for idx, line in enumerate(lines):
    print("Processing {0} of {1} lines".format(idx+1, len(lines)))
    sw = sp.SwathProfile(line, dem, width=width, n_lines=n_lines, 
                                       step_size=ssize, name=names[idx])
    
    #calculate roll and pitch from adjacent cells
    #define atan fucntions to calculate slopes
    def f(x):
        return math.degrees(math.atan(x))

    f2 = np.vectorize(f)
    
    #get roll slopes, based on height difference between 
    #cell left and right of central cell
    dx = ((sw.data[:,1]-sw.data[:,2])/(width*2))
    
    #get pitch slopes, based on height difference between 
    #one cell back and one cell further along line of central cell
    dy = []
    
    for i, point in enumerate(sw.data[:,0][:-1]):
        tmp = ((sw.data[:,0][i+1] - sw.data[:,0][i-1])/(ssize*2))
        dy = np.append(dy, tmp)
        
    tmp2 = 0
    
    dy = np.append(tmp2,dy[1:])
    dy = np.append(dy,tmp2)
    
    #create one dataframe
    sw_df = pd.DataFrame({'dist': sw.li, 
                          'X': sw.coord[:,0],
                          'Y': sw.coord[:,1],
                          'data': sw.data[:,0],
                          'dataleft': sw.data[:,1],
                          'dataright': sw.data[:,2],
                          'mean': sw.meanz, 
                          'min': sw.minz, 'max': sw.maxz, 
                          'q1': sw.q1, 
                          'q3': sw.q3, 
                          'HI': sw.HI, 
                          'relief': sw.relief,
                          'roll': f2(dx),
                          'pitch': f2(dy)})
               
    sw_df.to_csv(f'''Swath_{names[idx]}_rollpitch.csv''')

#attempt to get profiles from different grids

files = []

for file in os.listdir("../../../Fugro 2017-2018/02_MBES"):
    if file.endswith(".tif"):
        files.append(os.path.join("../../../Fugro 2017-2018/02_MBES", file))
        
lines, names = sp.read_line_shapefile(in_shp, name_fld)

kps = np.append(np.arange(0., line.length, ssize), line.length)

xy = sp.get_coords(lines, kps)

pr_df = pd.DataFrame({' kp': kps, 'X': xy[:,0],'Y': xy[:,1]})
      
for idx, f in enumerate(files):
    dem = p.open_raster(f)
    
    nm = re.split('\\.|\\\\|\\/',f)[-2]
    print("Processing {0} of {1} rasters".format(idx+1, len(files)))
    pr = sp.sample_dem(lines, dem, kps)
    pr_df[nm] = pr
    
