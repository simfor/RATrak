#Utility functions
#lmp
#readBinary
#readMetadata
#loadPackages
#
#
#
#


lmp <- function (modelobject) {
  if (class(modelobject) != "lm") stop("Not an object of class 'lm' ")
  f <- summary(modelobject)$fstatistic
  p <- pf(f[1],f[2],f[3],lower.tail=F)
  attributes(p) <- NULL
  return(p)
}

.trak <- setClass(Class = "trak", slots = c(speed = "data.frame", speed.regressed = "data.frame", time = 'numeric', centroid = "data.frame",  activity = "list", metadata = "data.frame", hz = "numeric"), package = 'RATrak')

readInfo <- function(speedBinFileName = NULL, centroidBinFileName = NULL, timeBinFileName = NULL, metadataFileName, wellCount, start = 1, end = wellCount, hz = 5, inferPhenos = F, size.centroid = NA_integer_){
  #WARNING: The precision for the centroid data is not consistent across autotracker versions. If the centroid coordinates make no sense, try changing size.centroid
  #This is passed on as the size argument to readBin()
  time <- numeric()
  centroid <- data.frame()
  speed <- data.frame()
  
  if(!is.null(centroidBinFileName) & !is.null(timeBinFileName) & !is.null(speedBinFileName)){  
    speed <- readBinary(speedBinFileName, wellCount, dataType = 'speed')
    centroid <- readBinary(centroidBinFileName, wellCount, dataType = 'centroid', size.centroid = size.centroid)
    time <- readBinary(timeBinFileName, dataType = 'time')
    
    centroid <- centroid[2:nrow(centroid), ] #Align speed and centroid data
  }
  else if(is.null(centroidBinFileName) & !is.null(timeBinFileName) & !is.null(speedBinFileName)){  
    speed <- readBinary(speedBinFileName, wellCount, dataType = 'speed')
    time <- readBinary(timeBinFileName, dataType = 'time')
  }
  else if(!is.null(centroidBinFileName) & is.null(timeBinFileName) & !is.null(speedBinFileName)){  
    speed <- readBinary(speedBinFileName, wellCount, dataType = 'speed')
    centroid <- readBinary(centroidBinFileName, wellCount, dataType = 'centroid', size.centroid = size.centroid)
    
    centroid <- centroid[2:nrow(centroid), ] #Align speed and centroid data
  }
  else if(!is.null(centroidBinFileName) & !is.null(timeBinFileName) & is.null(speedBinFileName)){
    print('Only centroid and time data provided. Calculating speed')
    centroid <- readBinary(centroidBinFileName, wellCount, dataType = 'centroid', size.centroid = size.centroid)
    time <- readBinary(timeBinFileName, dataType = 'time')
    speed <- flies.calculateSpeed(as.matrix(centroid), time)
    
    centroid <- centroid[2:nrow(centroid), ] #Align speed and centroid data
  }
  else if(is.null(centroidBinFileName) & is.null(timeBinFileName) & !is.null(speedBinFileName)){  
    speed <- readBinary(speedBinFileName, wellCount, dataType = 'speed')
  }
  else if(is.null(centroidBinFileName) & !is.null(timeBinFileName) & is.null(speedBinFileName)){
    warning('Only time data provided')
    time <- readBinary(timeBinFileName, dataType = 'time')
  }
  else if(!is.null(centroidBinFileName) & is.null(timeBinFileName) & is.null(speedBinFileName)){
    print('Only centroid data provided. Calculating speed')
    centroid <- readBinary(centroidBinFileName, wellCount, dataType = 'centroid', size.centroid = size.centroid)
    speed <- flies.calculateSpeed(as.matrix(centroid))*5 #Rescale speed to pixel/s
    
    centroid <- centroid[2:nrow(centroid), ] #Align speed and centroid data
  }
  else
    stop('Neither speed, centroid, or time data was provided')
  
  metadata <- readMetadata(metadataFileName, start, end)
  data <- .trak(speed=speed, centroid=centroid, metadata=metadata, time = time, hz=hz)
  if(inferPhenos)
    data <- flies.sleepActivity(data)
  return(data)
}

readBinary <- function(fileName, colCount, dataType, size.centroid = NA_integer_, size.speed_time = 4){
  #WARNING: The precision for the centroid data has been changed between single and double in different autotracker versions. 
  file <- file(fileName, "rb")
  if(dataType == 'speed'){
    mat <- matrix(readBin(file, numeric(), n = 1e9, size = size.speed_time), ncol = colCount, byrow = TRUE)
    mat <- mat[4:nrow(mat), ] #Discard first few frames
    close(file)
    return(as.data.frame(mat))
  }
  else if(dataType == 'centroid'){
    mat.tmp <- matrix(readBin(file, numeric(), n = 1e9, size = size.centroid), ncol = colCount*2, byrow = TRUE)
    #Reshape matrix
    mat <- matrix(ncol = ncol(mat.tmp), nrow = nrow(mat.tmp))
    xCols <- seq(from = 1, to = ncol(mat.tmp) - 1, by = 2)
    yCols <- seq(from = 2, to = ncol(mat.tmp), by = 2)
    mat[, xCols] <- mat.tmp[, 1:colCount]
    mat[, yCols] <- mat.tmp[, (colCount+1):(colCount*2)]
    mat <- mat[3:nrow(mat), ] #Discard first few frames
    close(file)
    return(as.data.frame(mat))
  }
  else if(dataType == 'time'){
    time <- readBin(file, numeric(), n = 1e9, size = size.speed_time)
    time <- time[4:length(time)] #Discard first few frames
    close(file)
    return(time)
  }
  else
    stop(paste('datatype:', dataType, 'was not recognized. dataType should be: speed, centroid, or time'))
}

readMetadata <- function(fileName, start = 1, end){
  #Determine field separator
  L <- readLines(fileName, n = 1)
  if (grepl(";", L))
    meta <- read.table(fileName, header = TRUE, sep = ';')
  else if (grepl(",", L))
    meta <- read.table(fileName, header = TRUE, sep = ',')
  else if (grepl("\t", L))
    meta <- read.table(fileName, header = TRUE, sep = '\t')
  else
    stop(paste('Could not determine field separator in', fileName))
  
  meta$Treatment <- as.vector(meta$Treatment)
  data = meta[start:end,]
  return(data)
}



#This script provides a quick way to group load packages - it's not needed in the package but could be useful for end users in other applications
loadPackages <- function(names){
  missingPackages <- names[!(names %in% installed.packages()[,"Package"])]
  if(length(missingPackages)){
    install.packages(missingPackages)
  }
  for (pkg in names) {
    library(pkg,character.only = TRUE)
  }
}
