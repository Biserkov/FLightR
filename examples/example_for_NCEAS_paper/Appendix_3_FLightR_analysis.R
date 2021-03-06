###############################################################################
# this is old and outdated example. Check vignette in CRAN version fo FLIghtR #

###############################################################################
#LOCATIONS ESTIMATED FROM SIMULATED LIGHT LEVEL DATA SET WITH FLightR PACKAGE#
###############################################################################


############################################
## PART 1. install.package and get the data#
############################################


#This first command will clear everything from your environment.
rm(list=ls())

##Load the necessary packages##
require(GeoLight)
require(maptools)
require(rgeos)
require(geosphere)
require(raster)
require(fields)

require(tsoutliers)
require(forecast)

require(circular)
require(truncnorm)
require(parallel)
require(bit)
require(aspace)
require(rgdal)
require(CircStats)

require(devtools)
install_github("eldarrak/FLightR@current_stable_version")
require(FLightR)

##IF WE POST THESE FOLDERS ONLINE SOMEWHERE, THEN THEY COULD READ DIRECTLY FROM THERE

## CURRENTLY ONE CAN DOWNLOAD DATA AND SCRIPT FROM MY GITHUB ACCOUNT
## we can change it later to some ither place

# download data file

require(RCurl)

# read script lines from website
text <- getURL("https://raw.githubusercontent.com/eldarrak/FLightR/master/examples/example_for_NCEAS_paper/SIM_PABU_DATA_SHDERR_A.csv", ssl.verifypeer = FALSE, followlocation = TRUE)
d<-read.csv(text=text, stringsAsFactors =F)


#Read the csv file for the raw light data and format dates
#d <- read.csv("SIM_PABU_DATA_SHDERR_A.csv")

d$datetime <- strptime(d$datetime, "%Y-%m-%d %H:%M:%S", "GMT")

#Define twighlight events with the threshold
gl_twl <- twilightCalc(d$datetime, d$light, LightThreshold = 4.5, ask = F) #get twilight times

FLightR.data=process.geolight.output(d$datetime, d$light, gl_twl)
Proc.data<-process.twilights(FLightR.data$Data, FLightR.data$twilights, measurement.period=600, saving.period=600)

known.coord <- c(-93.4, 35.2)

################################################
## PART 2. Calibration
################################################

##----------------------------------------------
##   Search for a proper calibration period 
##   and manual check of outliers
##----------------------------------------------

## we need to select days when bird was in a known location
## these are typically days in the beginning or in the end
## of migration. To do we first will plot all sun slopes over 
## the whole period and then will decide when is our calibration period

## Dusk
Twilight.time.mat.Calib.dusk<-Proc.data$Twilight.time.mat.dusk

Twilight.log.light.mat.Calib.dusk<-Proc.data$Twilight.log.light.mat.dusk

## Dawn

Twilight.time.mat.Calib.dawn<-Proc.data$Twilight.time.mat.dawn

Twilight.log.light.mat.Calib.dawn<-Proc.data$Twilight.log.light.mat.dawn

# in the next screens you will see twilights..
# it is very important to go through them and check on whether there are some weird ones that should be excluded..
# weird in this case means seriously nonlinear - such that linear regression over them will be seriously biased...
# in the scrip window you will number of dawn or dusk..
# write down numbers that you want to exclude and add them at the next step..

# this is especially important for the nest box or cavity breeders.
# the abnormally fast twilights corresponding to twilight missed inside a cavity should be excluded..

Calib.data.all<-logger.template.calibration(Twilight.time.mat.Calib.dawn, Twilight.log.light.mat.Calib.dawn, Twilight.time.mat.Calib.dusk, Twilight.log.light.mat.Calib.dusk, positions=known.coord, log.light.borders=log(c(2, 64)),  log.irrad.borders=c(-1000, 1000), plot.each=F, plot.final=T) 

# plot=T - will plot al the twilights and you might exclude weird ones.
# plot=F will just go to the end without manual check possibility

Calib.data.all<-Calib.data.all[[1]]
All.slopes<-get.calib.param(Calib.data.all, plot=F)

All.slopes$Slopes<-as.data.frame(All.slopes$Slopes)
plot(log(All.slopes$Slopes$Slope)~All.slopes$Slopes$Time, type="n")

lines(log(Slope)~Time, data=All.slopes$Slopes[All.slopes$Slopes$Type=="Dusk",])
points(log(Slope)~Time, data=All.slopes$Slopes[All.slopes$Slopes$Type=="Dusk",], pch="+")
points(log(Slope)~Time, data=All.slopes$Slopes[All.slopes$Slopes$Type=="Dawn",], pch="+", col="red")
lines(log(Slope)~Time, data=All.slopes$Slopes[All.slopes$Slopes$Type=="Dawn",], col="red")

## we conclude that in the end of the trip our bird was around for about a month. - that's a nice period for the calibration..

abline(v=All.slopes$Slopes$Time[50])

as.POSIXct(All.slopes$Slopes$Time[50], tx="UTC", origin="1970-01-01")
# we assume it to be 04 Aug - as it have started to sit in a next box


##----------------------------------------------
##   Calibration for the selected period
##----------------------------------------------

Dusk.calib.days<-which(as.POSIXct(Proc.data$Twilight.time.mat.dusk[1,], tz="UTC", origin="1970-01-01") <= as.POSIXct("2013-08-04", tz="UTC"))
Twilight.time.mat.Calib.dusk<-Proc.data$Twilight.time.mat.dusk[,Dusk.calib.days]
Twilight.log.light.mat.Calib.dusk<-Proc.data$Twilight.log.light.mat.dusk[,Dusk.calib.days]

Dawn.calib.days<-which(as.POSIXct(Proc.data$Twilight.time.mat.dawn[1,], tz="UTC", origin="1970-01-01") <= as.POSIXct("2013-08-04", tz="UTC") )
Twilight.time.mat.Calib.dawn<-Proc.data$Twilight.time.mat.dawn[,Dawn.calib.days]
Twilight.log.light.mat.Calib.dawn<-Proc.data$Twilight.log.light.mat.dawn[,Dawn.calib.days ]

Calib.data.all<-logger.template.calibration(Twilight.time.mat.Calib.dawn, Twilight.log.light.mat.Calib.dawn, Twilight.time.mat.Calib.dusk, Twilight.log.light.mat.Calib.dusk, positions=known.coord,log.light.borders=log(c(2, 64)),  log.irrad.borders=c(-50, 50), plot=F) 
Calib.data.all<-Calib.data.all[[1]]
All.slopes<-get.calib.param(Calib.data.all, plot=F)

plot(log(All.slopes$Slopes$Slope)~All.slopes$Slopes$Time)

# Now we create 'parameters' object that will have all the details about the calibration
Parameters<-All.slopes$Parameters # LogSlope -0.22 0.5
Parameters$measurement.period<-Proc.data$measurement.period 
Parameters$saving.period<-Proc.data$saving.period 
Parameters$log.light.borders<-log(c(2, 64)) # these are the boundaries in which one should use the BAS tag.. for the other types of tags they will be different.
Parameters$min.max.values<-c(min(FLightR.data$Data$light), max(FLightR.data$Data$light))
Parameters$log.irrad.borders=c(-50, 50)
Parameters$start=known.coord

# Normally we would want to optimize parameters for 1 minute scale, but for the current silmulation
# we do not need to do it as we assume tag measures with the same rate as saves...


#tmp<-optim(par=Parameters$LogSlope, get.1.minute.parameters, gr=NULL, parameters=Parameters, method="L-BFGS-B", lower=c(-3, 0), upper=c(3, Inf), position=Parameters$start, start.time=min(All.slopes$Slopes$Time), end.time=max(All.slopes$Slopes$Time), print=T)

#Slope.1.minute<-tmp$par[1]
#SD.slope.1.minute<-tmp$par[2]

#Parameters$LogSlope_1_minute<-c(Slope.1.minute, SD.slope.1.minute)

Parameters$LogSlope_1_minute<-Parameters$LogSlope

# and now we could estimate time and latitude correction functions but I am still not sure how much they are actually needed
# as far functions after expect to have compensation functios ready we will just create a simple fake correction functions

time_correction_fun= eval(parse(text=paste("function (x) return(", Parameters$LogSlope[1], ")")))
Calibration<-list(Parameters=Parameters, time_correction_fun=time_correction_fun)

lat_correction_fun<-function(x, y, z) return(0)
#lat_correction_fun<-eval(parse(text=paste("function (x,y,z) return(", Parameters$LogSlope[2]^2/2, ")")))

Calibration$lat_correction_fun<-lat_correction_fun

#---------------------------------------------------------
# here is a fork.
# you might want to skip the outlier detection if you know that there is none
# e.g. in a this simulated example

#==============================================
#   START OF OPTIONAL OUTLIER DETECTION PART
#==============================================
#----------------------------------------------------------
# automated outlier detection:
#----------------------------------------------------------

Threads=detectCores()-1

Outliers<-detect.tsoutliers(Calibration, Proc.data, plot=T, Threads=Threads, max.outlier.proportion=0.2, simple.version=T)

# there shgoud not be obvious outliers left!!

Proc.data.full<-Proc.data
Proc.data<-Outliers$Proc.data

FLightR.data$twilights$excluded[which(!as.numeric(FLightR.data$twilights$datetime) %in% c(Proc.data$Twilight.time.mat.dusk[25,]+Calibration$Parameters$saving.period-Calibration$Parameters$measurement.period,  Proc.data$Twilight.time.mat.dawn[25,]) & FLightR.data$twilights$excluded!=1 )]<-2


#--------------------------------------------------------
# recalibration with outliers excluded..
#--------------------------------------------------------
Dusk.calib.days<-which(as.POSIXct(Proc.data$Twilight.time.mat.dusk[1,], tz="UTC", origin="1970-01-01") <= as.POSIXct("2013-08-04", tz="UTC"))
Twilight.time.mat.Calib.dusk<-Proc.data$Twilight.time.mat.dusk[,Dusk.calib.days]
Twilight.log.light.mat.Calib.dusk<-Proc.data$Twilight.log.light.mat.dusk[,Dusk.calib.days]

Dawn.calib.days<-which(as.POSIXct(Proc.data$Twilight.time.mat.dawn[1,], tz="UTC", origin="1970-01-01") <= as.POSIXct("2013-08-04", tz="UTC") )
Twilight.time.mat.Calib.dawn<-Proc.data$Twilight.time.mat.dawn[,Dawn.calib.days]
Twilight.log.light.mat.Calib.dawn<-Proc.data$Twilight.log.light.mat.dawn[,Dawn.calib.days ]

Calib.data.all<-logger.template.calibration(Twilight.time.mat.Calib.dawn, Twilight.log.light.mat.Calib.dawn, Twilight.time.mat.Calib.dusk, Twilight.log.light.mat.Calib.dusk, positions=known.coord,log.light.borders=log(c(2, 64)),  log.irrad.borders=c(-50, 50), plot=F) 
Calib.data.all<-Calib.data.all[[1]]

All.slopes<-get.calib.param(Calib.data.all, plot=T)

plot(log(All.slopes$Slopes$Slope)~All.slopes$Slopes$Time)

# there is one very strong outlier!
which(abs(log(All.slopes$Slopes$Slope)-mean(log(All.slopes$Slopes$Slope), na.rm=T))>5*sd(log(All.slopes$Slopes$Slope), na.rm=T))

Calib.data.all<-Calib.data.all[!Calib.data.all$Day%in% which(abs(log(All.slopes$Slopes$Slope)-mean(log(All.slopes$Slopes$Slope), na.rm=T))>5*sd(log(All.slopes$Slopes$Slope), na.rm=T)),]

All.slopes<-get.calib.param(Calib.data.all, plot=T)

plot(log(All.slopes$Slopes$Slope)~All.slopes$Slopes$Time)



##########
# Now we create 'parameters' object that will have all the details about the calibration
Parameters<-All.slopes$Parameters # LogSlope -0.31 0.29
Parameters$measurement.period<-Proc.data$measurement.period 
Parameters$saving.period<-Proc.data$saving.period 
Parameters$log.light.borders<-log(c(2, 64)) # these are the boundaries in which one should use the BAS tag.. for the other types of tags they will be different.
Parameters$min.max.values<-c(min(FLightR.data$Data$light), max(FLightR.data$Data$light))
Parameters$log.irrad.borders=c(-50, 50)
Parameters$start=known.coord

# Normally we would want to optimize parameters for 1 minute scale, but for the current silmulation
# we do not need to do it as we assume tag measures with the same rate as saves...


#tmp<-optim(par=Parameters$LogSlope, get.1.minute.parameters, gr=NULL, parameters=Parameters, method="L-BFGS-B", lower=c(-3, 0), upper=c(3, Inf), position=Parameters$start, start.time=min(All.slopes$Slopes$Time), end.time=max(All.slopes$Slopes$Time), print=T)

#Slope.1.minute<-tmp$par[1]
#SD.slope.1.minute<-tmp$par[2]

#Parameters$LogSlope_1_minute<-c(Slope.1.minute, SD.slope.1.minute)

Parameters$LogSlope_1_minute<-Parameters$LogSlope

# and now we could estimate time and latitude correction functions but I am still not sure how much they are actually needed
# as far functions after expect to have compensation functios ready we will just create a simple fake correction functions

time_correction_fun= eval(parse(text=paste("function (x) return(", Parameters$LogSlope[1], ")")))
Calibration<-list(Parameters=Parameters, time_correction_fun=time_correction_fun)

lat_correction_fun<-function(x, y, z) return(0)
#lat_correction_fun<-eval(parse(text=paste("function (x,y,z) return(", Parameters$LogSlope[2]^2/2, ")")))

Calibration$lat_correction_fun<-lat_correction_fun

#==============================================
#   END OF OPTIONAL OUTLIER DETECTION PART
#==============================================


###########################################################
##  Part 3. Define spatial extent for the optimisation   ##
###########################################################

# we will define just  a box, 
# but one could use any other more complicated shape

xlim = c(-120, -80)
ylim = c(5, 45)


Globe.Points<-regularCoordinates(200) # 50 km between each point

All.Points.Focus<-Globe.Points[Globe.Points[,1]>xlim[1] & Globe.Points[,1]<xlim[2] & Globe.Points[,2]>ylim[1] & Globe.Points[,2]<ylim[2],]

# here we could cut by the sea but we will not do it now

plot(All.Points.Focus, type="n")
map('state',add=TRUE, lwd=1,  col=grey(0.5))
map('world',add=TRUE, lwd=1.5,  col=grey(0.8))
abline(v=known.coord[1])
abline(h=known.coord[2])

Points.Land<-cbind(All.Points.Focus, Land=1)
# the masks work in a follwing way:
#
# Spatial constrain: if one wants to prevent animal being at this point at twilight 
# the point should just be excluded
# 
# Spatiobehavioural constrain: if you do allow to be flying at the point but not be stationary
# then set Land=0 for this point

##########################################################
## Part 4. Preestimation of all the matrices           ##
##########################################################
 
raw.Y.dusk<-correct.hours(FLightR.data$twilights$datetime[FLightR.data$twilights$type==2 & FLightR.data$twilights$excluded==0])
raw.X.dusk<-as.numeric(FLightR.data$twilights$datetime[FLightR.data$twilights$type==2 & FLightR.data$twilights$excluded==0])
Data_tmp<-list(d=FLightR.data$Data)
Result.Dusk<-make.result.list(Data_tmp, raw.X.dusk, raw.Y.dusk)

raw.Y.dawn<-correct.hours(FLightR.data$twilights$datetime[FLightR.data$twilights$type==1 & FLightR.data$twilights$excluded==0])
raw.X.dawn<-as.numeric(FLightR.data$twilights$datetime[FLightR.data$twilights$type==1 & FLightR.data$twilights$excluded==0])
Result.Dawn<-make.result.list(Data_tmp, raw.X.dawn, raw.Y.dawn)
Result.all<-list(Final.dusk=Result.Dusk, Final.dawn=Result.Dawn)
####

Index.tab<-create.proposal(Result.all, start=known.coord, Points.Land=Points.Land)
Index.tab$yday<-as.POSIXlt(Index.tab$Date, tz="GMT")$yday
Index.tab$Decision<-0.1 # prob of migration
Index.tab$Direction<- 0 # direction 0 - North
Index.tab$Kappa<-0 # distr concentration 0 means even
Index.tab$M.mean<- 300 # distance mu
Index.tab$M.sd<- 500 # distance sd

all.in<-geologger.sampler.create.arrays(Index.tab, Points.Land, start=known.coord)

all.in$Matrix.Index.Table$Decision<-0.1
all.in$M.mean<-300

# we also want to restrict irradiance values to c(-12, 5)
Calibration$Parameters$log.irrad.borders<-c(-12, 5)

# the next step might have some time
# with the current example it takes about 5 min at 24 core workstation

Threads= detectCores()-1
Phys.Mat<-get.Phys.Mat.parallel(all.in, Proc.data$Twilight.time.mat.dusk, Proc.data$Twilight.log.light.mat.dusk, Proc.data$Twilight.time.mat.dawn, Proc.data$Twilight.log.light.mat.dawn,  threads=Threads, calibration=Calibration)

all.in$Phys.Mat<-Phys.Mat

#---------------------------
# we can also check the pre-estimated matrices:

par(mfrow=c(3,3))
par(ask=T)
my.golden.colors <- colorRampPalette(
			c("white","#FF7100"))
for (i in 1:dim(all.in$Phys.Mat)[2]) {
image(as.image(all.in$Phys.Mat[,i], x=all.in$Points.Land[,1:2], nrow=30, ncol=30), col=my.golden.colors(64), main=paste( ifelse((all.in$Matrix.Index.Table$Dusk[i]), "Dusk","Dawn"), all.in$Matrix.Index.Table$Real.time[i], "i=", i))
	map('state',add=TRUE, lwd=1,  col=grey(0.5))
	map('world',add=TRUE, lwd=1.5,  col=grey(0.8))
	abline(v=all.in$Points.Land[all.in$start,1], col="grey", lwd=2)
	abline(h=all.in$Points.Land[all.in$start,2], col="grey", lwd=2)
}

# if there are any outliers it will be better to exclude them now
#setting all their values to 0 e.g all.in$Phys.Mat[,c(255,303, 306, 458, 476)]<-1

# saving object...
save(all.in, file="all.in.RData")


##########################################################
## Part 5. main run          ##
##########################################################



Threads= detectCores()-1
# do not forget about RAM - each node will eat 2 - 2.5 Gb of Ram!!!

Result<-run.particle.filter(all.in, save.Res=F, cpus=min(Threads,6), nParticles=1e6, known.last=T, precision.sd=25, sea.value=1, save.memory=T, k=NA, parallel=T, 
 plot=T, prefix="pf", extend.prefix=T, max.kappa=100, 
 min.SD=25, min.Prob=0.01, max.Prob=0.99, 
 fixed.parameters=list(M.mean=300, M.sd=500, Kappa=0), 
 cluster.type="SOCK", a=45, b=1500, L=90, update.angle.drift=F, adaptive.resampling=0.99, save.transitions=T, check.outliers=F)
gc()

save(Result, file="result.no.mask.RData")


#------------------
# here I will shorten the Result file to make loadeable on github..

format(object.size(Result), "Mb")
Result$distance<-NULL
Result$Azimuths<-NULL
Result$Phys.Mat<-NULL

save(Result, file="Result.short.RData")

#-------------------------
# If you did not make a full run you might want to download result from github:

Bin <- getBinaryURL ("https://raw.githubusercontent.com/eldarrak/FLightR/master/examples/example_for_NCEAS_paper/Result.short.RData", ssl.verifypeer = FALSE, followlocation = TRUE)
writeBin(Bin, "Result.short.RData")
load("Result.short.RData")

#########################################################
# Part 3. Plotting results
#########################################################
# map

#Read in the simulated track

# read script lines from website
text <- getURL("https://raw.githubusercontent.com/eldarrak/FLightR/master/examples/example_for_NCEAS_paper/SIM_PABU_TRACK_10min.csv", ssl.verifypeer = FALSE, followlocation = TRUE)

simTrack<-read.csv(text=text, stringsAsFactors =F)
simTrack$datetime <- strptime(simTrack$datetime, "%Y-%m-%d %H:%M:%S", "GMT")
base_track <- subset(simTrack, format(datetime,'%H') %in% c('12') & format(datetime,'%M') %in% c('00'))
summary(base_track)


pdf("FLightR_map.pdf",width=5,height=5)
par(mfrow=c(1,1))
par(mar=c(4,4,3,1),las=1,mgp=c(2.25,1,0))

#--------------------------------------------------------
# we could plot either mean or median.

Mean_coords<-cbind(Result$Quantiles$Meanlon, Result$Quantiles$Meanlat)
Median_coords<-cbind(Result$Quantiles$MedianlonJ, Result$Quantiles$MedianlatJ)
plot(Median_coords, type = "n",ylab="Latitude",xlab="Longitude")
data(wrld_simpl)
plot(wrld_simpl, add = T, col = "grey95", border="grey70")
lines(Median_coords, col = "darkgray", cex = 0.1)
points(Median_coords, pch = 16, cex = 0.75, col = "darkgray")
#lines(Mean_coords, col = "blue", cex = 0.1)
#points(Mean_coords, pch = 16, cex = 0.75, col = "blue")
lines(base_track$lon,base_track$lat, col = "black")
points(base_track$lon,base_track$lat, pch = 16, cex = 0.75, col = "black")
legend("bottomleft",legend = c("FLightR estimate", "known track"), col = c("darkgray", "black"), pch = 16,lty=1,cex=0.75)
title("FLightR analysis", line = 0.3)
box("plot")
dev.off()

#######################################
##Plot FLgihtR and known path by lat and long##
#######################################
Quantiles<-Result$Quantiles[1:length(Result$Matrix.Index.Table$Real.time),]
Quantiles$Time<-Result$Matrix.Index.Table$Real.time

pdf("FLightR_lat_lon.pdf",width=5,height=5)

par(mfrow=c(2,1))
par(mar=c(2,4,3,1),cex=1)
 Sys.setlocale("LC_ALL", "English")  

 #Longitude
plot(Quantiles$Medianlon~Quantiles$Time, las=1,col=grey(0.1),pch=16,ylab="Longitude",xlab="",lwd=2, ylim=range(c( Quantiles$LCI.lon, Quantiles$UCI.lon )), type="n")


polygon(x=c(Quantiles$Time, rev(Quantiles$Time)), y=c(Quantiles$LCI.lon, rev(Quantiles$UCI.lon)), col=grey(0.9), border=grey(0.5))

polygon(x=c(Quantiles$Time, rev(Quantiles$Time)), y=c(Quantiles$TrdQu.lon, rev(Quantiles$FstQu.lon)), col=grey(0.7), border=grey(0.5))

lines(Quantiles$Medianlon~Quantiles$Time, col=grey(0.1),lwd=2)

lines(base_track$datetime,base_track$lon, col = 'red', lwd=2)

abline(v=as.POSIXct("2013-09-22 21:34:30 EDT"), col="red", lwd=1)
abline(v=as.POSIXct("2014-03-22 21:34:30 EDT"), col="red", lwd=1)
title("FLightR analysis", line = 0.3)
legend("bottomright",legend = c("FLightR estimate", "known track"), col = c(grey(0.1), "red"), pch = c(NA,NA),lty=c(1,1),lwd=c(2,2),bg="white",cex=0.7)

#Latitude
par(mar=c(3,4,1,1))

plot(Quantiles$Medianlat~Quantiles$Time, las=1,col=grey(0.1),pch=16,ylab="Latitude",xlab="",lwd=2, ylim=range(c( Quantiles$UCI.lat, Quantiles$LCI.lat )), type="n")

polygon(x=c(Quantiles$Time, rev(Quantiles$Time)), y=c(Quantiles$LCI.lat, rev(Quantiles$UCI.lat)), col=grey(0.9), border=grey(0.5))

polygon(x=c(Quantiles$Time, rev(Quantiles$Time)), y=c(Quantiles$TrdQu.lat, rev(Quantiles$FstQu.lat)), col=grey(0.7), border=grey(0.5))

lines(Quantiles$Medianlat~Quantiles$Time, col=grey(0.1),lwd=2)

lines(base_track$datetime,base_track$lat, col = 'red', lwd=2)

abline(v=as.POSIXct("2013-09-22 21:34:30 EDT"), col="red", lwd=1)
abline(v=as.POSIXct("2014-03-22 21:34:30 EDT"), col="red", lwd=1)
legend("bottomright",legend = c("FLightR estimate", "known track"), col = c(grey(0.1), "red"), pch = c(NA,NA),lty=c(1,1),lwd=c(2,2),bg="white",cex=0.7)

dev.off()



