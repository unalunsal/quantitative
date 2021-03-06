library("quantmod")
library("parallel")
library("rugarch")
library("datasets")
library("crayon")
library("forecast")

#Define a function to delete NAs.There will be NAs in the retreived data from the Data Source.  
delete.na <- function(DF, n=0) {
  DF[rowSums(is.na(DF)) <= n,]
}

# Function that selects the optimum ARMA(p,q)-GARCH(m,n) parameters based on Information Criterion. 
# infoCrea = 1, means that Akaike Information Criterion (AIC) will be used to select ARMA(p,q)-GARCH(m,n) model parameters. 
# infoCrea = 2, means that Bayesian Information Criterion (BIC) will be used to select ARMA(p,q)-GARCH(m,n) model parameters. 
orderSelect <- function(df.train,infoCrea){
  final.ic = Inf
  final.order.ic = c(0,0,0,0)
  for (m in 0:1) for (n in 0:1) for (p in 0:3) for (q in 0:3) {
    spec = ugarchspec(variance.model=list(garchOrder=c(m,n)),
                        mean.model=list(armaOrder=c(p, q), include.mean=T),distribution.model="std")
    mod = ugarchfit(spec, diff(diff(df.train)), solver = "hybrid")
    current.ic = infocriteria(mod)[infoCrea]
    #print(paste("IC:", current.ic, "Order p q m n", p, q, m, n))
    
    if (current.ic < final.ic){
      final.ic = current.ic
      final.order.ic = c(p,q,m,n)
      fit = mod
    }
  }
  return(final.order.ic)
}


# Function that calculates the out of sample recursive RMSE value.
# SYMBOL: First Component of the function is the symbol for the time series data which will be retrieved from the SOURCE. 
# SOURCE: Second Componenet of the function which is the data source (E.g. FRED, YAHOO). 
# testRatio: Third Component of the function which the train set / test set ratio (E.g. testRatio = 0.5)
# infoCrea: Information criteria that will be used to choose optimum lags for the ARMA(p,q)-GARCH(m.n) model 
#           (E.g. infoCrea = 1 means Akaike Information Criterion (AIC) will be used to determine the optimum ARMA(p,q)-GARCH(m,n) parameters)
#                 infoCrea = 2 means Bayesian Information Criterion (BIC) will be used to determine the optimum ARMA(p,q)-GARCH(m,n) parameters). 

recursive <- function(SYMBOL, SOURCE,testRatio, infoCrea) {
  
  df = getSymbols(SYMBOL,src= SOURCE,auto.assign = getOption('loadSymbols.auto.assign',FALSE))
  df = as.vector(delete.na(df))
  rmse = 0 
  for (i in round(length(df)*testRatio):length(df)){
    df.train = df[0:(i-1)]
    df.test = df[i]
    pqmnorder = orderSelect(df.train, infoCrea) 
    p = pqmnorder[1]
    q = pqmnorder[2]
    m = pqmnorder[3]
    n = pqmnorder[4]
    spec = ugarchspec(variance.model=list(garchOrder=c(m,n)),
                      mean.model=list(armaOrder=c(p, q), include.mean=T),distribution.model="std")
    mod = ugarchfit(spec, diff(diff(df.train)), solver = "hybrid")
    fore = ugarchforecast(mod, n.ahead =1)@forecast$seriesFor + tail(df.train,1) + tail(diff(df.train),1)
    rmse = c(rmse, fore - df.test)
  }
  return(rmse[2:length(rmse)])
}

rmse = recursive("DEXUSEU", "FRED", 0.5, 2)

rmse = sqrt ( mean( rmse ^ 2 ) )

print(rmse)



