--Which markets have the highest 1-bedroom rent?
SELECT * FROM HighRentMarkets
WHERE PropertyTypeName = '1-Bedroom Apartment';

--Markets where rents rose while vacancy also rose: possible affordability/supply inflection
--vw_RentalTrend
SELECT * FROM RentVacancyIncrease
ORDER BY AvgYoYRentGrowthPct;

--Renter cost burden by market and income band
--DimIncomeBand, DimMarket, FactHouseholdAffordability
SELECT * FROM RenterCostBurden
ORDER BY MarketName, SortOrder;

--Estimated monthly mortgage payment for a single-family home
--vw_HomeBuyingAffordability
SELECT * FROM MonthlyMortgagePayment
WHERE PropertyTypeName = 'Single-Family Home'
ORDER BY MarketName;

--Supply pipeline by market
--FactHousingSupply, DimMarket, DimMonth
SELECT * FROM MarketHousingSupply;

--Highest YoY increase in Rental Cost
SELECT * FROM RentalYearlyIncrease
ORDER BY YoYRentGrowthPct DESC;

--Eviction rates across markets
--FactEvictionStress, FactRentalMarket, DimMarket
SELECT * FROM MarketEvictionRates;

--Property Type being supplied the most in each market
SELECT * FROM MarketPropertySupply
ORDER BY TotalUnitsCompleted DESC;

--Property type that are not being sold/rented (cost) View
--FactHomeMarket, FactRentalMarket, DimPropertyType
SELECT * FROM SoldRentTrends
WHERE MonthKey = '202608' AND PropertyTypeName = '1-Bedroom Apartment';

--Eviction pressure trend
SELECT * FROM EvictionPressureTrend;

--Rank markets using the packaged stress score
SELECT * FROM RankedMarketStress;

--Which markets experienced the largest home-price growth since 2022?
SELECT TOP 5
	MarketName,
	PropertyTypeName,
	MIN(CASE WHEN MonthKey >= 202201 AND MonthKey <= 202212 THEN MedianSalePrice END) AS BasePrice2022,
	MAX(MedianSalePrice) AS LatestMedianSalePrice,
	CAST(
	    (MAX(MedianSalePrice) - MIN(CASE WHEN MonthKey >= 202201 AND MonthKey <= 202212 THEN MedianSalePrice END)) 
	    * 100.0 / NULLIF(MIN(CASE WHEN MonthKey >= 202201 AND MonthKey <= 202212 THEN MedianSalePrice END), 0)
	    AS DECIMAL(10, 2)) AS TotalGrowthSince2022Pct
FROM SoldRentTrends
JOIN DimMarket
	ON DimMarket.MarketID = SoldRentTrends.MarketID
GROUP BY MarketName, PropertyTypeName
ORDER BY TotalGrowthSince2022Pct DESC;

--Window-function exercise: 3-month moving average for 1BR rents for current year
SELECT *
FROM RentMovingAvgByPropertyType
WHERE PropertyTypeName = '1-Bedroom Apartment' AND MonthKey BETWEEN '202601' AND '202612'
ORDER BY MarketName, MonthKey;
