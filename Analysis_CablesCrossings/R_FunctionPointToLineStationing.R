#### Functions needed to calculate stationing

pointOnLine <- function(point, line_start, line_end) {
# each of input parameters is pair of coordinates [x,y]
if (identical(point, line_start) | identical(point, line_end)) 
{
  return(TRUE)
}  # check, if the points cooincides with start/end point
if (point[1] > max(c(line_start[1], line_end[1])) | point[1] < min(c(line_start[1], 
                                                                     line_end[1])) | point[2] > max(c(line_start[2], line_end[2])) | point[2] < 
    min(c(line_start[2], line_end[2]))) {
  return(FALSE)  # if the point is out of the bounding box of the line, return false
}
if (line_start[2] == line_end[2]) {
  slope <- 0
} else if (line_start[1] == line_end[1]) {
  return(T)
} else {
  slope <- (line_start[2] - line_end[2])/(line_start[1] - line_end[1])
}
intercept <- -slope * line_start[1] + line_start[2]
onLine <- round(point[2], digits = 2) == round((slope * point[1] + intercept), 
                                               digits = 2)
return(onLine)
}


##slope

calculateStationing <- function(points, lines, maxDist = NA) {
  require(maptools)
  require(sf)
  
  points <- as_Spatial(st_zm(points))
  lines <- as_Spatial(st_zm(lines))
  
  # snap points to lines from package maptools
  snapped <- snapPointsToLines(points, lines, maxDist, withAttrs = TRUE)
  
  stationing <- c()
  distance <- c()
  leftright <- c()
  
  for (i in 1:length(snapped)) {
    crds_p <- coordinates(snapped[i, ])
    line <- lines[snapped[i, ]$nearest_line_id, ]
    crds_l <- coordinates(line)[[1]][[1]]
    crds_orig <- coordinates(points[i, ])
    
    distance <- c(distance, gDistance(points[i,], snapped[i,]))
    
    d <- 0
    for (j in 2:nrow(crds_l)) {
      onLine <- pointOnLine(point = crds_p, line_start = crds_l[j - 1, ], line_end = crds_l[j, ])
      if (onLine) {
        d0 <- sqrt((crds_p[1] - crds_l[j - 1, 1])^2 + (crds_p[2] - crds_l[j - 1, 2])^2)
        stationing <- c(stationing, round(d + d0, digits=2))
        
        #calculate left (-) or right (+) of line 
        dxl = crds_l[j, 1] - crds_l[j - 1, 1]
        dyl = crds_l[j, 2] - crds_l[j - 1, 2]
        
        dxp = crds_orig[1] - crds_p[1]
        dyp = crds_orig[2] - crds_p[2]
        
        if (dxl < 0) {
          if (dyp > 0) {
            lr = '+'}
          else lr = '-'}
        
        if (dxl > 0) {
          if (dyp < 0) {
          lr = '+'}
        else lr = '-'}
          
        leftright <- c(leftright, lr)
        
        break
      }
      d <- d + sqrt((crds_l[j, 1] - crds_l[j - 1, 1])^2 + (crds_l[j, 2] - crds_l[j - 1, 2])^2)
    }
  }
  
  snapped$stationing <- stationing
  snapped$distance <- distance
  snapped$leftright <- leftright
  snapped <- st_as_sf(snapped)
  return(snapped)
  
}

##

snapPointsToLines <- function(points, lines, maxDist = NA, withAttrs = TRUE) {
  require("rgeos")
  
  if (is(points, "SpatialPoints") && missing(withAttrs)) 
    withAttrs = FALSE
  if (!is.na(maxDist)) {
    w = gWithinDistance(points, lines, dist = maxDist, byid = TRUE)
    validPoints = apply(w, 2, any)
    validLines = apply(w, 1, any)
    points = points[validPoints, ]
    lines = lines[validLines, ]
  }
  d = gDistance(points, lines, byid = TRUE)
  nearest_line_index = apply(d, 2, which.min)
  coordsLines = coordinates(lines)
  coordsPoints = coordinates(points)
  mNewCoords = vapply(1:length(points), function(x) nearestPointOnLine(coordsLines[[nearest_line_index[x]]][[1]], 
                                                                       coordsPoints[x, ]), FUN.VALUE = c(0, 0))
  if (!is.na(maxDist)) 
    nearest_line_id = as.numeric(rownames(d)[nearest_line_index]) + 1 else nearest_line_id = nearest_line_index
  if (withAttrs) 
    df = cbind(points@data, nearest_line_id) else df = data.frame(nearest_line_id, row.names = names(nearest_line_index))
  SpatialPointsDataFrame(coords = t(mNewCoords), data = df, proj4string = CRS(proj4string(points)))
}

