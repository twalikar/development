-- Creating Views
-- 1. High Rent Markets
CREATE VIEW HighRentMarkets AS
WITH RankedMarkets AS (
    SELECT 
        MonthKey,
        MarketName,
        PropertyTypeName,
        MedianAskingRent,
        VacancyRatePct,
        DENSE_RANK() OVER(
            PARTITION BY PropertyTypeName 
            ORDER BY MedianAskingRent DESC
        ) AS RentRank
    FROM FactRentalMarket
    INNER JOIN DimMarket
        ON DimMarket.MarketID = FactRentalMarket.MarketID
    INNER JOIN DimPropertyType
        ON DimPropertyType.PropertyTypeID = FactRentalMarket.PropertyTypeID
    WHERE MonthKey = (SELECT MAX(MonthKey) FROM FactRentalMarket)
)
SELECT 
    MonthKey,
    MarketName,
    PropertyTypeName,
    MedianAskingRent,
    VacancyRatePct,
    RentRank
FROM RankedMarkets;

--2. RentVacancyIncrease: Markets where rents rose while vacancy also rose
CREATE VIEW RentVacancyIncrease AS
WITH CurrentYear as (
	SELECT
		MarketName,
		AVG(YoYRentGrowthPct) as AvgYoYRentGrowthPct,
		AVG(VacancyRatePct) as AvgVacancyRatePct
	FROM vw_RentalTrend
	WHERE YearNumber = (SELECT MAX(YearNumber) FROM vw_RentalTrend)
	GROUP BY MarketName)
SELECT *
FROM CurrentYear;


--3. Renter cost burden by market and income band
--DimIncomeBand, DimMarket, FactHouseholdAffordability
CREATE VIEW RenterCostBurden AS(
SELECT 
	SortOrder,
	MarketName,
	IncomeBandName,
	MedianHouseholdIncome,
	MedianMonthlyHousingCost,
	HousingCostToIncomePct,
	CostBurdenedHouseholdsPct,
	SevereBurdenHouseholdsPct
FROM FactHouseholdAffordability
JOIN DimIncomeBand
	ON DimIncomeBand.IncomeBandID = FactHouseholdAffordability.IncomeBandID
JOIN DimMarket
	ON DimMarket.MarketID = FactHouseholdAffordability.MarketID
WHERE YearNumber = (SELECT MAX(YearNumber) FROM FactHouseholdAffordability) AND TenureID = 1);


--4. Estimated monthly mortgage payment for homes
--vw_HomeBuyingAffordability
CREATE VIEW MonthlyMortgagePayment AS(
SELECT 
	MonthStartDate,
	MarketName,
	PropertyTypeName,
	MedianSalePrice,
	MortgageRate30YrPct,
	EstimatedDownPayment20Pct,
	EstimatedLoanAmount,
	EstimatedMonthlyPrincipalInterest,
	PriceCutSharePct
FROM vw_HomeBuyingAffordability
WHERE  MonthKey = (SELECT MAX(MonthKey) FROM vw_HomeBuyingAffordability));


--5. Supply pipeline by market
--FactHousingSupply, DimMarket, DimMonth
CREATE VIEW MarketHousingSupply AS (
SELECT TOP 13
	MarketName,
	SUM(PermitsIssued) as PermitsIssued,
	SUM(UnitsStarted) as UnitsStarted,
	SUM(UnitsCompleted) as UnitsCompleted,
	SUM(UnitsUnderConstruction) as UnitsUnderConstruction
FROM FactHousingSupply
JOIN DimMarket
	ON DimMarket.MarketID = FactHousingSupply.MarketID
JOIN DimMonth
	ON DimMonth.MonthKey = FactHousingSupply.MonthKey
WHERE YearNumber = (SELECT MAX(YearNumber) FROM DimMonth)
GROUP BY MarketName
ORDER BY SUM(PermitsIssued) DESC);

--6. Highest YoY increase in Rental Cost
CREATE VIEW RentalYearlyIncrease AS(
SELECT
	MarketName,
	PropertyTypeName,
	AVG(MedianAskingRent) as MedianAskingRent,
	AVG(Rent12MonthsAgo) as Rent12MonthsAgo,
	AVG(YoYRentGrowthPct) as YoYRentGrowthPct
FROM vw_RentalTrend
WHERE MonthKey = (SELECT MAX(MonthKey) FROM vw_RentalTrend)
GROUP BY MarketName, PropertyTypeName);

--7. Eviction rates across markets
--FactEvictionStress, FactRentalMarket, DimMarket
CREATE VIEW MarketEvictionRates AS(
SELECT TOP 13
	MarketName,
	AVG(EstimatedRenterHouseholds) as EstimatedRenterHouseholds,
	AVG(EvictionFilings) as EvictionFilings,
	AVG(EvictionJudgments) as EvictionJudgments,
	AVG(FilingRatePer100Renters) as FilingRatePer100Renters,
	AVG(MedianAskingRent) as AvgRent,
	AVG(VacancyRatePct) as AvgVacancyRatePct
FROM FactEvictionStress
JOIN FactRentalMarket
	ON FactRentalMarket.MarketID = FactEvictionStress.MarketID
JOIN DimMarket
	On DimMarket.MarketID = FactEvictionStress.MarketID
WHERE FactEvictionStress.MonthKey = (SELECT MAX(MonthKey) FROM FactEvictionStress)
GROUP BY MarketName
ORDER BY SUM(FilingRatePer100Renters) DESC);


--9. Property Type being supplied the most in each market
CREATE VIEW MarketPropertySupply AS
WITH SupplyByMarketAndType AS (
    SELECT 
        MarketName,
        PropertyTypeName,
        COUNT(FactHousingSupply.PropertyTypeID) AS RecordCount,
        SUM(PermitsIssued) AS TotalPermitsIssued,
        SUM(UnitsStarted) AS TotalUnitsStarted,
        SUM(UnitsCompleted) AS TotalUnitsCompleted,
        SUM(UnitsUnderConstruction) AS TotalUnitsUnderConstruction,
        RANK() OVER (
            PARTITION BY MarketName 
            ORDER BY SUM(UnitsCompleted) DESC
        ) AS SupplyRank
    FROM FactHousingSupply
    JOIN DimMarket
        ON DimMarket.MarketID = FactHousingSupply.MarketID
    JOIN DimPropertyType
        ON DimPropertyType.PropertyTypeID = FactHousingSupply.PropertyTypeID
    GROUP BY MarketName, PropertyTypeName
)
SELECT 
    MarketName,
    PropertyTypeName,
    RecordCount,
    TotalPermitsIssued,
    TotalUnitsStarted,
    TotalUnitsCompleted,
    TotalUnitsUnderConstruction
FROM SupplyByMarketAndType
WHERE SupplyRank = 1;


--10. Property type that are not being sold/rented (cost) View
--FactHomeMarket, FactRentalMarket, DimPropertyType
CREATE VIEW SoldRentTrends AS
WITH HomeRentMarkets AS(
	SELECT
		COALESCE(FactRentalMarket.MarketID, FactHomeMarket.MarketId) as MarketID,
		COALESCE(FactRentalMarket.MonthKey, FactHomeMarket.MonthKey) as MonthKey,
		PropertyTypeName,
		MedianAskingRent,
		ActiveRentalListings,
		VacancyRatePct,
		AvgDaystoLease,
		MedianSalePrice,
		ActiveForSaleListings,
		HomesSold,
		MedianDaysOnMarket
	FROM FactRentalMarket
    FULL OUTER JOIN FactHomeMarket 
        ON FactRentalMarket.MarketID = FactHomeMarket.MarketID 
        AND FactRentalMarket.MonthKey = FactHomeMarket.MonthKey 
        AND FactRentalMarket.PropertyTypeID = FactHomeMarket.PropertyTypeID
    LEFT JOIN DimPropertyType 
        ON COALESCE(FactRentalMarket.PropertyTypeID, FactHomeMarket.PropertyTypeID) = DimPropertyType.PropertyTypeID
),
TrendCalculations AS (
    SELECT
        MarketID,
        MonthKey,
        PropertyTypeName,
        MedianAskingRent,
        MedianSalePrice,
        LAG(MedianAskingRent, 1) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey) AS PrevMonthAskingRent,
        (MedianAskingRent - LAG(MedianAskingRent, 1) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey)) AS RentChangeMoM,
        ((MedianAskingRent - LAG(MedianAskingRent, 1) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey)) / NULLIF(LAG(MedianAskingRent, 1) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey), 0)) * 100 AS RentPctChangeMoM,
        LAG(MedianAskingRent, 12) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey) AS PrevYearAskingRent,
        (MedianAskingRent - LAG(MedianAskingRent, 12) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey)) AS RentChangeYoY,
        ((MedianAskingRent - LAG(MedianAskingRent, 12) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey)) / NULLIF(LAG(MedianAskingRent, 12) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey), 0)) * 100 AS RentPctChangeYoY,
		LAG(MedianSalePrice, 1) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey) AS PrevMonthSalePrice,
        (MedianSalePrice - LAG(MedianSalePrice, 1) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey)) AS SalePriceChangeMoM,
        ((MedianSalePrice - LAG(MedianSalePrice, 1) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey)) / NULLIF(LAG(MedianSalePrice, 1) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey), 0)) * 100 AS SalePricePctChangeMoM,
        LAG(MedianSalePrice, 12) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey) AS PrevYearSalePrice,
        (MedianSalePrice - LAG(MedianSalePrice, 1) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey)) AS SalePriceChangeYoY,
        ((MedianSalePrice - LAG(MedianSalePrice, 1) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey)) / NULLIF(LAG(MedianSalePrice, 1) OVER (PARTITION BY MarketID, PropertyTypeName ORDER BY MonthKey), 0)) * 100 AS SalePricePctChangeYoY,
        ActiveRentalListings,
        VacancyRatePct,
        AvgDaysToLease,
        ActiveForSaleListings,
        HomesSold,
        MedianDaysOnMarket
    FROM HomeRentMarkets
)
SELECT * FROM TrendCalculations;

--11. Eviction pressure trend
CREATE VIEW EvictionPressureTrend AS
SELECT 
    MarketName,
    YearMonthLabel,
    EstimatedRenterHouseholds,
    EvictionFilings,
    EvictionJudgments,
    FilingRatePer100Renters,
	(FilingRatePer100Renters - LAG(FilingRatePer100Renters) OVER (ORDER BY YearMonthLabel)) / LAG(FilingRatePer100Renters) OVER (ORDER BY YearMonthLabel) as MoMFilingRateChange
FROM FactEvictionStress 
JOIN DimMarket ON FactEvictionStress.MarketID = DimMarket.MarketID
JOIN DimMonth ON FactEvictionStress.MonthKey = DimMonth.MonthKey;


--12. Rank markets using the packaged stress score
CREATE VIEW RankedMarketStress AS (
SELECT 
	RANK() OVER (ORDER BY MarketStressScore DESC) AS StressRank,
	MarketName,
	MAX(AvgRent) as AvgRent,
	MAX(AvgVacancyPct) as AvgVacancyPct,
	MAX(FilingRatePer100Renters) as FilingRatePer100Renters,
	MAX(WeightedBurdenPct) as WeightedBurdenPct,
	MAX(LatestPermits) as LatestPermits,
	MarketStressScore
FROM vw_MarketStressScore
GROUP BY MarketName, MarketStressScore);

--13. Window-function: 3-month moving average
CREATE VIEW RentMovingAvgByPropertyType AS
SELECT
    MarketName,
    PropertyTypeName,
    MonthKey,
    MedianAskingRent,
    AVG(MedianAskingRent) OVER (
        PARTITION BY MarketName, PropertyTypeName
        ORDER BY MonthKey
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS ThreeMonthMovingAvgRent
FROM FactRentalMarket
JOIN DimMarket
    ON DimMarket.MarketID = FactRentalMarket.MarketID
JOIN DimPropertyType
    ON DimPropertyType.PropertyTypeID = FactRentalMarket.PropertyTypeID;