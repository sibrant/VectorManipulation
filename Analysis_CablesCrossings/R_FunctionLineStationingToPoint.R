#Functions to get point coordinates from a list of KP values along a line. 
#KP values should be in meters
#Line should be in sf format

library(sp)
library(sf)

#function to calculate distance between two points
norm_vec <- function(x) sqrt(sum(x^2))

#function to create new point
new_point <- function(p0, p1, di) { # Finds point in distance di from point p0 in direction of point p1
  v = p1 - p0
  u = v / norm_vec(v)
  return (p0 + u * di)
}

#function to loop through list of KP values and create points on a line at these KPs
pointFromKP = function(l, p) {
  
  l.m = as.matrix(st_coordinates(l))[,1:2]
  
  res = c()
  
  for (i in p) {
    ltmp = l.m
    accDist = 0

    while(accDist <= i) {
    
    p1 = ltmp[1,]
    p2 = ltmp[2,]
    
    dist = norm_vec(p2-p1)
    
    accDist = accDist + dist;
    
    if (accDist > i) {
      np = new_point(p1, p2, dist - (accDist - i))
      res = rbind(res, np )
      break
      }
    else { 
      ltmp = tail(ltmp, n = -1)
    }
    }
  }
  res = cbind(res,p)
  res = res %>% as.data.frame %>% 
    sf::st_as_sf(coords = c(1,2))
  st_crs(res) = st_crs(l)
  
  return(res)
  }




