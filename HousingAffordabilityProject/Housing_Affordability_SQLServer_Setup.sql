/*
    PROJECT: U.S. Housing Affordability & Rental Stress Analytics
    PLATFORM: Microsoft SQL Server

    PURPOSE
    -------
    Portfolio-grade SQL Server database for analyzing a real-world problem:
    housing affordability, rental stress, home-buying affordability, housing
    supply, mortgage-rate pressure, and eviction risk.

    IMPORTANT
    ---------
    The inserted fact data is SYNTHETIC but intentionally realistic and
    deterministic. It is designed for SQL/Data Analyst/Power BI/Tableau
    practice. It is NOT official market data.

    Coverage: Jan-2022 through Aug-2026
    Markets: 13 major U.S. metro markets
*/

USE master;
GO

IF DB_ID('HousingAffordabilityAnalytics') IS NULL
BEGIN
    EXEC('CREATE DATABASE HousingAffordabilityAnalytics');
END;
GO

USE HousingAffordabilityAnalytics;
GO

/*--------------------------------------------------------------
  0. DROP REPORTING VIEWS / TABLES SO SCRIPT IS RE-RUNNABLE
--------------------------------------------------------------*/
IF OBJECT_ID('dbo.vw_MarketStressScore', 'V') IS NOT NULL DROP VIEW dbo.vw_MarketStressScore;
IF OBJECT_ID('dbo.vw_HomeBuyingAffordability', 'V') IS NOT NULL DROP VIEW dbo.vw_HomeBuyingAffordability;
IF OBJECT_ID('dbo.vw_RentalTrend', 'V') IS NOT NULL DROP VIEW dbo.vw_RentalTrend;
GO

DROP TABLE IF EXISTS dbo.FactEvictionStress;
DROP TABLE IF EXISTS dbo.FactHousingSupply;
DROP TABLE IF EXISTS dbo.FactHouseholdAffordability;
DROP TABLE IF EXISTS dbo.FactHomeMarket;
DROP TABLE IF EXISTS dbo.FactRentalMarket;
DROP TABLE IF EXISTS dbo.FactMortgageRate;
DROP TABLE IF EXISTS dbo.DimTenure;
DROP TABLE IF EXISTS dbo.DimIncomeBand;
DROP TABLE IF EXISTS dbo.DimPropertyType;
DROP TABLE IF EXISTS dbo.DimMarket;
DROP TABLE IF EXISTS dbo.DimMonth;
GO

IF SCHEMA_ID('seed') IS NULL EXEC('CREATE SCHEMA seed');
GO
DROP TABLE IF EXISTS seed.MarketProfile;
GO

/*--------------------------------------------------------------
  1. DIMENSION / LOOKUP TABLES
--------------------------------------------------------------*/
CREATE TABLE dbo.DimMonth
(
    MonthKey        INT         NOT NULL PRIMARY KEY,   -- YYYYMM
    MonthStartDate  DATE        NOT NULL UNIQUE,
    YearNumber      SMALLINT    NOT NULL,
    QuarterNumber   TINYINT     NOT NULL,
    MonthNumber     TINYINT     NOT NULL,
    MonthName       VARCHAR(9)  NOT NULL,
    YearMonthLabel  CHAR(7)     NOT NULL               -- YYYY-MM
);
GO

CREATE TABLE dbo.DimMarket
(
    MarketID        INT          NOT NULL PRIMARY KEY,
    MarketName      VARCHAR(80)  NOT NULL UNIQUE,
    PrimaryCity     VARCHAR(50)  NOT NULL,
    StateCode       CHAR(2)      NOT NULL,
    StateName       VARCHAR(40)  NOT NULL,
    CensusRegion    VARCHAR(20)  NOT NULL,
    PopulationBand  VARCHAR(20)  NOT NULL,
    CoastalFlag     BIT          NOT NULL DEFAULT 0
);
GO

CREATE TABLE dbo.DimPropertyType
(
    PropertyTypeID      TINYINT      NOT NULL PRIMARY KEY,
    PropertyTypeName    VARCHAR(40)  NOT NULL UNIQUE,
    PropertyGroup       VARCHAR(20)  NOT NULL,
    BedroomCount        TINYINT      NULL,
    RentableFlag        BIT          NOT NULL,
    PurchasableFlag     BIT          NOT NULL
);
GO

CREATE TABLE dbo.DimIncomeBand
(
    IncomeBandID        TINYINT       NOT NULL PRIMARY KEY,
    IncomeBandName      VARCHAR(30)   NOT NULL UNIQUE,
    LowerIncome         INT           NULL,
    UpperIncome         INT           NULL,
    RepresentativeIncome INT          NOT NULL,
    SortOrder           TINYINT       NOT NULL,
    RenterSharePct      DECIMAL(5,2)  NOT NULL,
    OwnerSharePct       DECIMAL(5,2)  NOT NULL
);
GO

CREATE TABLE dbo.DimTenure
(
    TenureID        TINYINT      NOT NULL PRIMARY KEY,
    TenureName      VARCHAR(15)  NOT NULL UNIQUE
);
GO

/*--------------------------------------------------------------
  2. FACT TABLES
--------------------------------------------------------------*/
CREATE TABLE dbo.FactMortgageRate
(
    MortgageRateID      BIGINT IDENTITY(1,1) PRIMARY KEY,
    MonthKey            INT           NOT NULL,
    LoanTermYears       TINYINT       NOT NULL,
    AvgMortgageRatePct  DECIMAL(5,3)  NOT NULL,
    DataScenario        VARCHAR(20)   NOT NULL DEFAULT 'Synthetic',
    CONSTRAINT FK_MortgageRate_Month FOREIGN KEY (MonthKey)
        REFERENCES dbo.DimMonth(MonthKey),
    CONSTRAINT UQ_MortgageRate UNIQUE (MonthKey, LoanTermYears),
    CONSTRAINT CK_MortgageRate_Rate CHECK (AvgMortgageRatePct BETWEEN 0 AND 20)
);
GO

CREATE TABLE dbo.FactRentalMarket
(
    RentalMarketID          BIGINT IDENTITY(1,1) PRIMARY KEY,
    MonthKey                INT             NOT NULL,
    MarketID                INT             NOT NULL,
    PropertyTypeID          TINYINT         NOT NULL,
    MedianAskingRent        DECIMAL(12,2)   NOT NULL,
    ActiveRentalListings    INT             NOT NULL,
    VacancyRatePct          DECIMAL(5,2)    NOT NULL,
    AvgDaysToLease          SMALLINT        NOT NULL,
    NewLeaseConcessionPct   DECIMAL(5,2)    NOT NULL,
    DataScenario            VARCHAR(20)     NOT NULL DEFAULT 'Synthetic',
    CONSTRAINT FK_Rental_Month FOREIGN KEY (MonthKey) REFERENCES dbo.DimMonth(MonthKey),
    CONSTRAINT FK_Rental_Market FOREIGN KEY (MarketID) REFERENCES dbo.DimMarket(MarketID),
    CONSTRAINT FK_Rental_Property FOREIGN KEY (PropertyTypeID) REFERENCES dbo.DimPropertyType(PropertyTypeID),
    CONSTRAINT UQ_RentalMarket UNIQUE (MonthKey, MarketID, PropertyTypeID),
    CONSTRAINT CK_Rental_Vacancy CHECK (VacancyRatePct BETWEEN 0 AND 100)
);
GO

CREATE TABLE dbo.FactHomeMarket
(
    HomeMarketID            BIGINT IDENTITY(1,1) PRIMARY KEY,
    MonthKey                INT             NOT NULL,
    MarketID                INT             NOT NULL,
    PropertyTypeID          TINYINT         NOT NULL,
    MedianSalePrice         DECIMAL(14,2)   NOT NULL,
    ActiveForSaleListings   INT             NOT NULL,
    HomesSold               INT             NOT NULL,
    MedianDaysOnMarket      SMALLINT        NOT NULL,
    PriceCutSharePct        DECIMAL(5,2)    NOT NULL,
    SaleToListRatioPct      DECIMAL(6,2)    NOT NULL,
    DataScenario            VARCHAR(20)     NOT NULL DEFAULT 'Synthetic',
    CONSTRAINT FK_Home_Month FOREIGN KEY (MonthKey) REFERENCES dbo.DimMonth(MonthKey),
    CONSTRAINT FK_Home_Market FOREIGN KEY (MarketID) REFERENCES dbo.DimMarket(MarketID),
    CONSTRAINT FK_Home_Property FOREIGN KEY (PropertyTypeID) REFERENCES dbo.DimPropertyType(PropertyTypeID),
    CONSTRAINT UQ_HomeMarket UNIQUE (MonthKey, MarketID, PropertyTypeID)
);
GO

CREATE TABLE dbo.FactHouseholdAffordability
(
    AffordabilityID             BIGINT IDENTITY(1,1) PRIMARY KEY,
    YearNumber                  SMALLINT        NOT NULL,
    MarketID                    INT             NOT NULL,
    IncomeBandID                TINYINT         NOT NULL,
    TenureID                    TINYINT         NOT NULL,
    EstimatedHouseholds         INT             NOT NULL,
    MedianHouseholdIncome       DECIMAL(12,2)   NOT NULL,
    MedianMonthlyHousingCost    DECIMAL(10,2)   NOT NULL,
    HousingCostToIncomePct      DECIMAL(6,2)    NOT NULL,
    CostBurdenedHouseholdsPct   DECIMAL(5,2)    NOT NULL,
    SevereBurdenHouseholdsPct   DECIMAL(5,2)    NOT NULL,
    DataScenario                VARCHAR(20)     NOT NULL DEFAULT 'Synthetic',
    CONSTRAINT FK_Afford_Market FOREIGN KEY (MarketID) REFERENCES dbo.DimMarket(MarketID),
    CONSTRAINT FK_Afford_Income FOREIGN KEY (IncomeBandID) REFERENCES dbo.DimIncomeBand(IncomeBandID),
    CONSTRAINT FK_Afford_Tenure FOREIGN KEY (TenureID) REFERENCES dbo.DimTenure(TenureID),
    CONSTRAINT UQ_Affordability UNIQUE (YearNumber, MarketID, IncomeBandID, TenureID),
    CONSTRAINT CK_Afford_Burden CHECK
       (CostBurdenedHouseholdsPct BETWEEN 0 AND 100
        AND SevereBurdenHouseholdsPct BETWEEN 0 AND 100
        AND SevereBurdenHouseholdsPct <= CostBurdenedHouseholdsPct)
);
GO

CREATE TABLE dbo.FactHousingSupply
(
    HousingSupplyID         BIGINT IDENTITY(1,1) PRIMARY KEY,
    MonthKey                INT             NOT NULL,
    MarketID                INT             NOT NULL,
    PropertyTypeID          TINYINT         NOT NULL,
    PermitsIssued           INT             NOT NULL,
    UnitsStarted            INT             NOT NULL,
    UnitsCompleted          INT             NOT NULL,
    UnitsUnderConstruction  INT             NOT NULL,
    DataScenario            VARCHAR(20)     NOT NULL DEFAULT 'Synthetic',
    CONSTRAINT FK_Supply_Month FOREIGN KEY (MonthKey) REFERENCES dbo.DimMonth(MonthKey),
    CONSTRAINT FK_Supply_Market FOREIGN KEY (MarketID) REFERENCES dbo.DimMarket(MarketID),
    CONSTRAINT FK_Supply_Property FOREIGN KEY (PropertyTypeID) REFERENCES dbo.DimPropertyType(PropertyTypeID),
    CONSTRAINT UQ_HousingSupply UNIQUE (MonthKey, MarketID, PropertyTypeID)
);
GO

CREATE TABLE dbo.FactEvictionStress
(
    EvictionStressID        BIGINT IDENTITY(1,1) PRIMARY KEY,
    MonthKey                INT             NOT NULL,
    MarketID                INT             NOT NULL,
    EstimatedRenterHouseholds INT           NOT NULL,
    EvictionFilings         INT             NOT NULL,
    EvictionJudgments       INT             NOT NULL,
    FilingRatePer100Renters DECIMAL(7,3)    NOT NULL,
    DataScenario            VARCHAR(20)     NOT NULL DEFAULT 'Synthetic',
    CONSTRAINT FK_Eviction_Month FOREIGN KEY (MonthKey) REFERENCES dbo.DimMonth(MonthKey),
    CONSTRAINT FK_Eviction_Market FOREIGN KEY (MarketID) REFERENCES dbo.DimMarket(MarketID),
    CONSTRAINT UQ_EvictionStress UNIQUE (MonthKey, MarketID)
);
GO

/*--------------------------------------------------------------
  3. INDEXES FOR COMMON ANALYST QUERIES
--------------------------------------------------------------*/
CREATE INDEX IX_Rental_MarketMonth ON dbo.FactRentalMarket(MarketID, MonthKey)
    INCLUDE (MedianAskingRent, VacancyRatePct, ActiveRentalListings);
CREATE INDEX IX_Home_MarketMonth ON dbo.FactHomeMarket(MarketID, MonthKey)
    INCLUDE (MedianSalePrice, HomesSold, MedianDaysOnMarket, PriceCutSharePct);
CREATE INDEX IX_Afford_MarketYear ON dbo.FactHouseholdAffordability(MarketID, YearNumber)
    INCLUDE (IncomeBandID, TenureID, HousingCostToIncomePct, CostBurdenedHouseholdsPct);
CREATE INDEX IX_Supply_MarketMonth ON dbo.FactHousingSupply(MarketID, MonthKey)
    INCLUDE (PermitsIssued, UnitsCompleted, UnitsUnderConstruction);
CREATE INDEX IX_Eviction_MarketMonth ON dbo.FactEvictionStress(MarketID, MonthKey)
    INCLUDE (EvictionFilings, FilingRatePer100Renters);
GO

/*--------------------------------------------------------------
  4. INSERT LOOKUP VALUES
--------------------------------------------------------------*/
INSERT INTO dbo.DimMarket
    (MarketID, MarketName, PrimaryCity, StateCode, StateName, CensusRegion, PopulationBand, CoastalFlag)
VALUES
(1,  'New York Metro',       'New York',      'NY', 'New York',            'Northeast', '10M+', 1),
(2,  'Los Angeles Metro',    'Los Angeles',   'CA', 'California',          'West',      '10M+', 1),
(3,  'San Francisco Metro',  'San Francisco', 'CA', 'California',          'West',      '3M-10M',1),
(4,  'Seattle Metro',        'Seattle',       'WA', 'Washington',          'West',      '3M-10M',1),
(5,  'Washington DC Metro',  'Washington',    'DC', 'District of Columbia','South',     '3M-10M',1),
(6,  'Boston Metro',         'Boston',        'MA', 'Massachusetts',       'Northeast', '3M-10M',1),
(7,  'Miami Metro',          'Miami',         'FL', 'Florida',             'South',     '3M-10M',1),
(8,  'Austin Metro',         'Austin',        'TX', 'Texas',               'South',     '1M-3M', 0),
(9,  'Dallas-Fort Worth',    'Dallas',        'TX', 'Texas',               'South',     '3M-10M',0),
(10, 'Atlanta Metro',        'Atlanta',       'GA', 'Georgia',             'South',     '3M-10M',0),
(11, 'Chicago Metro',        'Chicago',       'IL', 'Illinois',            'Midwest',   '3M-10M',1),
(12, 'Phoenix Metro',        'Phoenix',       'AZ', 'Arizona',             'West',      '3M-10M',0),
(13, 'Denver Metro',         'Denver',        'CO', 'Colorado',            'West',      '1M-3M', 0);
GO

INSERT INTO dbo.DimPropertyType
    (PropertyTypeID, PropertyTypeName, PropertyGroup, BedroomCount, RentableFlag, PurchasableFlag)
VALUES
(1, 'Studio Apartment',  'Apartment',     0, 1, 0),
(2, '1-Bedroom Apartment','Apartment',    1, 1, 0),
(3, '2-Bedroom Apartment','Apartment',    2, 1, 0),
(4, '3-Bedroom Apartment','Apartment',    3, 1, 0),
(5, 'Condo/Townhome',    'Attached Home', NULL, 1, 1),
(6, 'Single-Family Home','Detached Home', NULL, 1, 1);
GO

INSERT INTO dbo.DimIncomeBand
    (IncomeBandID, IncomeBandName, LowerIncome, UpperIncome, RepresentativeIncome, SortOrder, RenterSharePct, OwnerSharePct)
VALUES
(1, 'Under $30K',     NULL,   29999,  22500, 1, 24.00,  8.00),
(2, '$30K-$49K',      30000,  49999,  40000, 2, 22.00, 12.00),
(3, '$50K-$74K',      50000,  74999,  62500, 3, 21.00, 18.00),
(4, '$75K-$99K',      75000,  99999,  87500, 4, 14.00, 18.00),
(5, '$100K-$149K',   100000, 149999, 125000, 5, 12.00, 24.00),
(6, '$150K+',        150000, NULL,   185000, 6,  7.00, 20.00);
GO

INSERT INTO dbo.DimTenure (TenureID, TenureName)
VALUES (1, 'Renter'), (2, 'Owner');
GO

/* Month dimension: 2022-01 through 2026-08 */
DECLARE @MonthDate DATE = '2022-01-01';
WHILE @MonthDate <= '2026-08-01'
BEGIN
    INSERT INTO dbo.DimMonth
        (MonthKey, MonthStartDate, YearNumber, QuarterNumber, MonthNumber, MonthName, YearMonthLabel)
    VALUES
        (YEAR(@MonthDate) * 100 + MONTH(@MonthDate),
         @MonthDate,
         YEAR(@MonthDate),
         DATEPART(QUARTER, @MonthDate),
         MONTH(@MonthDate),
         DATENAME(MONTH, @MonthDate),
         CONVERT(CHAR(7), @MonthDate, 126));

    SET @MonthDate = DATEADD(MONTH, 1, @MonthDate);
END;
GO

/*--------------------------------------------------------------
  5. DATA-GENERATION SEED PROFILE
  This table supports deterministic portfolio data generation.
  Do not import this table into the BI semantic model.
--------------------------------------------------------------*/
CREATE TABLE seed.MarketProfile
(
    MarketID                INT PRIMARY KEY,
    BaseMonthlyRent1BR      DECIMAL(10,2) NOT NULL,
    BaseHomePriceSF         DECIMAL(12,2) NOT NULL,
    BaseMedianIncome        DECIMAL(10,2) NOT NULL,
    BaseRenterHouseholds    INT NOT NULL,
    BaseOwnerHouseholds     INT NOT NULL,
    BaseVacancyPct          DECIMAL(5,2) NOT NULL,
    AnnualRentGrowth        DECIMAL(6,4) NOT NULL,
    AnnualHomePriceGrowth   DECIMAL(6,4) NOT NULL,
    SupplyIntensity         DECIMAL(6,3) NOT NULL,
    EvictionRiskFactor      DECIMAL(6,3) NOT NULL,
    CONSTRAINT FK_Seed_Market FOREIGN KEY (MarketID) REFERENCES dbo.DimMarket(MarketID)
);
GO

INSERT INTO seed.MarketProfile
(MarketID, BaseMonthlyRent1BR, BaseHomePriceSF, BaseMedianIncome,
 BaseRenterHouseholds, BaseOwnerHouseholds, BaseVacancyPct,
 AnnualRentGrowth, AnnualHomePriceGrowth, SupplyIntensity, EvictionRiskFactor)
VALUES
(1,  2900,  720000,  82000, 3400000, 3600000, 3.6, 0.040, 0.045, 0.75, 1.10),
(2,  2400,  900000,  78000, 2200000, 2800000, 4.2, 0.045, 0.050, 0.70, 1.05),
(3,  2850, 1250000, 105000,  850000, 1200000, 5.0, 0.025, 0.035, 0.60, 0.70),
(4,  2100,  760000,  98000,  720000, 1000000, 5.2, 0.030, 0.040, 0.90, 0.65),
(5,  2250,  610000, 102000, 1000000, 1500000, 4.4, 0.038, 0.042, 0.80, 0.75),
(6,  2700,  700000, 100000,  820000, 1200000, 3.9, 0.050, 0.050, 0.65, 0.70),
(7,  2250,  520000,  70000,  900000, 1300000, 5.4, 0.060, 0.060, 0.85, 1.25),
(8,  1550,  500000,  86000,  430000,  550000, 7.4, 0.015, 0.030, 1.55, 0.80),
(9,  1500,  410000,  78000,  900000, 1400000, 6.5, 0.025, 0.035, 1.45, 0.95),
(10, 1580,  390000,  76000,  800000, 1200000, 6.1, 0.035, 0.040, 1.20, 1.20),
(11, 1750,  340000,  76000, 1400000, 1900000, 5.1, 0.030, 0.035, 0.65, 1.00),
(12, 1550,  465000,  73000,  650000,  950000, 6.8, 0.020, 0.030, 1.25, 1.05),
(13, 1850,  620000,  92000,  520000,  820000, 6.0, 0.028, 0.035, 1.00, 0.65);
GO

/*--------------------------------------------------------------
  6. GENERATE MONTHLY MORTGAGE RATE DATA
  Synthetic benchmark shaped like the 2022-2026 rate environment.
--------------------------------------------------------------*/
INSERT INTO dbo.FactMortgageRate (MonthKey, LoanTermYears, AvgMortgageRatePct)
SELECT
    m.MonthKey,
    t.LoanTermYears,
    CAST(
        CASE
            WHEN m.YearNumber = 2022 THEN
                (3.35 + (m.MonthNumber - 1) * 0.29)
            WHEN m.YearNumber = 2023 THEN
                (6.25 + (m.MonthNumber - 1) * 0.105 +
                 CASE WHEN m.MonthNumber IN (4,5,8) THEN -0.18 ELSE 0 END)
            WHEN m.YearNumber = 2024 THEN
                (6.95 - (m.MonthNumber - 1) * 0.045 +
                 CASE WHEN m.MonthNumber IN (4,5) THEN 0.25 ELSE 0 END)
            WHEN m.YearNumber = 2025 THEN
                (6.55 - (m.MonthNumber - 1) * 0.035 +
                 CASE WHEN m.MonthNumber IN (2,3) THEN 0.12 ELSE 0 END)
            ELSE
                (6.05 - (m.MonthNumber - 1) * 0.035)
        END
        - CASE WHEN t.LoanTermYears = 15 THEN 0.65 ELSE 0 END
    AS DECIMAL(5,3))
FROM dbo.DimMonth m
CROSS JOIN (VALUES (30),(15)) t(LoanTermYears);
GO

/*--------------------------------------------------------------
  7. GENERATE RENTAL MARKET DATA
--------------------------------------------------------------*/
INSERT INTO dbo.FactRentalMarket
(
    MonthKey, MarketID, PropertyTypeID, MedianAskingRent,
    ActiveRentalListings, VacancyRatePct, AvgDaysToLease,
    NewLeaseConcessionPct
)
SELECT
    m.MonthKey,
    s.MarketID,
    p.PropertyTypeID,
    CAST(s.BaseMonthlyRent1BR
         * pf.RentFactor
         * POWER(1.0 + s.AnnualRentGrowth,
                 DATEDIFF(MONTH, '2022-01-01', m.MonthStartDate) / 12.0)
         * cyc.RentCycleFactor
         * season.SeasonFactor
         * noise.NoiseFactor
      AS DECIMAL(12,2)) AS MedianAskingRent,
    CAST(s.BaseRenterHouseholds
         * (vac.VacancyRate / 100.0)
         * pf.ListingShare
      AS INT) AS ActiveRentalListings,
    CAST(vac.VacancyRate AS DECIMAL(5,2)) AS VacancyRatePct,
    CAST(12 + vac.VacancyRate * 2.2 + noise.NoiseInt AS SMALLINT) AS AvgDaysToLease,
    CAST(
       CASE WHEN vac.VacancyRate < 4.0 THEN 4.0
            ELSE 4.0 + (vac.VacancyRate - 4.0) * 3.5 END
      AS DECIMAL(5,2)) AS NewLeaseConcessionPct
FROM dbo.DimMonth m
CROSS JOIN seed.MarketProfile s
JOIN dbo.DimPropertyType p ON p.RentableFlag = 1
CROSS APPLY
(
    SELECT CASE p.PropertyTypeID
        WHEN 1 THEN 0.78 WHEN 2 THEN 1.00 WHEN 3 THEN 1.28
        WHEN 4 THEN 1.58 WHEN 5 THEN 1.42 WHEN 6 THEN 1.90 END,
        CASE p.PropertyTypeID
        WHEN 1 THEN 0.14 WHEN 2 THEN 0.25 WHEN 3 THEN 0.27
        WHEN 4 THEN 0.13 WHEN 5 THEN 0.10 WHEN 6 THEN 0.11 END
) pf(RentFactor, ListingShare)
CROSS APPLY
(
    SELECT CASE
        WHEN m.YearNumber = 2022 THEN 1.045
        WHEN m.YearNumber = 2023 THEN 1.025
        WHEN m.YearNumber = 2024 THEN 1.005
        WHEN m.YearNumber = 2025 THEN 0.995
        ELSE 0.992 END
) cyc(RentCycleFactor)
CROSS APPLY
(
    SELECT CASE
        WHEN m.MonthNumber IN (5,6,7,8) THEN 1.018
        WHEN m.MonthNumber IN (12,1,2) THEN 0.988
        ELSE 1.000 END
) season(SeasonFactor)
CROSS APPLY
(
    SELECT
        0.975 + ((ABS(CHECKSUM(CONCAT(m.MonthKey, '-', s.MarketID, '-', p.PropertyTypeID))) % 51) / 1000.0),
        (ABS(CHECKSUM(CONCAT('D-', m.MonthKey, '-', s.MarketID, '-', p.PropertyTypeID))) % 7)
) noise(NoiseFactor, NoiseInt)
CROSS APPLY
(
    SELECT
        CASE
            WHEN s.BaseVacancyPct
                 + CASE WHEN m.YearNumber >= 2025 THEN 0.7 ELSE 0 END
                 + ((ABS(CHECKSUM(CONCAT('V-',m.MonthKey,'-',s.MarketID))) % 15) - 7) / 10.0 < 2.0
            THEN 2.0
            WHEN s.BaseVacancyPct
                 + CASE WHEN m.YearNumber >= 2025 THEN 0.7 ELSE 0 END
                 + ((ABS(CHECKSUM(CONCAT('V-',m.MonthKey,'-',s.MarketID))) % 15) - 7) / 10.0 > 10.0
            THEN 10.0
            ELSE s.BaseVacancyPct
                 + CASE WHEN m.YearNumber >= 2025 THEN 0.7 ELSE 0 END
                 + ((ABS(CHECKSUM(CONCAT('V-',m.MonthKey,'-',s.MarketID))) % 15) - 7) / 10.0
        END
) vac(VacancyRate);
GO

/*--------------------------------------------------------------
  8. GENERATE FOR-SALE HOME MARKET DATA
--------------------------------------------------------------*/
INSERT INTO dbo.FactHomeMarket
(
    MonthKey, MarketID, PropertyTypeID, MedianSalePrice,
    ActiveForSaleListings, HomesSold, MedianDaysOnMarket,
    PriceCutSharePct, SaleToListRatioPct
)
SELECT
    m.MonthKey,
    s.MarketID,
    p.PropertyTypeID,
    CAST(s.BaseHomePriceSF
         * pf.PriceFactor
         * POWER(1.0 + s.AnnualHomePriceGrowth,
                 DATEDIFF(MONTH, '2022-01-01', m.MonthStartDate) / 12.0)
         * cyc.PriceCycleFactor
         * noise.PriceNoise
      AS DECIMAL(14,2)) AS MedianSalePrice,
    CAST(s.BaseOwnerHouseholds * 0.0105 * pf.InventoryShare
         * cyc.InventoryFactor * season.InventorySeason
      AS INT) AS ActiveForSaleListings,
    CAST(s.BaseOwnerHouseholds * 0.0038 * pf.InventoryShare
         * season.SalesSeason
         * cyc.SalesFactor
      AS INT) AS HomesSold,
    CAST(18 + ((rate30.AvgMortgageRatePct - 3.0) * 5.5)
         + noise.DayNoise
      AS SMALLINT) AS MedianDaysOnMarket,
    CAST(
       CASE WHEN 8.0 + (rate30.AvgMortgageRatePct - 3.0) * 3.4 + noise.CutNoise > 38
            THEN 38
            ELSE 8.0 + (rate30.AvgMortgageRatePct - 3.0) * 3.4 + noise.CutNoise END
      AS DECIMAL(5,2)) AS PriceCutSharePct,
    CAST(101.5 - (rate30.AvgMortgageRatePct - 3.0) * 0.65 - noise.RatioNoise
      AS DECIMAL(6,2)) AS SaleToListRatioPct
FROM dbo.DimMonth m
CROSS JOIN seed.MarketProfile s
JOIN dbo.DimPropertyType p ON p.PurchasableFlag = 1
JOIN dbo.FactMortgageRate rate30
  ON rate30.MonthKey = m.MonthKey AND rate30.LoanTermYears = 30
CROSS APPLY
(
    SELECT CASE p.PropertyTypeID WHEN 5 THEN 0.68 ELSE 1.00 END,
           CASE p.PropertyTypeID WHEN 5 THEN 0.38 ELSE 0.62 END
) pf(PriceFactor, InventoryShare)
CROSS APPLY
(
    SELECT
      CASE
        WHEN m.YearNumber = 2022 THEN 1.050
        WHEN m.YearNumber = 2023 THEN 0.990
        WHEN m.YearNumber = 2024 THEN 1.010
        WHEN m.YearNumber = 2025 THEN 1.005
        ELSE 1.000 END,
      CASE
        WHEN m.YearNumber = 2022 THEN 0.72
        WHEN m.YearNumber = 2023 THEN 1.05
        WHEN m.YearNumber = 2024 THEN 1.15
        WHEN m.YearNumber = 2025 THEN 1.28
        ELSE 1.35 END,
      CASE
        WHEN m.YearNumber = 2022 THEN 1.14
        WHEN m.YearNumber = 2023 THEN 0.82
        WHEN m.YearNumber = 2024 THEN 0.88
        WHEN m.YearNumber = 2025 THEN 0.91
        ELSE 0.94 END
) cyc(PriceCycleFactor, InventoryFactor, SalesFactor)
CROSS APPLY
(
    SELECT
      CASE WHEN m.MonthNumber IN (3,4,5,6,7) THEN 1.18 ELSE 0.90 END,
      CASE WHEN m.MonthNumber IN (4,5,6,7,8) THEN 1.22 ELSE 0.88 END
) season(InventorySeason, SalesSeason)
CROSS APPLY
(
    SELECT
      0.985 + ((ABS(CHECKSUM(CONCAT('P-',m.MonthKey,'-',s.MarketID,'-',p.PropertyTypeID))) % 31) / 1000.0),
      ABS(CHECKSUM(CONCAT('DM-',m.MonthKey,'-',s.MarketID,'-',p.PropertyTypeID))) % 8,
      (ABS(CHECKSUM(CONCAT('PC-',m.MonthKey,'-',s.MarketID,'-',p.PropertyTypeID))) % 25) / 10.0,
      (ABS(CHECKSUM(CONCAT('RL-',m.MonthKey,'-',s.MarketID,'-',p.PropertyTypeID))) % 16) / 10.0
) noise(PriceNoise, DayNoise, CutNoise, RatioNoise);
GO

/*--------------------------------------------------------------
  9. GENERATE HOUSING SUPPLY / CONSTRUCTION DATA
--------------------------------------------------------------*/
INSERT INTO dbo.FactHousingSupply
(
    MonthKey, MarketID, PropertyTypeID, PermitsIssued,
    UnitsStarted, UnitsCompleted, UnitsUnderConstruction
)
SELECT
    m.MonthKey,
    s.MarketID,
    p.PropertyTypeID,
    v.PermitsIssued,
    CAST(v.PermitsIssued * (0.84 + noise.StartNoise) AS INT),
    CAST(v.PermitsIssued * (0.66 + noise.CompletionNoise) AS INT),
    CAST(v.PermitsIssued * (7.0 + noise.UCNoise) AS INT)
FROM dbo.DimMonth m
CROSS JOIN seed.MarketProfile s
CROSS JOIN dbo.DimPropertyType p
CROSS APPLY
(
    SELECT CASE p.PropertyTypeID
       WHEN 1 THEN 0.05 WHEN 2 THEN 0.14 WHEN 3 THEN 0.18
       WHEN 4 THEN 0.10 WHEN 5 THEN 0.18 WHEN 6 THEN 0.35 END
) w(TypeWeight)
CROSS APPLY
(
    SELECT
       (ABS(CHECKSUM(CONCAT('S-',m.MonthKey,'-',s.MarketID,'-',p.PropertyTypeID))) % 31) / 100.0,
       (ABS(CHECKSUM(CONCAT('C-',m.MonthKey,'-',s.MarketID,'-',p.PropertyTypeID))) % 29) / 100.0,
       (ABS(CHECKSUM(CONCAT('U-',m.MonthKey,'-',s.MarketID,'-',p.PropertyTypeID))) % 41) / 10.0
) noise(StartNoise, CompletionNoise, UCNoise)
CROSS APPLY
(
    SELECT CAST(
       ((s.BaseRenterHouseholds + s.BaseOwnerHouseholds) / 1000.0)
       * s.SupplyIntensity
       * w.TypeWeight
       * CASE WHEN m.YearNumber IN (2022,2023) THEN 1.10
              WHEN m.YearNumber = 2024 THEN 1.00
              WHEN m.YearNumber = 2025 THEN 0.90
              ELSE 0.86 END
       * CASE WHEN m.MonthNumber IN (3,4,5,6,7,8,9) THEN 1.12 ELSE 0.88 END
       * (0.90 + ((ABS(CHECKSUM(CONCAT('PERM-',m.MonthKey,'-',s.MarketID,'-',p.PropertyTypeID))) % 21) / 100.0))
     AS INT)
) v(PermitsIssued);
GO

/*--------------------------------------------------------------
  10. GENERATE EVICTION STRESS DATA
--------------------------------------------------------------*/
INSERT INTO dbo.FactEvictionStress
(
    MonthKey, MarketID, EstimatedRenterHouseholds,
    EvictionFilings, EvictionJudgments, FilingRatePer100Renters
)
SELECT
    m.MonthKey,
    s.MarketID,
    CAST(s.BaseRenterHouseholds
         * POWER(1.008, DATEDIFF(MONTH, '2022-01-01', m.MonthStartDate) / 12.0)
      AS INT) AS EstimatedRenterHouseholds,
    v.Filings,
    CAST(v.Filings * (0.34 + noise.JudgmentNoise) AS INT) AS EvictionJudgments,
    CAST(v.Filings * 100.0 /
         NULLIF(s.BaseRenterHouseholds
           * POWER(1.008, DATEDIFF(MONTH, '2022-01-01', m.MonthStartDate) / 12.0),0)
      AS DECIMAL(7,3)) AS FilingRatePer100Renters
FROM dbo.DimMonth m
CROSS JOIN seed.MarketProfile s
CROSS APPLY
(
    SELECT
       (ABS(CHECKSUM(CONCAT('EJ-',m.MonthKey,'-',s.MarketID))) % 18) / 100.0,
       0.88 + (ABS(CHECKSUM(CONCAT('EF-',m.MonthKey,'-',s.MarketID))) % 25) / 100.0
) noise(JudgmentNoise, FilingNoise)
CROSS APPLY
(
    SELECT CAST(
       s.BaseRenterHouseholds * 0.00215
       * s.EvictionRiskFactor
       * noise.FilingNoise
       * CASE WHEN m.MonthNumber IN (1,2,8,9) THEN 1.12 ELSE 1.00 END
       * CASE WHEN m.YearNumber >= 2025 THEN 1.04 ELSE 1.00 END
      AS INT)
) v(Filings);
GO

/*--------------------------------------------------------------
  11. GENERATE ANNUAL HOUSEHOLD AFFORDABILITY DATA
--------------------------------------------------------------*/
;WITH Years AS
(
    SELECT DISTINCT YearNumber
    FROM dbo.DimMonth
), Base AS
(
    SELECT
        y.YearNumber,
        s.MarketID,
        i.IncomeBandID,
        t.TenureID,
        i.RepresentativeIncome,
        i.RenterSharePct,
        i.OwnerSharePct,
        s.BaseRenterHouseholds,
        s.BaseOwnerHouseholds,
        s.BaseMonthlyRent1BR,
        s.BaseHomePriceSF,
        s.AnnualRentGrowth,
        s.AnnualHomePriceGrowth
    FROM Years y
    CROSS JOIN seed.MarketProfile s
    CROSS JOIN dbo.DimIncomeBand i
    CROSS JOIN dbo.DimTenure t
), Costs AS
(
    SELECT
        b.*,
        CAST(b.RepresentativeIncome * POWER(1.035, b.YearNumber - 2022) AS DECIMAL(12,2)) AS MedianIncome,
        CAST(CASE WHEN b.TenureID = 1
            THEN b.BaseMonthlyRent1BR
                 * 1.10
                 * POWER(1.0 + b.AnnualRentGrowth, b.YearNumber - 2022)
            ELSE b.BaseHomePriceSF
                 * POWER(1.0 + b.AnnualHomePriceGrowth, b.YearNumber - 2022)
                 * (0.00535 + ((b.YearNumber - 2022) * 0.00018))
        END AS DECIMAL(10,2)) AS MonthlyHousingCost,
        CAST(CASE WHEN b.TenureID = 1
            THEN b.BaseRenterHouseholds * (b.RenterSharePct / 100.0)
            ELSE b.BaseOwnerHouseholds * (b.OwnerSharePct / 100.0)
        END * POWER(1.008, b.YearNumber - 2022) AS INT) AS EstimatedHH
    FROM Base b
), Ratios AS
(
    SELECT *,
           MonthlyHousingCost / NULLIF(MedianIncome / 12.0, 0) AS CostRatio
    FROM Costs
), Burden AS
(
    SELECT *,
       CASE
          WHEN 10 + (CostRatio - 0.20) * 150 < 4 THEN 4.0
          WHEN 10 + (CostRatio - 0.20) * 150 > 95 THEN 95.0
          ELSE 10 + (CostRatio - 0.20) * 150
       END AS BurdenPct,
       CASE
          WHEN 3 + (CostRatio - 0.38) * 135 < 1 THEN 1.0
          WHEN 3 + (CostRatio - 0.38) * 135 > 82 THEN 82.0
          ELSE 3 + (CostRatio - 0.38) * 135
       END AS SeverePctRaw
    FROM Ratios
)
INSERT INTO dbo.FactHouseholdAffordability
(
    YearNumber, MarketID, IncomeBandID, TenureID,
    EstimatedHouseholds, MedianHouseholdIncome, MedianMonthlyHousingCost,
    HousingCostToIncomePct, CostBurdenedHouseholdsPct, SevereBurdenHouseholdsPct
)
SELECT
    YearNumber,
    MarketID,
    IncomeBandID,
    TenureID,
    EstimatedHH,
    MedianIncome,
    MonthlyHousingCost,
    CAST(CostRatio * 100.0 AS DECIMAL(6,2)),
    CAST(BurdenPct AS DECIMAL(5,2)),
    CAST(CASE WHEN SeverePctRaw > BurdenPct - 2 THEN BurdenPct - 2 ELSE SeverePctRaw END AS DECIMAL(5,2))
FROM Burden;
GO

/*--------------------------------------------------------------
  12. REPORTING VIEWS
--------------------------------------------------------------*/
CREATE VIEW dbo.vw_RentalTrend
AS
SELECT
    r.MonthKey,
    m.MonthStartDate,
    m.YearNumber,
    dm.MarketID,
    dm.MarketName,
    dm.CensusRegion,
    p.PropertyTypeName,
    r.MedianAskingRent,
    r.VacancyRatePct,
    r.ActiveRentalListings,
    r.AvgDaysToLease,
    r.NewLeaseConcessionPct,
    LAG(r.MedianAskingRent, 12) OVER
       (PARTITION BY r.MarketID, r.PropertyTypeID ORDER BY r.MonthKey) AS Rent12MonthsAgo,
    CAST(100.0 * (r.MedianAskingRent - LAG(r.MedianAskingRent, 12) OVER
       (PARTITION BY r.MarketID, r.PropertyTypeID ORDER BY r.MonthKey)) /
       NULLIF(LAG(r.MedianAskingRent, 12) OVER
       (PARTITION BY r.MarketID, r.PropertyTypeID ORDER BY r.MonthKey),0)
       AS DECIMAL(8,2)) AS YoYRentGrowthPct
FROM dbo.FactRentalMarket r
JOIN dbo.DimMonth m ON m.MonthKey = r.MonthKey
JOIN dbo.DimMarket dm ON dm.MarketID = r.MarketID
JOIN dbo.DimPropertyType p ON p.PropertyTypeID = r.PropertyTypeID;
GO

CREATE VIEW dbo.vw_HomeBuyingAffordability
AS
SELECT
    h.MonthKey,
    mo.MonthStartDate,
    mk.MarketID,
    mk.MarketName,
    pt.PropertyTypeName,
    h.MedianSalePrice,
    mr.AvgMortgageRatePct AS MortgageRate30YrPct,
    CAST(h.MedianSalePrice * 0.20 AS DECIMAL(14,2)) AS EstimatedDownPayment20Pct,
    CAST(h.MedianSalePrice * 0.80 AS DECIMAL(14,2)) AS EstimatedLoanAmount,
    CAST(
      (h.MedianSalePrice * 0.80) *
      ((mr.AvgMortgageRatePct / 100.0) / 12.0) *
      POWER(1.0 + ((mr.AvgMortgageRatePct / 100.0) / 12.0), 360) /
      NULLIF(POWER(1.0 + ((mr.AvgMortgageRatePct / 100.0) / 12.0), 360) - 1.0, 0)
      AS DECIMAL(12,2)) AS EstimatedMonthlyPrincipalInterest,
    h.ActiveForSaleListings,
    h.HomesSold,
    h.MedianDaysOnMarket,
    h.PriceCutSharePct,
    h.SaleToListRatioPct
FROM dbo.FactHomeMarket h
JOIN dbo.DimMonth mo ON mo.MonthKey = h.MonthKey
JOIN dbo.DimMarket mk ON mk.MarketID = h.MarketID
JOIN dbo.DimPropertyType pt ON pt.PropertyTypeID = h.PropertyTypeID
JOIN dbo.FactMortgageRate mr
  ON mr.MonthKey = h.MonthKey AND mr.LoanTermYears = 30;
GO

CREATE VIEW dbo.vw_MarketStressScore
AS
WITH LatestMonth AS
(
    SELECT MAX(MonthKey) AS MonthKey FROM dbo.DimMonth
), RentAgg AS
(
    SELECT r.MarketID,
           AVG(r.VacancyRatePct) AS AvgVacancyPct,
           AVG(r.MedianAskingRent) AS AvgRent
    FROM dbo.FactRentalMarket r
    CROSS JOIN LatestMonth lm
    WHERE r.MonthKey = lm.MonthKey
    GROUP BY r.MarketID
), Evict AS
(
    SELECT e.MarketID, e.FilingRatePer100Renters
    FROM dbo.FactEvictionStress e
    CROSS JOIN LatestMonth lm
    WHERE e.MonthKey = lm.MonthKey
), Afford AS
(
    SELECT a.MarketID,
           SUM(a.EstimatedHouseholds * a.CostBurdenedHouseholdsPct) /
             NULLIF(SUM(a.EstimatedHouseholds),0) AS WeightedBurdenPct
    FROM dbo.FactHouseholdAffordability a
    WHERE a.YearNumber = (SELECT MAX(YearNumber) FROM dbo.FactHouseholdAffordability)
      AND a.TenureID = 1
    GROUP BY a.MarketID
), Supply AS
(
    SELECT s.MarketID,
           SUM(s.PermitsIssued) AS LatestPermits
    FROM dbo.FactHousingSupply s
    CROSS JOIN LatestMonth lm
    WHERE s.MonthKey = lm.MonthKey
    GROUP BY s.MarketID
)
SELECT
    mk.MarketID,
    mk.MarketName,
    r.AvgRent,
    r.AvgVacancyPct,
    e.FilingRatePer100Renters,
    a.WeightedBurdenPct,
    sp.LatestPermits,
    CAST(
       (a.WeightedBurdenPct * 0.55)
       + (e.FilingRatePer100Renters * 12.0)
       + ((10.0 - r.AvgVacancyPct) * 2.0)
       AS DECIMAL(8,2)) AS MarketStressScore
FROM dbo.DimMarket mk
JOIN RentAgg r ON r.MarketID = mk.MarketID
JOIN Evict e ON e.MarketID = mk.MarketID
JOIN Afford a ON a.MarketID = mk.MarketID
JOIN Supply sp ON sp.MarketID = mk.MarketID;
GO

/*--------------------------------------------------------------
  13. DATA QUALITY / ROW-COUNT CHECKS
--------------------------------------------------------------*/
SELECT 'DimMonth' AS TableName, COUNT(*) AS RowCount FROM dbo.DimMonth
UNION ALL SELECT 'DimMarket', COUNT(*) FROM dbo.DimMarket
UNION ALL SELECT 'DimPropertyType', COUNT(*) FROM dbo.DimPropertyType
UNION ALL SELECT 'DimIncomeBand', COUNT(*) FROM dbo.DimIncomeBand
UNION ALL SELECT 'FactMortgageRate', COUNT(*) FROM dbo.FactMortgageRate
UNION ALL SELECT 'FactRentalMarket', COUNT(*) FROM dbo.FactRentalMarket
UNION ALL SELECT 'FactHomeMarket', COUNT(*) FROM dbo.FactHomeMarket
UNION ALL SELECT 'FactHouseholdAffordability', COUNT(*) FROM dbo.FactHouseholdAffordability
UNION ALL SELECT 'FactHousingSupply', COUNT(*) FROM dbo.FactHousingSupply
UNION ALL SELECT 'FactEvictionStress', COUNT(*) FROM dbo.FactEvictionStress
ORDER BY TableName;
GO

/* A few sanity checks */
SELECT TOP 20 * FROM dbo.vw_RentalTrend
ORDER BY MonthKey DESC, MarketName, PropertyTypeName;
GO

SELECT TOP 20 * FROM dbo.vw_HomeBuyingAffordability
ORDER BY MonthKey DESC, MarketName, PropertyTypeName;
GO

SELECT * FROM dbo.vw_MarketStressScore
ORDER BY MarketStressScore DESC;
GO
