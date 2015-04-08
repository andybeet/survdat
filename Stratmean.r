#Stratmean.r v.2.0
#Generate stratified means from survey data
#SML

stratmean <- function (x, group.col, strat.col, nsta.col = 'ntows', area.wgt = 'W.h',
                       weight = 'BIOMASS', number = 'ABUNDANCE') {
  #x         <- data table with catch, station, and area data
  #group.col <- column of x which the mean is based on (i.e. svspp)
  #strat.col <- column of x with the stratum
  #nsta.col  <- column of x with the number of stations per stratum
  #area.wgt  <- column of x with the stratum weight
  #weight    <- column of x with the weight values (i.e. biomass)
  #number    <- column of x with the number of individuals
  
  #-------------------------------------------------------------------------------
  #Required packages
  library(data.table)
  
  #-------------------------------------------------------------------------------
  #User created functions
  #count occurances
  count<-function(x){
    num<-rep(1,length(x))
    out<-sum(num)
    return(out)
    }
    
  #-------------------------------------------------------------------------------
  x <- copy(x)
  
  setnames(x, c(group.col, strat.col, nsta.col, area.wgt, weight, number),
              c('group',   'strat',   'ntows', 'W.h',     'BIO',  'N'))
  
  #Fix Na's
  x[is.na(BIO), BIO := 0]
  x[is.na(N),   N   := 0]
  
  #Calculate weight per tow and number per tow
  setkey(x, group, strat, YEAR)
  
  x[, biomass.tow   := sum(BIO) / ntows, by = key(x)]
  x[, abundance.tow := sum(N)   / ntows, by = key(x)]
  
  #Calculated stratified means
  x[, weighted.biomass   := biomass.tow   * W.h]
  x[, weighted.abundance := abundance.tow * W.h]

  #Variance - need to account for zero catch
  x[, n.zero     := ntows - count(BIO), by = key(x)]
  
  x[, zero.var.b := n.zero * (0 - biomass.tow)^2]
  x[, vari.b := (BIO - biomass.tow)^2]
  x[, Sh.2.b := (zero.var.b + sum(vari.b)) / (ntows - 1), by = key(x)]
  x[is.nan(Sh.2.b), Sh.2.b := 0]
  
  x[, zero.var.a := n.zero * (0 - abundance.tow)^2]
  x[, vari.a := (N - abundance.tow)^2]
  x[, Sh.2.a := (zero.var.a + sum(vari.a)) / (ntows - 1), by = key(x)]
  x[is.nan(Sh.2.a), Sh.2.a := 0]
  
  stratified <- unique(x)
  
  setkey(stratified, group, YEAR)
  
  #Stratified mean  
  stratified[, strat.biomass := sum(weighted.biomass),   by = key(stratified)]
  stratified[, strat.abund   := sum(weighted.abundance), by = key(stratified)]
  
  #Stratified variance
  stratified[, biomass.S2 := sum(Sh.2.b * W.h) / sum(ntows) + sum((1 - W.h) * Sh.2.b)/sum(ntows)^2, by = key(stratified)]
  stratified[, abund.S2   := sum(Sh.2.a * W.h) / sum(ntows) + sum((1 - W.h) * Sh.2.a)/sum(ntows)^2, by = key(stratified)]
  
  #standard error of the means
  stratified[, biomass.SE := sqrt(biomass.S2) / sqrt(sum(ntows)), by = key(stratified)]
  stratified[, abund.SE   := sqrt(abund.S2)   / sqrt(sum(ntows)), by = key(stratified)]
  
  #Delete extra rows/columns
  stratified.means <- unique(stratified)
  stratified.means <- stratified.means[, list(YEAR, group, strat.biomass, biomass.S2, biomass.SE, strat.abund, abund.S2, abund.SE)]

  setnames(stratified.means, 'group', group.col)
  
  return(stratified.means)
  }