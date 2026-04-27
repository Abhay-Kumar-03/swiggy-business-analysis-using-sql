SELECT * FROM swiggy_data;

-- ============================================================
-- DATA VALIDATION & CLEANING
-- ============================================================
-- ------->>> Null Check <<<-------
SELECT
SUM(CASE WHEN State IS NULL THEN 1 ELSE 0 END) AS null_state,
SUM(CASE WHEN City IS NULL THEN 1 ELSE 0 END) AS null_city,
SUM(CASE WHEN Order_Date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
SUM( CASE WHEN Restaurant_Name IS NULL THEN 1 ELSE 0 END) AS null_restaurant,
SUM(CASE WHEN Location IS NULL THEN 1 ELSE 0 END) AS null_location,
SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END) AS null_category,
SUM( CASE WHEN Dish_Name IS NULL THEN 1 ELSE 0 END) AS null_dish,
SUM(CASE WHEN Price_INR IS NULL THEN 1 ELSE 0 END) AS null_price, 
SUM(CASE WHEN Rating IS NULL THEN 1 ELSE 0 END) AS null_rating,
SUM(CASE WHEN Rating_Count IS NULL THEN 1 ELSE 0 END) AS null_rating_count
FROM swiggy_data;


-- ------->>> Blank or Empty String <<<-------
SELECT * FROM swiggy_data
WHERE State = '' OR City = '' OR Restaurant_Name = '' 
	  OR Location = '' OR Category = '' OR Dish_Name = '';


-- ------->>> Duplicate Detection <<<-------
SELECT
	State,
	City,
	Order_Date,
	Restaurant_Name,
	Location,
	Category,
	Dish_Name,
	Price_INR,
	Rating,
	Rating_Count,
	COUNT(*) AS CNT
FROM swiggy_data
GROUP BY State, City, Order_Date, Restaurant_Name, Location, 
		 Category, Dish_Name, Price_INR, Rating, Rating_Count
HAVING COUNT(*) > 1;

-- delete duplicate values
WITH CTE AS(
	SELECT
		*,
		ROW_NUMBER() OVER(
						  PARTITION BY State, City, Order_Date, Restaurant_Name,
						  Location,Category, Dish_Name, Price_INR, Rating, Rating_Count
						  ORDER BY(SELECT NULL)
						  ) AS rn
	FROM swiggy_data
)
DELETE FROM CTE WHERE rn>1;




-- ============================================================
-- CREATING SCHEMA
-- ============================================================
-- ------->>> Creating Dimension Tables <<<-------
-- ------->>>Date Table
CREATE TABLE dim_date(
	date_id INT IDENTITY(1,1) PRIMARY KEY,
	full_date DATE,
	year INT,
	month INT,
	month_name varchar(20),
	quarter INT,
	day INT,
	week INT
);


-- ------->>>Loation Table
CREATE TABLE dim_location(
	location_id INT IDENTITY(1,1) PRIMARY KEY,
	state VARCHAR(100),
	city VARCHAR(100),
	Location VARCHAR(100)
);


-- ------->>>Restaurant Table
CREATE TABLE dim_restaurant(
	restaurant_id INT IDENTITY(1,1) PRIMARY KEY,
	Restaurant_name VARCHAR(200)
);


-- ------->>>Category Table
CREATE TABLE dim_category(
	category_id INT IDENTITY(1,1) PRIMARY KEY,
	Category VARCHAR(200)
);

-- ------->>>Dish Table
CREATE TABLE dim_dish(
	dish_id INT IDENTITY(1,1) PRIMARY KEY,
	Dish_name VARCHAR(200)
);



-- ------->>> Creating Fact Table <<<-------

CREATE TABLE fact_swiggy_orders (
	order_id INT IDENTITY (1,1) PRIMARY KEY,
	
	date_id INT,
	Price_INR DECIMAL (10,2),
	Rating DECIMAL (4,2),
	Rating_Count INT,

	location_id INT,
	restaurant_id INT,
	category_id INT,
	dish_id INT,

	FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
	FOREIGN KEY (location_id) REFERENCES dim_location(location_id),
	FOREIGN KEY (restaurant_id) REFERENCES dim_restaurant(restaurant_id),
	FOREIGN KEY (category_id) REFERENCES dim_category(category_id),
	FOREIGN KEY (dish_id) REFERENCES dim_dish(dish_id)
) ;



-- ------->>> Inserting Data In Tables <<<-------
-- ------->>> IN Date Table
INSERT INTO dim_date (full_date, year, month, month_name, quarter, day, week)
SELECT DISTINCT
	Order_Date,
	YEAR (Order_Date), MONTH(Order_Date),
	DATENAME (MONTH, Order_Date),
	DATEPART (QUARTER, Order_Date),
	DAY (Order_Date),
	DATEPART (WEEK, Order_Date)
FROM swiggy_data
WHERE Order_Date IS NOT NULL;


-- ------->>> IN Loation Table
INSERT INTO dim_location(state, city, Location)
SELECT DISTINCT
	state, 
	city, 
	Location
FROM swiggy_data;


-- ------->>> IN Resturant Table
INSERT INTO dim_restaurant(Restaurant_name)
SELECT DISTINCT
	Restaurant_name
FROM swiggy_data;


-- ------->>> IN Category Table
INSERT INTO dim_category(Category)
SELECT DISTINCT
	Category
FROM swiggy_data;

-- ------->>> IN Dish Table
INSERT INTO dim_dish(Dish_name)
SELECT DISTINCT
	Dish_name
FROM swiggy_data;


-- ------->>> IN Fact Table
INSERT INTO fact_swiggy_orders (
    date_id, Price_INR, Rating, Rating_Count,
    location_id, restaurant_id, category_id, dish_id
)
SELECT
    dd.date_id,
    s.Price_INR,
    s.Rating,
    s.Rating_Count,
    dl.location_id,
    dr.restaurant_id,
    dc.category_id,
    dsh.dish_id
FROM swiggy_data AS s
JOIN dim_date AS dd       ON dd.full_date = s.Order_Date
JOIN dim_location AS dl   ON dl.state = s.State
                          AND dl.city = s.City
                          AND dl.Location = s.Location
JOIN dim_restaurant AS dr ON dr.Restaurant_name = s.Restaurant_Name
JOIN dim_category AS dc   ON dc.Category = s.Category
JOIN dim_dish AS dsh      ON dsh.Dish_name = s.Dish_Name;




-- FULL TABLE
select * from fact_swiggy_orders as f
JOIN dim_date AS d ON f.date_id = d.date_id
JOIN dim_location AS l ON f.location_id = l.location_id
JOIN dim_restaurant AS r ON f.restaurant_id = r.restaurant_id
JOIN dim_category AS c ON f.category_id = c.category_id
JOIN dim_dish AS di ON f.dish_id = di.dish_id




-- ============================================================
-- KPI's
-- ============================================================
-- ------->>> Total Orders
SELECT
	COUNT(*) AS total_order
FROM fact_swiggy_orders;


-- ------->>> Total Revenue
SELECT
	SUM(Price_INR) AS total_revenue
FROM fact_swiggy_orders;

SELECT
	FORMAT(SUM(CONVERT(FLOAT, Price_INR))/1000000, 'N2') + ' INR Million' AS total_revenue
FROM fact_swiggy_orders;


-- ------->>> Avg Dish Price
SELECT
	FORMAT(AVG(CONVERT(FLOAT, Price_INR)), 'N2') + ' INR' AS avg_dish_price
FROM fact_swiggy_orders;

-- ------->>> Avg Rating
SELECT
	AVG(Rating) AS avg_rating
FROM fact_swiggy_orders;




-- ============================================================
-- Deep-Dive Bussiness Analysis
-- ============================================================
-- ------->>> Monthly Orders Trends
SELECT
	d.year,
	d.month,
	d.month_name,
	COUNT(*) AS total_orders
FROM fact_swiggy_orders AS f
JOIN dim_date AS d
	ON f.date_id = d.date_id
GROUP BY d.year,
		d.month,
		d.month_name


-- ------->>> Monthly Total Revenue Trend
SELECT
	d.year,
	d.month,
	d.month_name,
	SUM(price_INR) AS total_revenue
FROM fact_swiggy_orders AS f
JOIN dim_date AS d
	ON f.date_id = d.date_id
GROUP BY d.year,
		d.month,
		d.month_name
ORDER BY SUM(price_INR) ASC


-- ------->>> Quaterly Orders Trends
SELECT
	d.year,
	d.quarter,
	COUNT(*) AS total_orders
FROM fact_swiggy_orders AS f
JOIN dim_date AS d
	ON f.date_id = d.date_id
GROUP BY d.year,
		d.quarter
ORDER BY COUNT(*) DESC


-- ------->>> Yearly Orders Trends
SELECT
	d.year,
	COUNT(*) AS total_orders
FROM fact_swiggy_orders AS f
JOIN dim_date AS d
	ON f.date_id = d.date_id
GROUP BY d.year


-- ------->>> Orders by Day of Week (Mon-Sun)
SELECT
	DATENAME(WEEKDAY, d.full_date) AS day_name,
	COUNT(*) AS total_orders
FROM fact_swiggy_orders AS f
JOIN dim_date AS d ON f.date_id = d.date_id
GROUP BY DATENAME(WEEKDAY, d.full_date), DATEPART(WEEKDAY, d.full_date)
ORDER BY DATEPART(WEEKDAY, d.full_date);


-- ------->>> Top 10 Cities by Order Volume
SELECT TOP 10
	l.city,
	COUNT(*) AS total_orders 
FROM fact_swiggy_orders AS f
JOIN dim_location AS l
	ON l.location_id = f.location_id
GROUP BY l.city
ORDER BY COUNT(*) DESC


-- ------->>> Revenue Contribution by states
SELECT
	l.state,
	SUM(f.price_INR) AS total_revenue
FROM fact_swiggy_orders AS f
JOIN dim_location AS l
	ON l.location_id = f.location_id
GROUP BY l.state
ORDER BY SUM(f.price_INR) DESC


-- ------->>> Top 10 Restaurant by states
SELECT TOP 10
	r.Restaurant_name,
	SUM(f.price_INR) AS total_revenue
FROM fact_swiggy_orders AS f
JOIN dim_restaurant AS r
	ON r.restaurant_id = f.restaurant_id
GROUP BY r.restaurant_name
ORDER BY SUM(f.price_INR) DESC


-- ------->>> Top Categories by order volume
SELECT TOP 10
	c.category,
	COUNT(*) AS total_orders
FROM fact_swiggy_orders AS f
JOIN dim_category AS c
	ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY SUM(f.price_INR) DESC


-- ------->>> Most Ordered Dish
SELECT TOP 10
	d.dish_name,
	COUNT(*) AS order_count
FROM fact_swiggy_orders AS f
JOIN dim_dish AS d
	ON f.dish_id = d.dish_id
GROUP BY d.dish_name
ORDER BY order_count DESC


-- ------->>> Cuisine Performane(Orders + Avg Rating)
SELECT
	c.category,
	COUNT(*) AS total_orders,
	ROUND(AVG(CONVERT(FLOAT, f.Rating)), 4) AS avg_rating
FROM fact_swiggy_orders AS f
JOIN dim_category AS c
	ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY total_orders DESC


-- ------->>> Total Orders by Price Range
SELECT
    price_range,
    COUNT(*) AS total_orders
FROM (
		SELECT
			CASE
				WHEN CONVERT(FLOAT, price_inr) < 100              THEN 'Under 100'
				WHEN CONVERT(FLOAT, price_inr) BETWEEN 100 AND 199 THEN '100 - 199'
				WHEN CONVERT(FLOAT, price_inr) BETWEEN 200 AND 299 THEN '200 - 299'
				WHEN CONVERT(FLOAT, price_inr) BETWEEN 300 AND 499 THEN '300 - 499'
				ELSE '500+'
			END AS price_range
		FROM fact_swiggy_orders
	) AS subquery
GROUP BY price_range
ORDER BY total_orders DESC;


-- ------->>> Rating Count Distribution(1-5)
SELECT
	rating,
	COUNT(*) AS rating_count
FROM fact_swiggy_orders
GROUP BY rating
ORDER BY COUNT(*) DESC;














