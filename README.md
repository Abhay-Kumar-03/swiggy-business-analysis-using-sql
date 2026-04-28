# 🍊 Swiggy Sales Analysis — End-to-End SQL Project

![SQL](https://img.shields.io/badge/Tool-Microsoft%20SQL%20Server-CC2927?style=for-the-badge&logo=microsoftsqlserver&logoColor=white)
![T-SQL](https://img.shields.io/badge/Language-T--SQL-blue?style=for-the-badge)
![Domain](https://img.shields.io/badge/Domain-Food%20Delivery%20Analytics-orange?style=for-the-badge)
![Schema](https://img.shields.io/badge/Schema-Star%20Schema-green?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen?style=for-the-badge)

---

## 📌 Project Overview

A complete, production-style SQL analytics project built on Swiggy's food delivery dataset. Starting from a raw, messy flat table, this project walks through every stage a real data analyst would follow — data validation and cleaning, dimensional modelling with a Star Schema, KPI computation, and 12+ deep-dive business queries.

> **Every query answers a real business question — the same ones Swiggy's analytics and product teams would ask every day.**

---

## 🚨 Business Problem

The raw Swiggy dataset contains food delivery records across multiple Indian states, cities, restaurants, categories, and dishes — all dumped into a single flat table. Without structure or validation, it is impossible to reliably answer:

| Business Question | Why It Matters |
|---|---|
| Which cities and states generate the most orders and revenue? | Resource allocation and expansion decisions |
| Which food categories and dishes are most popular? | Menu strategy and promotional targeting |
| How do orders trend across months, quarters, and days? | Seasonal planning and staffing |
| What is the average dish price and customer rating? | Pricing strategy and quality benchmarking |
| How are customers distributed across price ranges? | Customer segmentation and offer design |
| Which restaurants are top performers by revenue? | Partnership prioritisation |

**Additional data quality problems in the raw table:**
- NULL values across business-critical columns
- Blank/empty strings that standard NULL checks miss
- Duplicate records that corrupt aggregations and KPIs

---

## ✅ Solution — Four-Phase Approach

```
Phase 1: Data Validation & Cleaning
         ↓
Phase 2: Dimensional Modelling (Star Schema)
         ↓
Phase 3: KPI Development
         ↓
Phase 4: Deep-Dive Business Analysis (12+ queries)
```

---

## 🔧 Phase 1 — Data Validation & Cleaning

Three data quality checks were performed on the raw `swiggy_data` table before any analysis:

### 1.1 Null Check
Conditional aggregation across all 10 business-critical columns in a single scan:

```sql
SELECT
    SUM(CASE WHEN State IS NULL THEN 1 ELSE 0 END)           AS null_state,
    SUM(CASE WHEN City IS NULL THEN 1 ELSE 0 END)            AS null_city,
    SUM(CASE WHEN Order_Date IS NULL THEN 1 ELSE 0 END)      AS null_order_date,
    SUM(CASE WHEN Restaurant_Name IS NULL THEN 1 ELSE 0 END) AS null_restaurant,
    SUM(CASE WHEN Location IS NULL THEN 1 ELSE 0 END)        AS null_location,
    SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END)        AS null_category,
    SUM(CASE WHEN Dish_Name IS NULL THEN 1 ELSE 0 END)       AS null_dish,
    SUM(CASE WHEN Price_INR IS NULL THEN 1 ELSE 0 END)       AS null_price,
    SUM(CASE WHEN Rating IS NULL THEN 1 ELSE 0 END)          AS null_rating,
    SUM(CASE WHEN Rating_Count IS NULL THEN 1 ELSE 0 END)    AS null_rating_count
FROM swiggy_data;
```

### 1.2 Blank / Empty String Check
Records with `''` in text fields are invisible to NULL checks but still break GROUP BY results:

```sql
SELECT * FROM swiggy_data
WHERE State = '' OR City = '' OR Restaurant_Name = ''
      OR Location = '' OR Category = '' OR Dish_Name = '';
```

### 1.3 Duplicate Detection & Removal
Duplicates detected by grouping on all 10 business columns. Removal performed using a CTE with `ROW_NUMBER()` — keeping the first occurrence, deleting all surplus copies:

```sql
-- Detection
SELECT
    State, City, Order_Date, Restaurant_Name, Location,
    Category, Dish_Name, Price_INR, Rating, Rating_Count,
    COUNT(*) AS CNT
FROM swiggy_data
GROUP BY State, City, Order_Date, Restaurant_Name, Location,
         Category, Dish_Name, Price_INR, Rating, Rating_Count
HAVING COUNT(*) > 1;

-- Removal
WITH CTE AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY State, City, Order_Date, Restaurant_Name,
                         Location, Category, Dish_Name, Price_INR,
                         Rating, Rating_Count
            ORDER BY (SELECT NULL)
        ) AS rn
    FROM swiggy_data
)
DELETE FROM CTE WHERE rn > 1;
```

---

## 🗂️ Phase 2 — Dimensional Modelling (Star Schema)

After cleaning, the flat table was restructured into a **Star Schema** — the industry standard for analytical databases.

### Why Star Schema?
- Eliminates data redundancy — restaurant names, city names stored once
- Faster query performance — small, focused dimension lookups
- Cleaner aggregations — `GROUP BY` on integer keys, not repeated text
- BI-ready — works natively with Power BI, Tableau, and Excel Pivot

### Schema Diagram

```
              dim_date                dim_location
             (date_id) ─────────┐ ┌─── (location_id)
                                ↓ ↓
dim_dish ──────────── fact_swiggy_orders ──────────── dim_restaurant
(dish_id)               (order_id PK)                 (restaurant_id)
                                ↑
                          dim_category
                          (category_id)
```

### Dimension Tables

| Table | Primary Key | Columns | Purpose |
|---|---|---|---|
| `dim_date` | `date_id` | full_date, year, month, month_name, quarter, day, week | Time-series slicing |
| `dim_location` | `location_id` | state, city, location | Full geographic hierarchy |
| `dim_restaurant` | `restaurant_id` | restaurant_name | Restaurant master list |
| `dim_category` | `category_id` | category | Cuisine and food types |
| `dim_dish` | `dish_id` | dish_name | All unique dishes |

### Fact Table

| Table | Measures | Foreign Keys |
|---|---|---|
| `fact_swiggy_orders` | Price_INR, Rating, Rating_Count | date_id, location_id, restaurant_id, category_id, dish_id |

### Creating the Schema

```sql
-- Date Dimension
CREATE TABLE dim_date (
    date_id    INT IDENTITY(1,1) PRIMARY KEY,
    full_date  DATE,
    year       INT,
    month      INT,
    month_name VARCHAR(20),
    quarter    INT,
    day        INT,
    week       INT
);

-- Location Dimension
CREATE TABLE dim_location (
    location_id INT IDENTITY(1,1) PRIMARY KEY,
    state       VARCHAR(100),
    city        VARCHAR(100),
    Location    VARCHAR(100)
);

-- Restaurant Dimension
CREATE TABLE dim_restaurant (
    restaurant_id  INT IDENTITY(1,1) PRIMARY KEY,
    Restaurant_name VARCHAR(200)
);

-- Category Dimension
CREATE TABLE dim_category (
    category_id INT IDENTITY(1,1) PRIMARY KEY,
    Category    VARCHAR(200)
);

-- Dish Dimension
CREATE TABLE dim_dish (
    dish_id   INT IDENTITY(1,1) PRIMARY KEY,
    Dish_name VARCHAR(200)
);

-- Fact Table
CREATE TABLE fact_swiggy_orders (
    order_id      INT IDENTITY(1,1) PRIMARY KEY,
    date_id       INT,
    Price_INR     DECIMAL(10,2),
    Rating        DECIMAL(4,2),
    Rating_Count  INT,
    location_id   INT,
    restaurant_id INT,
    category_id   INT,
    dish_id       INT,
    FOREIGN KEY (date_id)       REFERENCES dim_date(date_id),
    FOREIGN KEY (location_id)   REFERENCES dim_location(location_id),
    FOREIGN KEY (restaurant_id) REFERENCES dim_restaurant(restaurant_id),
    FOREIGN KEY (category_id)   REFERENCES dim_category(category_id),
    FOREIGN KEY (dish_id)       REFERENCES dim_dish(dish_id)
);
```

### Loading Data into the Schema

Dimension tables populated with `SELECT DISTINCT`. Fact table loaded by resolving all foreign keys via `JOIN`:

```sql
INSERT INTO fact_swiggy_orders (
    date_id, Price_INR, Rating, Rating_Count,
    location_id, restaurant_id, category_id, dish_id
)
SELECT
    dd.date_id, s.Price_INR, s.Rating, s.Rating_Count,
    dl.location_id, dr.restaurant_id, dc.category_id, dsh.dish_id
FROM swiggy_data AS s
JOIN dim_date        AS dd  ON dd.full_date       = s.Order_Date
JOIN dim_location    AS dl  ON dl.state           = s.State
                           AND dl.city            = s.City
                           AND dl.Location        = s.Location
JOIN dim_restaurant  AS dr  ON dr.Restaurant_name = s.Restaurant_Name
JOIN dim_category    AS dc  ON dc.Category        = s.Category
JOIN dim_dish        AS dsh ON dsh.Dish_name      = s.Dish_Name;
```

---

## 📊 Phase 3 — Core KPIs

| KPI | SQL Technique | Business Purpose |
|---|---|---|
| Total Orders | `COUNT(*)` on fact table | Overall platform volume |
| Total Revenue | `SUM(Price_INR)` formatted in Millions | Revenue tracking in INR Millions |
| Avg Dish Price | `AVG` with `CONVERT(FLOAT)` | Typical customer spend per dish |
| Avg Rating | `AVG(Rating)` | Platform-wide satisfaction benchmark |

```sql
-- Total Orders
SELECT COUNT(*) AS total_orders FROM fact_swiggy_orders;

-- Total Revenue (in Millions)
SELECT
    FORMAT(SUM(CONVERT(FLOAT, Price_INR)) / 1000000, 'N2') + ' INR Million' AS total_revenue
FROM fact_swiggy_orders;

-- Average Dish Price
SELECT
    FORMAT(AVG(CONVERT(FLOAT, Price_INR)), 'N2') + ' INR' AS avg_dish_price
FROM fact_swiggy_orders;

-- Average Rating
SELECT AVG(Rating) AS avg_rating FROM fact_swiggy_orders;
```

---

## 🔍 Phase 4 — Deep-Dive Business Analysis

### 📅 Time & Order Trends

```sql
-- Monthly Order Trends
SELECT d.year, d.month, d.month_name, COUNT(*) AS total_orders
FROM fact_swiggy_orders AS f
JOIN dim_date AS d ON f.date_id = d.date_id
GROUP BY d.year, d.month, d.month_name;

-- Monthly Revenue Trend
SELECT d.year, d.month, d.month_name, SUM(price_INR) AS total_revenue
FROM fact_swiggy_orders AS f
JOIN dim_date AS d ON f.date_id = d.date_id
GROUP BY d.year, d.month, d.month_name
ORDER BY SUM(price_INR) ASC;

-- Quarterly Orders
SELECT d.year, d.quarter, COUNT(*) AS total_orders
FROM fact_swiggy_orders AS f
JOIN dim_date AS d ON f.date_id = d.date_id
GROUP BY d.year, d.quarter
ORDER BY COUNT(*) DESC;

-- Yearly Orders
SELECT d.year, COUNT(*) AS total_orders
FROM fact_swiggy_orders AS f
JOIN dim_date AS d ON f.date_id = d.date_id
GROUP BY d.year;

-- Orders by Day of Week (correctly sorted Mon–Sun)
SELECT
    DATENAME(WEEKDAY, d.full_date) AS day_name,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders AS f
JOIN dim_date AS d ON f.date_id = d.date_id
GROUP BY DATENAME(WEEKDAY, d.full_date), DATEPART(WEEKDAY, d.full_date)
ORDER BY DATEPART(WEEKDAY, d.full_date);
```

### 📍 Location-Based Analysis

```sql
-- Top 10 Cities by Order Volume
SELECT TOP 10
    l.city, COUNT(*) AS total_orders
FROM fact_swiggy_orders AS f
JOIN dim_location AS l ON l.location_id = f.location_id
GROUP BY l.city
ORDER BY COUNT(*) DESC;

-- Revenue Contribution by State
SELECT
    l.state, SUM(f.price_INR) AS total_revenue
FROM fact_swiggy_orders AS f
JOIN dim_location AS l ON l.location_id = f.location_id
GROUP BY l.state
ORDER BY SUM(f.price_INR) DESC;
```

### 🍽️ Food & Restaurant Performance

```sql
-- Top 10 Restaurants by Revenue
SELECT TOP 10
    r.Restaurant_name, SUM(f.price_INR) AS total_revenue
FROM fact_swiggy_orders AS f
JOIN dim_restaurant AS r ON r.restaurant_id = f.restaurant_id
GROUP BY r.Restaurant_name
ORDER BY SUM(f.price_INR) DESC;

-- Top Categories by Order Volume
SELECT TOP 10
    c.category, COUNT(*) AS total_orders
FROM fact_swiggy_orders AS f
JOIN dim_category AS c ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY SUM(f.price_INR) DESC;

-- Most Ordered Dishes
SELECT TOP 10
    d.dish_name, COUNT(*) AS order_count
FROM fact_swiggy_orders AS f
JOIN dim_dish AS d ON f.dish_id = d.dish_id
GROUP BY d.dish_name
ORDER BY order_count DESC;

-- Cuisine Performance: Volume + Rating (find hidden gems)
SELECT
    c.category,
    COUNT(*) AS total_orders,
    ROUND(AVG(CONVERT(FLOAT, f.Rating)), 4) AS avg_rating
FROM fact_swiggy_orders AS f
JOIN dim_category AS c ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY total_orders DESC;
```

### 💰 Customer Spending & Rating Analysis

```sql
-- Price Range Distribution
SELECT price_range, COUNT(*) AS total_orders
FROM (
    SELECT
        CASE
            WHEN CONVERT(FLOAT, price_inr) < 100               THEN 'Under 100'
            WHEN CONVERT(FLOAT, price_inr) BETWEEN 100 AND 199 THEN '100 - 199'
            WHEN CONVERT(FLOAT, price_inr) BETWEEN 200 AND 299 THEN '200 - 299'
            WHEN CONVERT(FLOAT, price_inr) BETWEEN 300 AND 499 THEN '300 - 499'
            ELSE '500+'
        END AS price_range
    FROM fact_swiggy_orders
) AS subquery
GROUP BY price_range
ORDER BY total_orders DESC;

-- Rating Distribution (1–5)
SELECT rating, COUNT(*) AS rating_count
FROM fact_swiggy_orders
GROUP BY rating
ORDER BY COUNT(*) DESC;
```

---

## 🛠️ SQL Techniques Demonstrated

| Technique | Where Used |
|---|---|
| `CASE + SUM` Conditional Aggregation | NULL detection across all columns in one scan |
| CTE (Common Table Expression) | Duplicate removal with `ROW_NUMBER()` |
| `ROW_NUMBER() + PARTITION BY` | Assigning row numbers per duplicate group for targeted `DELETE` |
| `IDENTITY(1,1)` Primary Keys | Auto-incrementing surrogate keys on all dimension and fact tables |
| `FOREIGN KEY` Constraints | Enforcing referential integrity across the star schema |
| Multi-table JOINs (5 tables) | Full data reconstruction from fact + all dimensions |
| `SELECT DISTINCT` | Clean, deduplicated dimension population |
| `DATENAME + DATEPART` | Day-of-week analysis with correct Monday–Sunday sort order |
| `CONVERT(FLOAT)` | Precision handling for DECIMAL columns in AVG calculations |
| `FORMAT()` | Business-readable revenue output (e.g. `12.45 INR Million`) |
| Subquery + `CASE WHEN` buckets | Price range segmentation for spend analysis |
| `TOP N + ORDER BY` | Top 10 cities, restaurants, dishes, and categories |

---

## 🗃️ Final Database Objects

| Object | Type | Source | Description |
|---|---|---|---|
| `swiggy_data` | Raw Table | Original CSV import | Flat source table — cleaned in Phase 1 |
| `dim_date` | Dimension | DISTINCT Order_Date | Date attributes for time-series analysis |
| `dim_location` | Dimension | DISTINCT State + City + Location | Full geographic hierarchy |
| `dim_restaurant` | Dimension | DISTINCT Restaurant_Name | Restaurant master list |
| `dim_category` | Dimension | DISTINCT Category | Cuisine and food category list |
| `dim_dish` | Dimension | DISTINCT Dish_Name | All dish names across the platform |
| `fact_swiggy_orders` | Fact Table | Full cleaned swiggy_data | Central transaction table with FK links |

---

## 💼 Skills Showcased

- ✅ End-to-end analytics engineering workflow
- ✅ Production-quality Star Schema database design
- ✅ Advanced T-SQL: window functions, CTEs, multi-table JOINs, subqueries
- ✅ Data cleaning and validation best practices
- ✅ Business-oriented KPI development
- ✅ Real-world food delivery domain analysis
- ✅ BI-ready schema (Power BI / Tableau compatible)

---

## 📁 Repository Structure

```
📦 swiggy-sql-analysis
 ┣ 📄 SQLQuery.sql              ← All SQL code (cleaning → schema → KPIs → analysis)
 ┣ 📄 Swiggy_SQL_Project_Report.pdf  ← Detailed project report
 ┣ 📄 Business_Requirements.docx     ← Business problem and requirements
 ┣ 📄 Project_Presentation.pdf       ← Slide deck presentation
 ┗ 📄 README.md                ← This file
```

---

## 🚀 How to Run

1. Import the raw `swiggy_data` CSV into Microsoft SQL Server as a flat table.
2. Open `SQLQuery.sql` in SQL Server Management Studio (SSMS).
3. Execute sections sequentially:
   - **Data Cleaning** → validates and deduplicates the raw table
   - **Schema Creation** → creates all dimension and fact tables
   - **Data Population** → loads dimension and fact tables from cleaned data
   - **KPIs** → run individual KPI queries
   - **Business Analysis** → run any deep-dive query independently

---

## 👤 Author

**Abhay**
Aspiring SQL Developer | Analyst
📍 Lucknow, India

---

*Built with Microsoft SQL Server (T-SQL) · Star Schema Design · Food Delivery Analytics*
