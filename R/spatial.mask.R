# this function creates a spatial mask
# the main feture is that it will search for any land in the ditance of xx meters, 


#' makes spatial grid
#' 
#' This function makes a rectangular grid with use defined boundaries and probabilities of being stationary.
#' @param left - left boundary in degrees (-180 <= left <= 180)
#' @param bottom - lower boundary in degrees (-90 <= bottom <= 90)
#' @param right - right boundary in degrees (-180 <= right <= 180)
#' @param top - top boundary in degrees (-90 <= right <= 90)
#' @param distance.from.land.allowed.to.use - define how far from the shore animal could occur. Unit - km, negative values are for inland and positive for offshore directions. \code{Inf} stays for infinity
#' @param distance.from.land.allowed.to.stay - define how far from the shore animal could stay stationary between twilights. Unit - km, negative values are for inland and positive for offshore directions. \code{Inf} stays for infinity
#' @param return.distances - return distances to the shoreline
#' @param probability.of.staying - assigned probability value for grid cells that do not satisfy \code{distance.from.water.allowed.to.stay}
#' @param plot show a plot of final grid.
#' @return dataframe with coordinates(lon and lat) and \code{probability.of.staying}
#' @examples
#' Grid<-make.grid(left=-14, bottom=30, right=13, top=57,
#'   distance.from.land.allowed.to.use=c(-Inf, Inf),
#'   distance.from.land.allowed.to.stay=c(-Inf, Inf))
#'
#' @author Eldar Rakhimberdiev
#' 
#' @export
make.grid<-function(left=-180, bottom=-90,
                    right=180, top=90,
					distance.from.land.allowed.to.use=c(-Inf,Inf),
					distance.from.land.allowed.to.stay=c(-Inf, Inf), plot=TRUE, return.distances=FALSE, probability.of.staying=0.5) {
   bb<-c(left, bottom, right, top)
   #data('Points', package='FLightR')
  
   if (distance.from.land.allowed.to.stay[1]> -25) distance.from.land.allowed.to.stay[1]<- -25
   if (distance.from.land.allowed.to.stay[2]<25) distance.from.land.allowed.to.stay[2]<- 25

   if (left<right) {
      All.Points.Focus<-Points[Points[,1]>=left &
                  Points[,1]<=right & 
                  Points[,2]>=bottom &
                  Points[,2]<=top &
				  Points[,3]<distance.from.land.allowed.to.use[2] &
				  Points[,3]>distance.from.land.allowed.to.use[1],]
    } else {
      All.Points.Focus<-Points[(Points[,1]>=left |
                  Points[,1]<=right) & 
                  Points[,2]>=bottom &
                  Points[,2]<=top &
				  Points[,3]<distance.from.land.allowed.to.use[2] &
				  Points[,3]>distance.from.land.allowed.to.use[1],]
	
	}
    Stay<-as.numeric(All.Points.Focus[,3] > distance.from.land.allowed.to.stay[1]) & as.numeric(All.Points.Focus[,3]<distance.from.land.allowed.to.stay[2])
    Grid<-cbind(All.Points.Focus[,1:2], Stay)
	Grid[,3][Grid[,3]==0]<-probability.of.staying
	if (return.distances) Grid<-cbind(Grid, All.Points.Focus[,3])
	if (plot) {
        graphics::plot(Grid, type="n")
    	wrld_simpl<-NA
		load(system.file("data", "wrld_simpl.rda", package = "maptools"))
        sp::plot(wrld_simpl, lwd=1.5, add=TRUE)
        graphics::points(Grid[,1:2], pch=".", col="grey", cex=2) 
        graphics::points(Grid[Grid[,3]==1,1:2], pch=".", col="orange", cex=2) 
	}	
	attr(Grid,'left') <- left
	attr(Grid,'bottom') <- bottom
	attr(Grid,'right') <- right
	attr(Grid,'top') <- top
	attr(Grid,'distance.from.land.allowed.to.use') <- distance.from.land.allowed.to.use
	attr(Grid,'distance.from.land.allowed.to.stay') <- distance.from.land.allowed.to.stay
    return(Grid)
	}


create.land.mask<-function(Points, distance_km=25) {
distance<-distance_km*1000
Sp.All.Points.Focus<-sp::SpatialPoints(Points, proj4string=sp::CRS("+proj=longlat +datum=WGS84"))
#############
# ok, let's check
wrld_simpl<-NA
 
load(system.file("data", "wrld_simpl.rda", package = "maptools"))

Potential_water<-is.na(sp::over( sp::spTransform(Sp.All.Points.Focus, sp::CRS("+proj=longlat +datum=WGS84")), sp::spTransform(wrld_simpl, sp::CRS("+proj=longlat +datum=WGS84")))[,1])

# Now we have potential water and we could try to estimate distance on lonlat (first) and after it in km

wrld_simpl_t<-sp::spTransform(wrld_simpl,  CRS=sp::CRS(sp::proj4string(Sp.All.Points.Focus)))

#-----------------
#Close_to_coast<-rep(0, length(Potential_water))

#for (i in 1:nrow(Points)) {
#if (Potential_water[i]==0) next 
#Close_to_coast[i]<-as.numeric(gWithinDistance(Sp.All.Points.Focus[i,], wrld_simpl_t, ))
#cat("\r",i)
#}
#--------------------
# and now, for these special poitns we want to double check in the right projection

Land<-as.numeric(!Potential_water)

for (i in 1:nrow(Points)) {
#if (Close_to_coast[i]==1) {
if (Potential_water[i]==TRUE) {
Land[i]<-as.numeric(rgeos::gWithinDistance( sp::spTransform(Sp.All.Points.Focus[i,], sp::CRS(paste("+proj=aeqd +lon=", Sp.All.Points.Focus[i,]@coords[1], "lat=", Sp.All.Points.Focus[i,]@coords[2], sep=""))), sp::spTransform(wrld_simpl, sp::CRS(paste("+proj=aeqd +lon=", Sp.All.Points.Focus[i,]@coords[1], "lat=", Sp.All.Points.Focus[i,]@coords[2], sep=""))), distance))
cat("\r",i)
}

}
return(Land)
}

get.distance.to.water<-function(Points) {
  Points[,2]<-pmin(Points[,2], 89.9)
  Points[,2]<-pmax(Points[,2], -89.9)
   Sp.All.Points.Focus<-sp::SpatialPoints(Points, 
         proj4string=sp::CRS( "+proj=longlat +datum=WGS84"))

  	wrld_simpl<-NA
   load(system.file("data", "wrld_simpl.rda", package = "maptools"))
   wrld_simpl_l <- methods::as(wrld_simpl, 'SpatialLines')

   Potential_water<-is.na(sp::over(
        sp::spTransform(Sp.All.Points.Focus, sp::CRS("+proj=longlat +datum=WGS84")),
		sp::spTransform(wrld_simpl, sp::CRS("+proj=longlat +datum=WGS84")))[,1])

   Distance<-as.numeric(Potential_water)


   for (i in 1:nrow(Points)) {
      if (Potential_water[i]==TRUE) {
	     Point<-Sp.All.Points.Focus[i,]
         Distance[i]<-rgeos::gDistance(sp::spTransform(Point, sp::CRS(paste("+proj=aeqd +R=6371000 +lon_0=", Point@coords[1], " +lat_0=", Point@coords[2], sep=""))), sp::spTransform(wrld_simpl_l, sp::CRS(paste("+proj=aeqd +R=6371000 +lon_0=", Point@coords[1], " +lat_0=", Point@coords[2], sep=""))))/1000
         cat("\r",i)
      }
   }
   return(Distance)
}

#D<-get.distance.to.water(Points)
