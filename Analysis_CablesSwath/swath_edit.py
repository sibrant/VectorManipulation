# -*- coding: utf-8 -*-
#
#  swath.py
#
#  Copyright (C) 2016  J. Vicente Perez, Universidad de Granada
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.

#  For additional information, contact to:
#  Jose Vicente Perez Pena
#  Dpto. Geodinamica-Universidad de Granada
#  18071 Granada, Spain
#  vperez@ugr.es // geolovic@gmail.com

#  Version: 1.1
#  November 12, 2017

#  Last modified November 14, 2017

import ogr
from shapely.geometry import LineString
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import numpy as np

# Disable some keymap characters that interfere with graph key events
plt.rcParams["keymap.xscale"] = [""]
plt.rcParams["keymap.yscale"] = [""]
plt.rcParams["keymap.save"] = [u'ctrl+s']
DIRECTIONS = {"LEFT": -1, "RIGHT": 1}

def read_line_shapefile(shapefile, names_field=""):
    """
    This function reads a line shapefile and returns a tuple (out_lines, out_names)
    
    Parameters:
    ================
    shapefile : *str*
      Path to the line shapefile with profile centerline
    names_field : *str*
      Name of the field with the profile names. If skipped, profiles will be named sequentially
    
    Returns:
    ==============
    (out_lines, out_names) : *tuple*
        out_lines : List with shapely.geometry.LineString objects representing shapefile lines
        out_names : List of string with profile names
    """
    # Open the dataset and get the layer
    driver = ogr.GetDriverByName("ESRI Shapefile")
    dataset = driver.Open(shapefile)
    layer = dataset.GetLayer()
    
    # Check if layer has the right geometry
    if not layer.GetGeomType() == 2:
        return

    # Get a list of layer fields
    layerdef = layer.GetLayerDefn()
    fields = [layerdef.GetFieldDefn(idx).GetName() for idx in range(layerdef.GetFieldCount())]
    take_field = True
    if not names_field in fields:
        take_field = False

    out_names = []
    out_lines = []
    perfil_id = 0
    
    for feat in layer:
        if take_field:
            out_names.append(str(feat.GetField(names_field)))
        else:
            out_names.append(str(perfil_id))
        
        geom = feat.GetGeometryRef()
        # If the feature is multipart, only the first part is considered
        if geom.GetGeometryCount() > 0:
            geom = geom.GetGeometryRef(0)
        
        coords = []
        for n in range(geom.GetPointCount()):
            pt = geom.GetPoint(n)
            coords.append((pt[0], pt[1]))
        out_lines.append(LineString(coords))
        perfil_id += 1
        
    return out_lines, out_names

def sample_dem(line, dem, kps):
        """
        Get elevations along a line in npoints equally spaced. If any point of the line falls
        outside the DEM or in a NoData cell, a np.nan value will be asigned.
        :param line : Shapely.LineString object. Input LineString
        :param dem : pRaster object. DEM with elevatations.
        :param kps : flt. distances of sample points along line
        :return zi : Numpy.ndarray. Array with size (npoints, 1) with elevations
        """
        #step_size = 1.0/npoints
        zi = []
        for idx,val in enumerate(kps):
            kp = val/line.length
            pt = line.interpolate(kp, normalized=True)
            xy = list(pt.coords)[0]
            z = dem.get_xy_value(xy)
            if z == dem.nodata or not z:
                z = np.nan
            zi.append(z)

        return np.array(zi, dtype="float").reshape((len(zi), 1))


class SwathProfile:
    def __init__(self, line=None, dem=None, width=0, n_lines=None, step_size=None, name=""):
        """
        Class to create a swath profile object and related parameters

        :param line: shapely.geometry.LineString - LineString the swath profile centerline
        :param dem: praster.pRaster - pRaster with the Digital Elevation Model
        :param width: float - Half-width of the swath profile (in data units)
        :param n_lines: int - number of lines at each side of the swath centerline
        :param step_size: float - Step-size to get elevation points along the profile
        :param name: str - Name of the profile
        """

        self.name = str(name)
        
        # Creates an empty SwathProfile Object
        if line is None:
            return
        
        # Get step size (By default dem.cellsize if was not specified)
        if step_size is None or step_size < dem.cellsize:
            step_size = dem.cellsize
        
        # Get number of lines (By default 50)
        if n_lines is None:
            n_lines = 50
        elif n_lines > int(width/dem.cellsize):
            n_lines = int(width/dem.cellsize)
        
        # Get distance between lines
        line_distance = float(width) / n_lines
        
        # Get profile distances
        self.li = np.append(np.arange(0., line.length, step_size), line.length)
        
        # Get the kps of points 
        kps = (self.li)

        # Create the elevation data array with the first line (baseline)
        self.data = self._get_zi(line, dem, kps)
        
        self.coord = self._get_coord(line, kps)

        # Simplify baseline
        sline = line.simplify(tolerance=dem.cellsize*5)
        
        # Create the elevation data for the Swath
        for n in range(n_lines):
            dist = line_distance * (n+1)
            left_line = sline.parallel_offset(dist, side="left")
            right_line = sline.parallel_offset(dist, side="right") 
            # Sometimes parallel_offset produces MultiLineStrings ¿??
            if left_line.type == "MultiLineString":
                left_line = self._combine_multilines(left_line)
            if right_line.type == "MultiLineString":
                right_line = self._combine_multilines(right_line)

            right_line = self._flip(right_line)
            
            #Correct KPs for lines with kinks
            left_line.length
            
            l_elev = self._get_zi(left_line, dem, kps)
            r_elev = self._get_zi(right_line, dem, kps)
            self.data = np.append(self.data, r_elev, axis=1)
            self.data = np.append(self.data, l_elev, axis=1)

        # Get parameters (max, min, mean, q1, q3, HI, relief)
        self.maxz = np.nanmax(self.data, axis=1)
        self.minz = np.nanmin(self.data, axis=1)
        self.meanz = np.nanmean(self.data, axis=1)
        self.q1 = np.nanpercentile(self.data, q=25, axis=1)
        self.q3 = np.nanpercentile(self.data, q=75, axis=1)
        self.HI = (self.meanz - self.minz) / (self.maxz - self.minz)
        self.relief = self.maxz - self.minz
                
        # Length of the swath
        self.length = self.li[-1]
    
    def _get_coord(self, line, kps):
        
        #step_size = 1.0/npoints
        coord = []
        
        for idx,val in enumerate(kps):
            kp = val/line.length
            pt = line.interpolate(kp, normalized=True)
            xy = list(pt.coords)[0]
            coord.append(xy)

        return np.array(coord, dtype='float').reshape((len(coord),2))
        
        
    def _get_zi(self, line, dem, kps):
        """
        Get elevations along a line in npoints equally spaced. If any point of the line falls
        outside the DEM or in a NoData cell, a np.nan value will be asigned.
        :param line : Shapely.LineString object. Input LineString
        :param dem : pRaster object. DEM with elevatations.
        :param kps : flt. distances of sample points along line
        :return zi : Numpy.ndarray. Array with size (npoints, 1) with elevations
        """
        #step_size = 1.0/npoints
        zi = []
        for idx,val in enumerate(kps):
            kp = val/line.length
            pt = line.interpolate(kp, normalized=True)
            xy = list(pt.coords)[0]
            z = dem.get_xy_value(xy)
            if z == dem.nodata or not z:
                z = np.nan
            zi.append(z)

        return np.array(zi, dtype="float").reshape((len(zi), 1))
 
    def _flip(self, line):
        """
        Flips a LineString object. Returns the new line flipped
        :param line : Shapely.LineString object. Input LineString
        :return line : Shapely.LineString object. Fliped LineString
        """
        coords = list(line.coords)
        coords = np.array(coords)[::-1]
        return LineString(coords)
       
    def _combine_multilines(self, line):
        """
        Combines all the parts of a MultiLineString in a single LineString
        :param line : Shapely.LineString object. Input MultiLineString
        :return line : Shapely.LineString object. Ouput LineString
        """
        xyarr = np.array([], dtype="float32").reshape((0, 2))
        for n in range(len(line.geoms)):
            xyarr = np.append(xyarr, np.array(line.geoms[n].coords), axis=0)
        return LineString(xyarr)
            