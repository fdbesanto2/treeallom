#!/usr/bin/env Rscript

suppressMessages(library(ggplot2)) 
suppressMessages(library(ggrepel)) 
suppressMessages(library(gridExtra)) 

source("../ols.r")
source("../nls.r")
source("../quantileregression.r")
source("../bootstrap.r")

options(expressions=500000)
args = commandArgs(trailingOnly=TRUE)

plotFig1 <- function(afname)
{
	allomdata <- read.table(afname,col.names=c("country","d","h","agb","rho"))
	adata <- data.frame(allomdata$d*allomdata$d*allomdata$h*allomdata$rho,allomdata$agb)
	colnames(adata) <- c("d2hrho","agb")
	ols_model <- fitOLS(adata)
	p1 <- ggplot()
	p1 <- p1 + geom_point(data=adata,aes(ols_model$fitted.values,resid(ols_model)),size=1,alpha=0.75,stroke=0)
	p1 <- p1 + geom_hline(yintercept=0, linetype="dashed",color = "red",alpha=0.75)
	p1 <- p1 + coord_cartesian(xlim=c(0,11.5), ylim = c(-1.5,1.5))
	p1 <- p1 + labs(x=expression(paste("Estimated [ln(AGB)]")),y=expression(paste("Residuals [","ln(AGB)"," - ","ln(",hat("AGB"),")]"))) 
	p1 <- p1 + theme(aspect.ratio=1/((1+sqrt(5))/2))
	p2 <- ggplot(ols_model, aes(sample = rstandard(ols_model))) 
	p2 <- p2 + geom_qq(size=1,alpha=0.75,stroke=0)
	p2 <- p2 + labs(x="Theoretical quantile",y="Sample quantile")	
	p2 <- p2 + stat_qq_line(linetype="dashed",color="red",alpha=0.75)
	p2 <- p2 + coord_cartesian(xlim=c(-4.5,4.5), ylim = c(-4.5,4.5))
	p2 <- p2 + scale_y_continuous(breaks=seq(-4,4,len = 5))
	p2 <- p2 + scale_x_continuous(breaks=seq(-4,4,len = 5))
	p2 <- p2 + theme(aspect.ratio=1)
	p <- grid.arrange(p1,p2,widths=c(1.51,1))
	ggsave("f1.pdf",plot=p,scale=1,limitsize=FALSE)
}

plotFig2 <- function(afname)
{
	alpha <- 0.05
	runs <- 3333
	x <- seq(0,150000,length.out=25)
	x <- data.frame(x)
	colnames(x) <- c("d2hrho")
	adata <- read.table(afname,col.names=c("country","d","h","agb","rho"))
	data <- data.frame(adata$d*adata$d*adata$h*adata$rho,adata$agb)
	colnames(data) <- c("d2hrho","agb")
	#
	m2_model <- fitNLS(data,FALSE,FALSE)
	m2_yhats <- yhat(m2_model,x)
	m2_nlqrmodels <- nlQuantileRegression(m2_model,data,alpha)
	m2_bmodels <- bootstrap(m2_model,data,runs)
	m2_pis <- getPredictionIntervals(m2_nlqrmodels,x)
	m2_cis <- getConfidenceIntervals(m2_bmodels,x,alpha)
	m2_df <- data.frame(x,m2_yhats,m2_pis[,1],m2_pis[,2],m2_cis[,1],m2_cis[,2])
	colnames(m2_df) <- c("x","y_m2","pil_m2","piu_m2","cil_m2","ciu_m2")
	m2_p <- ggplot(data=data,aes(d2hrho,agb))	
	for(i in 1:length(m2_bmodels))
	{
		m2_yboot <- yhat(m2_bmodels[[i]],x)
		m2_dfm <- data.frame(x,m2_yboot)
		colnames(m2_dfm) <- c("x","y")
		if(i == 1)
		{
			m2_p <- m2_p + geom_line(data=m2_dfm,aes(x,y,color='bstrap',linetype='bstrap',alpha='bstrap'))
		}
		else
		{
			m2_p <- m2_p + geom_line(data=m2_dfm,aes(x,y),color='grey',alpha=0.5)
		}
	}
	m2_p <- m2_p + geom_line(data=m2_df,aes(x,pil_m2,color='pinterval',linetype='pinterval',alpha='pinterval'))
        m2_p <- m2_p + geom_line(data=m2_df,aes(x,piu_m2),color='black',linetype='twodash',alpha=1)
        m2_p <- m2_p + geom_line(data=m2_df,aes(x,cil_m2,color='cinterval',linetype='cinterval',alpha='cinterval'))
        m2_p <- m2_p + geom_line(data=m2_df,aes(x,ciu_m2),color='black',linetype='dashed',alpha=1)
        m2_p <- m2_p + geom_point(data=data,aes(d2hrho,agb),size=1.5,alpha=0.75,stroke=0)
	m2_p <- m2_p + geom_line(data=m2_df,aes(x,y_m2,color='model',linetype='model',alpha='model'))
	m2_p <- m2_p + scale_color_manual(name='',values=c('model'='red','pinterval'='black','cinterval'='black','bstrap'='grey'),labels=c('model'=getModelExpForGgplot(m2_model),'pinterval'=paste(toString(100-(alpha*100)),'% ','prediction intervals',sep=''),'cinterval'=paste(toString(100-(alpha*100)),'% ','confidence intervals',sep=''),'bstrap'='Bootstrap samples'),breaks=c('model','pinterval','cinterval','bstrap'))
	m2_p <- m2_p + scale_linetype_manual(name='',values=c('model'='solid','pinterval'='twodash','cinterval'='dashed','bstrap'='solid'),labels=c('model'=getModelExpForGgplot(m2_model),'pinterval'=paste(toString(100-(alpha*100)),'% ','prediction intervals',sep=''),'cinterval'=paste(toString(100-(alpha*100)),'% ','confidence intervals',sep=''),'bstrap'='Bootstrap samples'),breaks=c('model','pinterval','cinterval','bstrap'))
	m2_p <- m2_p + scale_alpha_manual(name='',values=c('model'=1,'pinterval'=1,'cinterval'=1,'bstrap'=0.5),labels=c('model'=getModelExpForGgplot(m2_model),'pinterval'=paste(toString(100-(alpha*100)),'% ','prediction intervals',sep=''),'cinterval'=paste(toString(100-(alpha*100)),'% ','confidence intervals',sep=''),'bstrap'='Bootstrap samples'),breaks=c('model','pinterval','cinterval','bstrap'))
	m2_p <- m2_p + theme(legend.position=c(0.045,0.955),legend.justification=c(0,1),legend.text.align=0,legend.key=element_blank(),legend.title=element_blank(),plot.title=element_text(hjust = 0.5))
	m2_p <- m2_p + coord_cartesian(xlim=c(0,125000),ylim=c(0,80000))
	m2_p <- m2_p + labs(x=expression(paste("D"^{2},"H",rho," (kg)")),y=expression(paste("AGB"," (kg)")),title=expression(paste("NLS M2:  ","y = ",beta[1],X^beta[2]," + ",epsilon,"  [",epsilon," ~ N(0,",sigma^2,")]  (additive)")))
	m3_model <- fitNLS(data,TRUE,FALSE)
	m3_yhats <- yhat(m3_model,x)
	m3_nlqrmodels <- nlQuantileRegression(m3_model,data,alpha)
	m3_bmodels <- bootstrap(m3_model,data,runs)
	m3_pis <- getPredictionIntervals(m3_nlqrmodels,x)
	m3_cis <- getConfidenceIntervals(m3_bmodels,x,alpha)
	m3_df <- data.frame(x,m3_yhats,m3_pis[,1],m3_pis[,2],m3_cis[,1],m3_cis[,2])
	colnames(m3_df) <- c("x","y_m3","pil_m3","piu_m3","cil_m3","ciu_m3")
	m3_p <- ggplot(data=data,aes(d2hrho,agb))
	for(i in 1:length(m3_bmodels))
	{
		m3_yboot <- yhat(m3_bmodels[[i]],x)
		m3_dfm <- data.frame(x,m3_yboot)
		colnames(m3_dfm) <- c("x","y")
		if(i == 1)
		{
			m3_p <- m3_p + geom_line(data=m3_dfm,aes(x,y,color='bstrap',linetype='bstrap',alpha='bstrap'))
		}
		else
		{
			m3_p <- m3_p + geom_line(data=m3_dfm,aes(x,y),color='grey',alpha=0.5)
		}
	}
	m3_p <- m3_p + geom_line(data=m3_df,aes(x,pil_m3,color='pinterval',linetype='pinterval',alpha='pinterval'))
        m3_p <- m3_p + geom_line(data=m3_df,aes(x,piu_m3),color='black',linetype='twodash',alpha=1)
        m3_p <- m3_p + geom_line(data=m3_df,aes(x,cil_m3,color='cinterval',linetype='cinterval',alpha='cinterval'))
        m3_p <- m3_p + geom_line(data=m3_df,aes(x,ciu_m3),color='black',linetype='dashed',alpha=1)
        m3_p <- m3_p + geom_point(data=data,aes(d2hrho,agb),size=1.5,alpha=0.75,stroke=0)
	m3_p <- m3_p + geom_line(data=m3_df,aes(x,y_m3,color='model',linetype='model',alpha='model'))
	m3_p <- m3_p + scale_color_manual(name='',values=c('model'='red','pinterval'='black','cinterval'='black','bstrap'='grey'),labels=c('model'=getModelExpForGgplot(m3_model),'pinterval'=paste(toString(100-(alpha*100)),'% ','prediction intervals',sep=''),'cinterval'=paste(toString(100-(alpha*100)),'% ','confidence intervals',sep=''),'bstrap'='Bootstrap samples'),breaks=c('model','pinterval','cinterval','bstrap'))
	m3_p <- m3_p + scale_linetype_manual(name='',values=c('model'='solid','pinterval'='twodash','cinterval'='dashed','bstrap'='solid'),labels=c('model'=getModelExpForGgplot(m3_model),'pinterval'=paste(toString(100-(alpha*100)),'% ','prediction intervals',sep=''),'cinterval'=paste(toString(100-(alpha*100)),'% ','confidence intervals',sep=''),'bstrap'='Bootstrap samples'),breaks=c('model','pinterval','cinterval','bstrap'))
	m3_p <- m3_p + scale_alpha_manual(name='',values=c('model'=1,'pinterval'=1,'cinterval'=1,'bstrap'=0.5),labels=c('model'=getModelExpForGgplot(m3_model),'pinterval'=paste(toString(100-(alpha*100)),'% ','prediction intervals',sep=''),'cinterval'=paste(toString(100-(alpha*100)),'% ','confidence intervals',sep=''),'bstrap'='Bootstrap samples'),breaks=c('model','pinterval','cinterval','bstrap'))
	m3_p <- m3_p + theme(legend.position=c(0.045,0.955),legend.justification=c(0,1),legend.text.align=0,legend.key=element_blank(),legend.title=element_blank(),plot.title=element_text(hjust=0.5))
	m3_p <- m3_p + coord_cartesian(xlim=c(0,125000),ylim=c(0,80000))
	m3_p <- m3_p + labs(x=expression(paste("D"^{2},"H",rho," (kg)")),y=expression(paste("AGB"," (kg)")),title=expression(paste("NLS M3:  ","y = ",beta[1],X^beta[2]," + ",epsilon,"  [",epsilon," ~ N(0,",sigma^2,X^"k",")]  (multiplicative)")))
	m2e_p <- ggplot()
	m2e_p <- m2e_p + geom_point(data=data,aes(agb,yhat(m2_model,data)),size=1.5,alpha=0.75,stroke=0)
	m2e_p <- m2e_p + geom_abline(intercept=0,slope=1,color='red',linetype='dashed')
	m2e_p <- m2e_p + coord_cartesian(xlim=c(0,80000),ylim=c(0,80000))
	m2e_p <- m2e_p + labs(x=expression(paste("Observed AGB"," (kg)")),y=expression(paste("Estimated AGB"," (kg)")))
	m3e_p <- ggplot()
	m3e_p <- m3e_p + geom_point(data=data,aes(agb,yhat(m3_model,data)),size=1.5,alpha=0.75,stroke=0)
	m3e_p <- m3e_p + geom_abline(intercept=0,slope=1,color='red',linetype='dashed')
	m3e_p <- m3e_p + labs(x=expression(paste("Observed AGB"," (kg)")),y=expression(paste("Estimated AGB"," (kg)")))
	m3e_p <- m3e_p + coord_cartesian(xlim=c(0,80000),ylim=c(0,80000))
	m2el_p <- ggplot()
	m2el_p <- m2el_p + geom_point(data=data,aes(log(agb),log(yhat(m2_model,data))),size=1.5,alpha=0.75,stroke=0)
	m2el_p <- m2el_p + geom_abline(intercept=0,slope=1,color='red',linetype='dashed')
	m2el_p <- m2el_p + labs(x=expression(paste("Observed ln(AGB)")),y=expression(paste("Estimated ln(AGB)")))
	m2el_p <- m2el_p + coord_cartesian(xlim=c(0,11.5),ylim=c(0,11.5))
	m3el_p <- ggplot()
	m3el_p <- m3el_p + geom_point(data=data,aes(log(agb),log(yhat(m3_model,data))),size=1.5,alpha=0.75,stroke=0)
	m3el_p <- m3el_p + geom_abline(intercept=0,slope=1,color='red',linetype='dashed')
	m3el_p <- m3el_p + labs(x=expression(paste("Observed ln(AGB)")),y=expression(paste("Estimated ln(AGB)")))
	m3el_p <- m3el_p + coord_cartesian(xlim=c(0,11.5),ylim=c(0,11.5))
	p <- grid.arrange(m2_p,m3_p,m2e_p,m3e_p,m2el_p,m3el_p,nrow=3,ncol=2)
	ggsave("f2.pdf",plot=p,scale=1.57,limitsize=FALSE)
}

plotFig3 <- function(args)
{
	adata <- read.table(args[1],col.names=c("country","d","h","agb","rho"))
	data = data.frame(adata$d*adata$d*adata$h*adata$rho,adata$agb)
	colnames(data) <- c("d2hrho","agb")
	M2_model <- fitNLS(data,FALSE,FALSE)
	M3_model <- fitNLS(data,TRUE,FALSE)
	M2_name <- as.expression(bquote("NLS M2: "~.(toString(round(coefficients(M2_model)[1],3)))~D^{2}*H*rho^{.(toString(round(coefficients(M2_model)[2],3)))}~" (additive)"))
	M3_name <- as.expression(bquote("NLS M3: "~.(toString(round(coefficients(M3_model)[1],3)))~D^{2}*H*rho^{.(toString(round(coefficients(M3_model)[2],3)))}~" (multiplicative)"))
	results <- read.table(args[2],header=TRUE)
	p <- ggplot(data=results)
	p <- p + geom_pointrange(data=results,aes(x=ba/sc,y=nls2_p_agb,ymin=nls2_p_agb_li,ymax=nls2_p_agb_ui,color='M2',shape='M2'))
	p <- p + geom_pointrange(data=results,aes(x=ba/sc,y=nls3_p_agb,ymin=nls3_p_agb_li,ymax=nls3_p_agb_ui,color='M3',shape='M3'))
	p <- p + geom_text_repel(data=results,aes(ba/sc,nls2_p_agb,label=pid),direction=c("x"),max.iter=1000000)#),direction=c("x"),point.padding = NA)
	p <- p + scale_color_manual(name='',values=c('M2'='red','M3'='black'),labels=c('M2'=M2_name,'M3'=M3_name),breaks=c('M3','M2'))
	p <- p + scale_shape_manual(name='',values=c('M2'=20,'M3'=18),labels=c('M2'=M2_name,'M3'=M3_name),breaks=c('M3','M2'))
	p <- p + coord_cartesian(xlim=c(0.05,0.115),ylim=c(100000,700000))
	p <- p + labs(x=expression(paste("Mean basal area (",m^2,")")),y=expression(paste("AGB"," (kg)")))
	p <- p + scale_y_continuous(labels=scales::comma)
	p <- p + theme(legend.position=c(0.9,0.03),legend.justification=c(1,0),legend.text.align=0,legend.title=element_blank(),legend.key=element_blank(),aspect.ratio=1/((1+sqrt(5))/2))
	p <- p + guides(colour = guide_legend(reverse=T)) + guides(shape = guide_legend(reverse=T))
	ggsave("f3.pdf",plot=p,scale=1,limitsize=FALSE)
}

plotFig4 <- function(args)
{
	adata <- read.table(args[1],col.names=c("country","d","h","agb","rho"))
	data = data.frame(adata$d*adata$d*adata$h*adata$rho,adata$agb)
	colnames(data) <- c("d2hrho","agb")
	M2_model <- fitNLS(data,FALSE,FALSE)
	M3_model <- fitNLS(data,TRUE,FALSE)
	M2_name <- as.expression(bquote("NLS M2: "~.(toString(round(coefficients(M2_model)[1],3)))~D^{2}*H*rho^{.(toString(round(coefficients(M2_model)[2],3)))}~" (additive)"))
	M3_name <- as.expression(bquote("NLS M3: "~.(toString(round(coefficients(M3_model)[1],3)))~D^{2}*H*rho^{.(toString(round(coefficients(M3_model)[2],3)))}~" (multiplicative)"))
	data <- data.frame(
			  d = c(0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0),#,1.1,1.2,1.3,1.4,1.5),
			m2_agb = c(3877417,3709436,3455037,3096358,2708609,2204345,1703616,1349290,1038577,719482),#,493395,438447,386113,269015,202945),
			m3_agb = c(4282187,4002768,3642556,3181426,2718904,2154760,1621391,1251635,937787,625930))#,414310,363704,317315,212417,155201))
	p <- ggplot(data=data)
	p <- p + labs(x="Minimum diameter (m)",y="Total AGB (kg)")
	p <- p + geom_point(data=data,aes(d,m2_agb,color='M2',shape='M2'),size=2)
	p <- p + geom_point(data=data,aes(d,m3_agb,color='M3',shape='M3'),size=2)
	p <- p + scale_color_manual(name='',values=c('M2'='red','M3'='black'),labels=c('M2'=M2_name,'M3'=M3_name),breaks=c('M3','M2'))
	p <- p + scale_shape_manual(name='',values=c('M2'=20,'M3'=18),labels=c('M2'=M2_name,'M3'=M3_name),breaks=c('M3','M2'))
	p <- p + geom_line(data=data,aes(d,m2_agb),color='red',linetype='twodash',alpha=0.75)
	p <- p + geom_line(data=data,aes(d,m3_agb),color='black',linetype='dashed',alpha=0.75)
	p <- p + scale_y_continuous(labels = scales::comma)
	p <- p + scale_x_continuous(breaks = scales::pretty_breaks(n = 5))
	p <- p + theme(legend.position=c(0.99,0.715),legend.justification=c(1,0),legend.text.align=0,legend.title=element_blank(),legend.key=element_blank(),aspect.ratio=1/((1+sqrt(5))/2))
	p <- p + guides(colour = guide_legend(reverse=T)) + guides(shape = guide_legend(reverse=T))
	ggsave("f4.pdf",plot=p,scale=1,limitsize=FALSE)
}

#plotFig1(args)
#plotFig2(args)
#plotFig3(args)
#plotFig4(args)