updateKP <- function (l1,l2, p) {
  source('R_FunctionLineStationingToPoint.R')
  source('R_FunctionPointToLineStationing.R')
  
  #first get points from old KPs
  ptsFromKP = pointFromKP(l1,p)
  
  #then get KPs on new line
  newKPPoints = calculateStationing(ptsFromKP, l2)

  return(newKPPoints)
  
  }
