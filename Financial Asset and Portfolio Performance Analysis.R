#Installing packages as needed

#NOTE: This statement essentially checks if PerformanceAnalytics package is available
#locally in your R library distribution. If not, it will install it and then include it
#as a part of this code, so that we can use its functions and features
if (!require(tidyverse)) install.packages("tidyverse")
if (!require(tidyquant)) install.packages("tidyquant")
if (!require(PerformanceAnalytics)) install.packages("PerformanceAnalytics")
if (!require(xts)) install.packages("xts")
if (!require(lubridate)) install.packages("lubridate")
#Package Details

#1) Tidyverse: The tidyverse is an opinionated collection of R packages designed for data science. All packages share an underlying design philosophy, grammar, and data structures: https://www.tidyverse.org/

#2)Tidyquant: The 'tidyquant' package provides a convenient wrapper to various 'xts', 'zoo', 'quantmod' and 'TTR' package functions and returns the objects in the tidy 'tibble' format. The main advantage is being able to use quantitative functions with the 'tidyverse' functions including 'purrr', 'dplyr', 'tidyr', 'ggplot2', 'lubridate', etc: https://www.rdocumentation.org/packages/tidyquant/versions/0.3.0

#3)Performanceanalytics: A very useful package for investment and financial performance and risk 
#analytics. Official Documentation: https://www.rdocumentation.org/packages/PerformanceAnalytics/versions/1.5.3
#Presentation Deck by Package Founders: http://past.rinfinance.com/RinFinance2009/presentations/PA%20Workshop%20Chi%20RFinance%202009-04.pdf
#Quick Video on calculating returns: https://www.youtube.com/watch?v=0rAVPUNf9yI

#4) xts: xts is a useful packge useful in time-series analysis. We use xts package here since
#PerformanceAnalytics functions usually require xts objects (time-series of prices etc.) rather than simple
#lists of prices for more accurate performance evaluation

#5) lubridate: lubridate is a date manipulation package. We use mdy() function of lubridate to standardize dates of our data 
#Useful Resource: https://raw.githubusercontent.com/rstudio/cheatsheets/master/lubridate.pdf
library(tidyverse)
library(tidyquant)
library(PerformanceAnalytics)
library(xts)
library(lubridate)
tickers <- c(
  "SPY",
  "EFA",
  "IJS",
  "EEM",
  "AGG",
  "TLT",
  "VNQ")
tickers <- "SPY"

prices_volume_via_tq_2020 <- 
  tickers %>% 
  tq_get(get = "stock.price", from = "2020-01-01") %>% 
  select(date,ticker = symbol, close, volume) %>%
  mutate(date = as.Date(date))
prices_volume_via_tq_2020
#Financial asset (individual stocks, securities, etc) and portfolio (groups of stocks, securities, etc) performance analysis is a deep field with a wide range of theories and methods for analyzing risk versus reward. The PerformanceAnalytics package consolidates functions to compute many of the most widely used performance metrics. tidquant integrates this functionality so it can be used at scale using the split, apply, combine framework within the tidyverse. Two primary functions integrate the performance analysis functionality:

##tq_performance implements the performance analysis functions in a tidy way, enabling scaling analysis using the split, apply, combine framework.
##tq_portfolio provides a useful tool set for aggregating a group of individual asset returns into one or many portfolios.

#An important concept is that performance analysis is based on the statistical properties of returns (not prices). As a result, this package uses inputs of time-based returns as opposed to stock prices. The arguments change to Ra for the asset returns and Rb for the baseline returns. We’ll go over how to get returns in the Workflow section.

#Another important concept is the baseline. The baseline is what you are measuring performance against. A baseline can be anything, but in many cases it’s a representative average of how an investment might perform with little or no effort. Often indexes such as the S&P500 are used for general market performance. Other times more specific Exchange Traded Funds (ETFs) are used such as the SPDR Technology ETF (XLK). The important concept here is that you measure the asset performance (Ra) against the baseline (Rb).


# Getting the Asset Period Returns
# Use tq_get() to get stock prices.
stock_prices <- c("AAPL", "GOOG", "NFLX") %>%
  tq_get(get  = "stock.prices",
         from = "2010-01-01",
         to   = Sys.Date())
stock_prices
# Using the tidyverse split, apply, combine framework, we can mutate groups of stocks by first “grouping”
#with group_by and then applying a mutating function using tq_transmute. We use the quantmod function periodReturn
#as the mutating function. We pass along the arguments period = "monthly" to return the results in monthly
#periodicity. Last, we use the col_rename argument to rename the output column.

stock_returns_monthly <- stock_prices %>%
  group_by(symbol) %>%
  tq_transmute(select     = adjusted, 
               mutate_fun = periodReturn, 
               period     = "monthly", 
               col_rename = "Ra")
stock_returns_monthly
# Getting SPDR Technology ETF i.e.XLK (Baseline for Market) Returns 
baseline_returns_monthly <- "XLK" %>%
  tq_get(get  = "stock.prices",
         from = "2010-01-01",
         to   = Sys.Date()) %>%
  tq_transmute(select     = adjusted, 
               mutate_fun = periodReturn, 
               period     = "monthly", 
               col_rename = "Rb")
baseline_returns_monthly
#The tidyquant function, tq_portfolio() aggregates a group of individual assets into a single return using a weighted composition of the underlying assets. To do this we need to first develop portfolio weights. We supplying a vector of weights and form the portfolio.
wts <- c(0.4, 0.3, 0.3)
portfolio_returns_monthly <- stock_returns_monthly %>%
  tq_portfolio(assets_col  = symbol, 
               returns_col = Ra, 
               weights     = wts, 
               col_rename  = "Ra")
# Now that we have the aggregated portfolio returns (“Ra”) and the baseline returns (“Rb”), we can merge to get our consolidated table of asset and baseline returns. Nothing new here.
RaRb_single_portfolio <- left_join(portfolio_returns_monthly, 
                                   baseline_returns_monthly,
                                   by = "date")
# Computing the CAPM Table
# The CAPM table is computed with the function table.CAPM from PerformanceAnalytics.
RaRb_single_portfolio %>%
  tq_performance(Ra = Ra, Rb = Rb, performance_fun = table.CAPM) %>%
  select(Alpha, AnnualizedAlpha, Beta, Correlation, 'R-squared')
# First, we need to grow our portfolios. tidyquant has a handy, albeit simple, function, tq_repeat_df(), for scaling a single portfolio to many. It takes a data frame, and the number of repeats, n, and the index_col_name, which adds a sequential index. Let’s see how it works for our example. We need three portfolios:

stock_returns_monthly_multi <- stock_returns_monthly %>%
  tq_repeat_df(n = 3)
#Examining the results, we can see that a few things happened:

##The length (number of rows) has tripled. This is the essence of tq_repeat_df: it grows the data frame length-wise, repeating the data frame n times. In our case, n = 3.
##Our data frame, which was grouped by symbol, was ungrouped. This is needed to prevent tq_portfolio from blending on the individual stocks. tq_portfolio only works on groups of stocks.
##We have a new column, named “portfolio”. The “portfolio” column name is a key that tells tq_portfolio that multiple groups exist to analyze. Just note that for multiple portfolio analysis, the “portfolio” column name is required.
##We have three groups of portfolios. This is what tq_portfolio will split, apply (aggregate), then combine on.

#Now the tricky part: We need a new table of weights to map on. There’s a few requirements:

##We must supply a three column tibble with the following columns: “portfolio”, asset, and weight in that order.
##The “portfolio” column must be named “portfolio” since this is a key name for mapping.
##The tibble must be grouped by the portfolio column.

#Here’s what the weights table should look like:

weights <- c(
  0.50, 0.25, 0.25,
  0.25, 0.50, 0.25,
  0.25, 0.25, 0.50
)
stocks <- c("AAPL", "GOOG", "NFLX")
weights_table <-  tibble(stocks) %>%
  tq_repeat_df(n = 3) %>%
  bind_cols(tibble(weights)) %>%
  group_by(portfolio)
weights_table
# Now just pass the the expanded stock_returns_monthly_multi and the weights_table to tq_portfolio for portfolio aggregation.


portfolio_returns_monthly_multi <- stock_returns_monthly_multi %>%
  tq_portfolio(assets_col  = symbol, 
               returns_col = Ra, 
               weights     = weights_table, 
               col_rename  = "Ra")

#we merge with the baseline using “date” as the key.
RaRb_multiple_portfolio <- left_join(portfolio_returns_monthly_multi, 
                                     baseline_returns_monthly,
                                     by = "date")
RaRb_multiple_portfolio %>%
  tq_performance(Ra = Ra, Rb = Rb, performance_fun = table.CAPM) %>%
  select(Alpha, AnnualizedAlpha, Beta, Correlation, 'R-squared')
# Let’s see an example of passing parameters. Suppose we want to instead see how our money is grows for a $1,000 investment. We’ll use the “Single Portfolio” example, where our portfolio mix was 40% AAPL, 30% GOOG, and 30% NFLX.


wts <- c(0.4, 0.3, 0.3)
portfolio_returns_monthly <- stock_returns_monthly %>%
  tq_portfolio(assets_col  = symbol, 
               returns_col = Ra, 
               weights     = wts, 
               col_rename  = "Ra")
portfolio_returns_monthly %>%
  ggplot(aes(x = date, y = Ra)) +
  geom_bar(stat = "identity", fill = palette_light()[[1]]) +
  labs(title = "Portfolio Returns",
       subtitle = "40% AAPL, 30% GOOG, and 30% NFLX",
       caption = "Shows an above-zero trend meaning positive returns",
       x = "", y = "Monthly Returns") +
  geom_smooth(method = "lm") +
  theme_tq() +
  scale_color_tq() +
  scale_y_continuous(labels = scales::percent)
# This is good, but we want to see how our $1,000 initial investment is growing. This is simple with the underlying Return.portfolio argument, wealth.index = TRUE. All we need to do is add these as additional parameters to tq_portfolio!


wts <- c(0.4, 0.3, 0.3)
portfolio_growth_monthly <- stock_returns_monthly %>%
  tq_portfolio(assets_col   = symbol, 
               returns_col  = Ra, 
               weights      = wts, 
               col_rename   = "investment.growth",
               wealth.index = TRUE) %>%
  mutate(investment.growth = investment.growth * 1000)
portfolio_growth_monthly %>%
  ggplot(aes(x = date, y = investment.growth)) +
  geom_line(size = 2, color = palette_light()[[1]]) +
  labs(title = "Portfolio Growth",
       subtitle = "40% AAPL, 30% GOOG, and 30% NFLX",
       caption = "Now we can really visualize performance!",
       x = "", y = "Portfolio Value") +
  geom_smooth(method = "loess") +
  theme_tq() +
  scale_color_tq() +
  scale_y_continuous(labels = scales::dollar)
#Finally, taking this one step further, we apply the same process to the “Multiple Portfolio” example:

##50% AAPL, 25% GOOG, 25% NFLX
##25% AAPL, 50% GOOG, 25% NFLX
##25% AAPL, 25% GOOG, 50% NFLX



portfolio_growth_monthly_multi <- stock_returns_monthly_multi %>%
  tq_portfolio(assets_col   = symbol, 
               returns_col  = Ra, 
               weights      = weights_table, 
               col_rename   = "investment.growth",
               wealth.index = TRUE) %>%
  mutate(investment.growth = investment.growth * 1000)
portfolio_growth_monthly_multi %>%
  ggplot(aes(x = date, y = investment.growth, color = factor(portfolio))) +
  geom_line(size = 2) +
  labs(title = "Portfolio Growth",
       subtitle = "Comparing Multiple Portfolios",
       caption = "Portfolio 3 is a Standout!",
       x = "", y = "Portfolio Value",
       color = "Portfolio") +
  geom_smooth(method = "loess") +
  theme_tq() +
  scale_color_tq() +
  scale_y_continuous(labels = scales::dollar)
## Performance comparison between an undiversified vs diversified portfolio

stock_prices <- c("BIIB", "RDY", "GSK","PFE","JNJ","COST","PG","PEP","CL","BA","NOC","GD","HSBC","JPM","MS","WFC","AAPL","GOOG","NFLX","AMZN") %>%
  tq_get(get  = "stock.prices",
         from = "2010-01-01",
         to   = "2018-06-01")
#stock_prices

stock_returns_monthly <- stock_prices %>%
  group_by(symbol) %>%
  tq_transmute(select     = adjusted, 
               mutate_fun = periodReturn, 
               period     = "monthly", 
               col_rename = "Ra")
#stock_returns_monthly
# Using the transmutate function to just take the adjusted column of the stock price and compute each stock's monthly returns. We have essentially converted the daily return of each stock to an adjusted monthly return using the tq_transmutate function.
pharma_weights <- c(0.2,0.2,0.2,0.2,0.2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
equal_weights <- c(0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05)


## Here we are taking 2 different weights for the portfolio: The first one being only weighted for the pharma stocks and the other being an equal weighted portfolio. The objective of this is to show the difference in the sharpe ratios between an undiversified and a diversified portfolio.
portfolio_returns_monthly_pharma <- stock_returns_monthly %>%
  tq_portfolio(assets_col  = symbol, 
               returns_col = Ra, 
               weights     = pharma_weights,  
               col_rename  = "Ra") %>% mutate(date=substring(date,1,7)) %>%
  rename(Date=date)
#portfolio_returns_monthly
portfolio_returns_monthly_diverse <- stock_returns_monthly %>%
  tq_portfolio(assets_col  = symbol, 
               returns_col = Ra, 
               weights     = equal_weights,  
               col_rename  = "Ra") %>% mutate(date=substring(date,1,7)) %>%
  rename(Date=date)
#portfolio_returns_monthly

# We use tq_portfolio() to calculate weighted returns of our portfolio each month. It takes in the arguments of the weights and monthly portfolio returns to give an output of the monthly weighted returns. 
contra_fund<-read.csv("contrafund.csv") 
contra_fund$Date<-mdy(contra_fund$Date) 
contra_fund <- contra_fund %>% mutate(Date=substring(Date,1,7))
#Reading contrafund CSV for comparison and to get market and risk free data. Contrafund is a mutual fund operated by Fidelity investments with an AUM of over $112 Billion.


final_portfolio_pharma <- left_join(portfolio_returns_monthly_pharma, 
                                    contra_fund,
                                    by = "Date") %>% mutate(Date=paste(Date,"01",sep="-"))

final_portfolio_pharma$Date <- as.Date(as.character(final_portfolio_pharma$Date))


final_data_pharma <-xts(final_portfolio_pharma[,-1],final_portfolio_pharma$Date)
## Joining the final portfolio with contra fund and converting it to xts object as an input to compute ratios and to compare the ratios of the contrafund and our portfolio. 


sharperatio_contra <- SharpeRatio(final_data_pharma$ContraRet,final_data_pharma$Risk.Free)
sharperatio_pharma <-SharpeRatio(final_data_pharma$Ra,final_data_pharma$Risk.Free)


Return.cumulative(final_data_pharma, geometric =TRUE)
chart.CumReturns(final_data_pharma, wealth.index =FALSE, geometric = TRUE, legend.loc = "topleft")
final_portfolio_diverse <- left_join(portfolio_returns_monthly_diverse, 
                                     contra_fund,
                                     by = "Date") %>% mutate(Date=paste(Date,"01",sep="-"))

final_portfolio_diverse$Date <- as.Date(as.character(final_portfolio_diverse$Date))


final_data_diverse <-xts(final_portfolio_diverse[,-1],final_portfolio_diverse$Date)
## Joining the final portfolio with contra fund and converting it to xts object as an input to compute ratios and to compare the ratios of the contrafund and our portfolio. 
sharperatio_contra <- SharpeRatio(final_data_diverse$ContraRet,final_data_diverse$Risk.Free)
sharperatio_diverse <-SharpeRatio(final_data_diverse$Ra,final_data_diverse$Risk.Free)


Return.cumulative(final_data_diverse, geometric =TRUE)
chart.CumReturns(final_data_diverse, wealth.index =FALSE, geometric = TRUE, legend.loc = "topleft")
sharperatio_pharma<-SharpeRatio(final_data_pharma$Ra,final_data_pharma$Risk.Free)
sharperatio_pharma
sharperatio_diverse
sharperatio_contra
## As you can see, the sharpe ratio of the diversified portfolio of ContraFund is higher than that of the undiversified portfolio of the pharma stocks (0.343 vs 0.239). When we repeat the above steps using the equally weighted portfolio (by changing the argument of weights to equal_weights in the tq_portfolio() method), we find that the resulting sharpe ratio of the equally weighted portfolio is higher than both the ContraFund and the undiversified portfolio (0.42 vs 0.343 vs 0.29). This proves the fact that by diversifying the portfolio one can eliminate unsystematic risk and improve performance. 


## Comparing Treynor Ratios of both the portfolios
treynor_pharma <- TreynorRatio(final_data_pharma$Ra,final_data_pharma$Market.Return,final_data_pharma$Risk.Free)
treynor_pharma
treynor_diverse <- TreynorRatio(final_data_diverse$Ra,final_data_diverse$Market.Return,final_data_diverse$Risk.Free)
treynor_diverse
## Disadvantage of Treynor Ratio: It is backward-looking and that it relies on using a specific benchmark to measure beta. Most investments, though, don't necessarily perform the same way in the future that they did in the past.

## Comparing Treynor Ratios of both the portfolios

Pharma_Jensen_df<-transform(final_data_pharma,MktExcess=Market.Return-Risk.Free,FundExcess=Ra-Risk.Free)
Pharma_Jensen_df
Alpha_pharma=lm( Ra.1~ Market.Return.1,data=Pharma_Jensen_df)
summary(Alpha_pharma)

Diverse_Jensen_df<-transform(final_data_diverse,MktExcess=Market.Return-Risk.Free,FundExcess=Ra-Risk.Free)
Diverse_Jensen_df

Alpha_diverse=lm( Ra.1~Market.Return.1,data=Diverse_Jensen_df)
summary(Alpha_diverse)
## By comparison, even the Jensen's alpha is better for a diversified portfolio as compared to the undivesified portfolio
temp_pharma <- select(final_portfolio_pharma, Date, Ra) %>% rename(R_pharma = Ra)
temp_diverse <- select(final_portfolio_diverse, Date, Ra) %>% rename(R_diverse = Ra)


Comparison_df  <- inner_join(temp_pharma, temp_diverse, by = "Date")
## using ggplot as an alternative visualization tool
ggplot_demo <- Comparison_df %>% mutate(R_pharma=R_pharma+1,R_diverse=R_diverse+1)%>%mutate(Pharma_Cumul = cumprod(R_pharma),Diverse_cumul = cumprod(R_diverse)) %>% select(Date,Pharma_Cumul,Diverse_cumul)

ggplot(ggplot_demo, aes(x=Date))+geom_line(aes(y=Pharma_Cumul, color="Pharma"))+geom_line(aes(x=Date,y=Diverse_cumul,color="Diverse"))+ggtitle("Portfolio Cumulative Returns over Time")+xlab("Year")+ylab("Cumulative Returns") + scale_color_manual(breaks = c("Pharma", "Diverse"), values = c("blue", "black")) + labs(color = "Portfolio")
