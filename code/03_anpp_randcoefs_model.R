##  anpp_randcoefs_model.R: Script to run GLMM analysis to test for treatment 
##  effects on the relationship between precipitation and ANPP.
##
##  NOTE: Stan may issue a couple warnings after running the MCMC that, as
##  the messages state, can be safely ignored. Just rejects a couple proposals
##  that result in ill-formed covariance matrices.
##
##  Author: Andrew Tredennick
##  Date created: June 2, 2017

##  Clear everything
rm(list = ls(all.names = TRUE))

##  Set working directory to source file location
setwd(dirname(rstudioapi::getActiveDocumentContext()$path)) # only for RStudio



####
####  LOAD LIBRARIES ----
####
library(tidyverse)    # Data munging
library(dplyr)        # Data summarizing
library(ggthemes)     # Pleasing ggplot themes
library(stringr)      # Working with strings
library(rstan)        # For MCMC
library(lme4)         # Mixed-effects modeling



####
####  READ IN AND EXTRACT EXPERIMENT ANPP DATA ----
####
source("read_format_data.R")

my_df <- anpp_data
my_df$y <- as.numeric(scale( log( anpp_data$anpp ) ))
m1 <- lmer( y ~ Treatment*vwc_scaled + (1|year_id) + (vwc_scaled|quadname), my_df)
summary(m1)

attr(VarCorr(m1)$quadname, 'correlation')



####
####  SET UP AND FIT MODEL IN STAN ----
####
##  Set up fixed and random design matrices
lmod <- lm(log(anpp) ~ Treatment*vwc_scaled, anpp_data)
x    <- model.matrix(lmod)
newx <- unique(x)
head(x)
lmod <- lm(log(anpp) ~ vwc_scaled, anpp_data)
z    <- model.matrix(lmod)

##  Make data list for Stan
anppdat <- list(
  Nobs     = nrow(anpp_data),
  Npreds   = ncol(x),
  Npreds2  = ncol(z),
  Nplots   = length(unique(anpp_data$quadname)),
  Ntreats  = length(unique(anpp_data$Treatment)),
  Nyears   = length(unique(anpp_data$year)),
  y        = as.numeric(scale(log(anpp_data$anpp))),
  x        = x,
  z        = z,
  plot_id  = as.numeric(as.factor(anpp_data$quadname)),
  treat_id = as.numeric(as.factor(as.character(anpp_data$Treatment))),
  year_id  = as.numeric(as.factor(anpp_data$year))
  ) # close list

##  Set Stan options
rstan_options(auto_write = TRUE)
options(mc.cores = parallel::detectCores())
set.seed(123)

##  Fit the model in Stan
rt  <- stanc("anpp_randcoefs.stan")
sm  <- stan_model(stanc_ret = rt, verbose = FALSE)
fit <- sampling(sm, data = anppdat, iter = 10000, chains = 4, thin = 10)

##  Save the model fit
saveRDS(fit, "../results/randcoefs_alltreatments_fit.RDS")



####
####  OPTIONAL DIAGNOSTICS ----
####
# betas <- as.numeric( summary(fit, 'beta')$summary[,1] )
# 
# df <- data.frame( x = anppdat$x, predicted = anppdat$x %*% betas)
# 
# df <- df %>% 
#   mutate( predicted = predicted*sd(log(anpp_data$anpp)) + mean(log(anpp_data$anpp))) %>% 
#   mutate( Treatment = ifelse( x.TreatmentDrought == 1, 'Drought', 'Control')) %>% 
#   mutate( Treatment = ifelse( x.TreatmentIrrigation == 1, 'Irrigation', Treatment)) %>% 
#   mutate( VWC = anpp_data$total_seasonal_vwc) %>% 
#   mutate( observed = anpp_data$anpp) %>% 
#   mutate( year = anppdat$year_id)
# 
# ggplot(df, aes( x = VWC, y = predicted, color = Treatment, shape = factor( year))) + 
#   geom_line(aes( group  = Treatment)) + 
#   geom_point( aes( x = VWC, y = log(observed))) + 
#   scale_color_manual(values = c('black', 'red', 'blue')) + 
#   ylab( 'Annual Net Primary Productivity') 
# 
# L_u <- matrix( summary(fit, 'L_u')$summary[,1], 2,2, byrow = T)
# L_u #lower cholesky
# L_u%*%t(L_u) # this should be the correlation matrix but it's odd that the lower diagonal is not one
# R <- matrix( summary(fit, 'R')$summary[,1], 2,2, byrow = T)
# 
# 
# library(bayesplot)
# stan_diag(fit)
# draws <- as.array(fit, pars = 'beta')
# mcmc_trace(draws)
# summary(fit, pars = "beta")
