# Housing Affordability Analytics Dashboard

A Tableau dashboard built on top of the `HousingAffordabilityAnalytics` SQL Server database, analyzing rental and for-sale housing costs, mortgage affordability, supply pipeline, and eviction pressure across multiple U.S. metro markets.

## Data Source

- **Server:** `TWYOGA\SQLEXPRESS` (Microsoft SQL Server)
- **Database:** `HousingAffordabilityAnalytics`
- **Connection type:** Live

## Data Model

The core dashboard runs on a **relationship-based star schema** (not physical joins), built in Tableau's Data Source canvas, because several fact tables share dimensions at different grains.

**Dimension tables (hubs):**
- `DimMarket`
- `DimMonth`
- `DimPropertyType`
- `DimIncomeBand`
- `DimTenure`

**Fact tables and how they connect:**

| Fact table | Relates to | Notes |
|---|---|---|
| `FactRentalMarket` | DimMarket, DimMonth, DimPropertyType | Monthly rental metrics |
| `FactHomeMarket` | DimMarket, DimMonth, DimPropertyType | Monthly for-sale metrics |
| `FactHousingSupply` | DimMarket, DimMonth, DimPropertyType | Permits/starts/completions |
| `FactEvictionStress` | DimMarket, DimMonth | No property-type breakdown |
| `FactHouseholdAffordability` | DimMarket, DimIncomeBand, DimTenure | **Annual grain** — not related to DimMonth |
| `FactMortgageRate` | DimMonth only | National rate series — no MarketID at all |

`seed.MarketProfile` is excluded from the model entirely — it's a data-generation helper table, not a reporting table.

## Custom Views

Beyond the core model, a set of single-purpose SQL views power individual dashboard sheets. Each is connected in Tableau as its own standalone data source (not related into the main model), since they're already flat, pre-aggregated results.

| View | Answers | Known caveats |
|---|---|---|
| `HighRentMarkets` | Highest-rent market per property type (latest month) | — |
| `RentVacancyIncrease` | Markets where rent and vacancy both rose YoY | Original version only showed current-state averages, not a true YoY comparison — **corrected** to add a `LAG()`-based prior-year vacancy comparison |
| `RenterCostBurden` | Renter cost burden by market and income band (latest year, renters only) | — |
| `MonthlyMortgagePayment` | Estimated monthly mortgage payment (via `vw_HomeBuyingAffordability`) | Reflects **principal & interest only** — excludes property tax, insurance, PMI, and HOA. Dashboard labeling calls this out explicitly. |
| `MarketHousingSupply` | Supply pipeline by market (latest year) | — |
| `RentalYearlyIncrease` | Highest YoY rent growth by market/property type | — |
| `MarketEvictionRates` | Eviction filing rates across markets | Original join was missing a `MonthKey` condition, causing rent/vacancy context columns to average across all history instead of the latest month — **corrected**. Still capped at `TOP 13` markets, ordered by filing rate — markets beyond that cutoff won't appear. |
| `MarketPropertySupply` | Leading property type supplied per market | Scoped to **all-time** cumulative completions (by design choice — left unedited rather than matching the latest-year scope used elsewhere). Uses `RANK()`, so a true tie in `UnitsCompleted` between two property types in the same market will produce two rows for that market. |
| `SoldRentTrends` | MoM/YoY rent and sale-price trend calculations; also used as the basis for the "low sales/rental activity" sheet | The `SalePriceChangeYoY` / `SalePricePctChangeYoY` columns reference `LAG(MedianSalePrice, 1)` instead of `LAG(MedianSalePrice, 12)` — a copy/paste bug that makes them compute MoM, not YoY, change. **Not yet fixed** — flagged for follow-up. Also has no `MarketName` column (only `MarketID`); dashboard sheets built on this view relate `DimMarket` in on the Tableau side to get readable names. |
| `EvictionPressureTrend` | Eviction pressure trend over time, with MoM filing-rate change | — |
| `RankedMarketStress` | Markets ranked by packaged composite stress score (`vw_MarketStressScore`) | — |
| `RentMovingAvgByPropertyType` | 3-month moving average rent by property type | Window-function exercise — kept as a view rather than a Tableau table calc |

## Dashboard Sheets

| Sheet | Data source | Chart type | Notes |
|---|---|---|---|
| Highest Rent by Property Type | `HighRentMarkets` | Bar chart, filtered to `RentRank = 1` | One bar per property type, labeled by market |
| Rent vs Vacancy Inflection | `RentVacancyIncrease` (corrected) | Quadrant scatter | Rent growth % (x) vs. vacancy change % (y), zero-reference lines on both axes, colored by whether a market falls in the "both rising" quadrant |
| Renter Cost Burden by Income Band | `RenterCostBurden` | Scatter (income vs. housing cost, colored by burden status) **and** a heatmap (Market × Income Band, colored by `HousingCostToIncomePct`) | Two complementary views: the scatter keeps raw dollar context, the heatmap is the fast scan for worst combinations |
| Estimated Monthly Mortgage Payment | `MonthlyMortgagePayment` | Dual-panel bar chart (Condo/Townhome vs. Single-Family Home) | Axis and sheet title explicitly labeled "Principal & Interest" to avoid implying it's a full payment figure |
| Eviction Rates by Market | `MarketEvictionRates` (corrected) | Sorted bar chart, color gradient on filing rate | Capped at 13 markets per the view's `TOP 13` |
| Leading Property Type by Market | `MarketPropertySupply` (as originally written) | Bar chart colored by property type | Title explicitly flags "All-Time" scope to avoid confusion with the latest-year-scoped supply sheet |
| Low Sales/Rental Activity | `SoldRentTrends` with `DimMarket` related in on the Tableau side | Heatmap (Market × Property Type), filtered to a calculated Activity Status | Uses a live-adjustable **"Low Activity Threshold" parameter** rather than a hardcoded SQL cutoff, filtered to the latest month via an LOD calc (`{MAX([MonthKey])}`) |

## Parameters

- **Home Threshold Pct** (Integer) — controls the cutoff percent for 'HomesSold' in comparison to the maximum in that category in Home Market Activity sheet. Adjustable live from the dashboard.
- **Rental Threshold Pct** (Integer) — controls the cutoff below for 'ActiveRentalListings' in comparison to the maximum in that category in Rental Market Activity sheet. Adjustable live from the dashboard.
