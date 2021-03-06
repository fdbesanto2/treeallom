#!/usr/bin/env Rscript

#Andrew Burt - a.burt@ucl.ac.uk

suppressMessages(library(quantreg))

nlQuantileRegression <- function(model,data,alpha=0.05)
{
	nlqrmodels <- vector(mode="list",length=2)
	func  <- y ~ a * X ^ b
	a <- coefficients(model)[1]
	b <- coefficients(model)[2]
	lmodel <- nlrq(func,data=data,start=list(a=a,b=b),tau=alpha/2)
	umodel <- nlrq(func,data=data,start=list(a=a,b=b),tau=1-(alpha/2))
	nlqrmodels[[1]] <- lmodel
	nlqrmodels[[2]] <- umodel
	return(nlqrmodels)
}

getPredictionIntervals <- function(nlqrmodels,data)
{
	intervals <- matrix(0,nrow(data),ncol=2)
	intervals[,1] <- yhat(nlqrmodels[[1]],data)
	intervals[,2] <- yhat(nlqrmodels[[2]],data)
	return(intervals)
}
