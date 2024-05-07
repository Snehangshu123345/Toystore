USE toystore


--Setting up fk and pk---
alter table sales add foreign key(Store_Id) references stores(Store_Id);
alter table sales add foreign key(Product_Id) references products(Product_Id);
alter table inventory add foreign key(Store_Id) references stores(Store_Id);
alter table inventory add foreign key(Product_Id) references products(Product_Id);
----
--CHECKING FOR NULL VALUES
SELECT * FROM calendar
WHERE Date IS NULL
SELECT * FROM inventory
WHERE Store_Id IS NULL OR Product_Id IS NULL OR Stock_On_Hand IS NULL
SELECT * FROM products
WHERE Product_Name IS NULL OR Product_Category IS NULL OR Product_Cost IS NULL OR Product_Price IS NULL
SELECT * FROM Sales
WHERE Date IS NULL OR Store_Id IS NULL OR Product_Id IS NULL OR Units IS NULL
SELECT * FROM Stores
WHERE Store_Name IS NULL OR Store_City IS Null OR Store_Location IS NULL OR Store_Open_Date IS NULL


--DATA DUPLICATION CHECK
SELECT Date,count(*)
FROM 
calendar
group by Date
having count(*)>1
SELECT Store_Id,Product_ID,Stock_On_Hand,count(*)
FROM inventory
group by
Store_Id,Product_ID,Stock_On_Hand
having 
count(*)>1
SELECT Product_Name,Product_Category,Product_Cost,Product_Price,count(*)
FROM Products
group by
Product_Name,Product_Category,Product_Cost,Product_Price
having count(*)>1
SELECT Date,Store_Id,Product_Id,Units,count(*)
FROM sales
group by
Date,Store_Id,Product_ID,Units
having count(*)>1
SELECT Store_Name,Store_City,Store_Location,Store_Open_Date,count(*)
FROM Stores
group by Store_Name,Store_City,Store_Location,Store_Open_Date
having count(*)>1
--Changing date column
ALTER TABLE sales
ADD new_date_column DATE;
UPDATE sales
SET new_date_column = TRY_CONVERT(DATE,Date,101)
--CONVERTS THE DATE INTO NEW DATE COLUMN.


SELECT * FROM Sales


--                PRODUCT PERFORMANCE ANALYSIS
--Identify top performing products based on total sales and profit.
CREATE TABLE NewTable (
    Product_Name VARCHAR(255),
    Total_Profit DECIMAL(10, 2),
    UNITSSOLD INT
);
INSERT INTO NewTable (Product_Name, Total_Profit, UNITSSOLD)
SELECT Product_Name,SUM((Product_Price-Product_Cost)*Units) AS Total_Profit,SUM(Units) AS UNITSSOLD
 FROM products
 JOIN sales
  ON  products.Product_ID = Sales.Product_ID
  GROUP BY products.Product_Id,Product_Name
  ORDER BY Total_Profit DESC,UNITSSOLD DESC
SELECT * FROM NewTable
  ----


  --          STORE PERFORMANCE ANALYSIS
--Analyse sales performance for each store,including total revenue and profit margin.
CREATE TABLE NewTable2 (
    Store_ID INT,
    Store_Name VARCHAR(255),
    Total_revenue DECIMAL(12, 2),
    Profit_margin DECIMAL(12, 2)
);
INSERT INTO NewTable2 (Store_ID, Store_Name, Total_revenue, Profit_margin)
SELECT 
    Sales.Store_ID,
    Stores.Store_Name,
    SUM(Sales.Units * Products.Product_Price) AS Total_revenue,
    SUM((Products.Product_Price - Products.Product_Cost) * Sales.Units) AS Profit_margin
FROM 
    Sales
JOIN 
    Products ON Sales.Product_ID = Products.Product_ID
JOIN 
    Stores ON Sales.Store_ID = Stores.Store_ID
GROUP BY 
    Sales.Store_ID, Stores.Store_Name
ORDER BY 
    Total_revenue DESC, Profit_margin DESC;
SELECT * FROM NewTable2


--                   CUMULATIVE DISTRIBUTION OF PROFIT MARGIN
--Calcualate the cumulative distribution of profit margin for each product category ,consider where the products are having profit.
CREATE TABLE NewTable3 (
    Store_Name VARCHAR(255),
    Store_location VARCHAR(255),
    Product_Name VARCHAR(255),
    Profit_per_location DECIMAL(12, 2)

);
INSERT INTO NewTable3 (Store_Name, Store_location, Product_Name, Profit_per_location)
SELECT Store_Name, Store_location, Product_Name, SUM((Product_Price - Product_Cost) * Units) AS Profit_per_location
FROM Stores
JOIN Sales ON Stores.Store_ID = Sales.Store_ID
JOIN Products ON Sales.Product_ID = Products.Product_ID
GROUP BY Store_Name,Store_location, Product_Name,Product_Category
ORDER BY Profit_per_location DESC;
---
SELECT * FROM NewTable3



--                   STORE INVENTORY TURNOVER ANALYSIS
--Analyse the efficiency of inventory turnover for each store by calculating the inventory turnover ratio.
--
CREATE TABLE NewTable4 (
    Store_Name VARCHAR(255),
    Inventory_Turnover_Ratio DECIMAL(12, 2)
);
INSERT INTO NewTable4 (Store_Name, Inventory_Turnover_Ratio)

SELECT 
    Store_Name,
    SUM(
        CASE 
            WHEN Stock_On_Hand = 0 THEN 0 
            ELSE ((Product_Price * Units)*2 / NULLIF(Stock_On_Hand, 0)) 
        END
    ) AS Inventory_Turnover_Ratio
FROM 
    stores
	--STOCK ON HAND IS 0 THEN INVENTORY TURNOVER RATIO IS 0;ELSE FORMULA,IF NULL THEN NULL WILL BE RETURNED
JOIN 
    sales ON stores.Store_ID = sales.Store_ID
JOIN 
    products ON sales.product_id = products.Product_ID
JOIN 
    inventory ON inventory.Product_ID = sales.Product_ID
GROUP BY 
    Store_Name;

SELECT * FROM NewTable4



--             COMPLEX MONTHLY SALES TREND ANALYSIS
--
--Examine monthly sales trends,considering the rolling 3-month average and identifying months with significant growth or decline
--TOTAL UNITS SOLD PER MONTH
CREATE TABLE RollingAverageResults (
    month_start DATE,
    total_units INT,
    trend VARCHAR(255)
);
WITH MonthlySales AS (
    SELECT
        DATEADD(MONTH, DATEDIFF(MONTH, 0, s.new_date_column), 0) AS month_start,
		--DATEDIFF TAKES OUT THE NUMBER OF MONTHS FROM BASE 0,
		--DATEADD WILL ADD ON MONTH BASIS
        SUM(s.units) AS total_units
    FROM
        sales s
    GROUP BY
        DATEADD(MONTH, DATEDIFF(MONTH, 0, s.new_date_column), 0)
),
--GROUPS BY DATE EACH MONTH
--DATEADD AND DATEDIFF IS STRIPPING THE DATES TRUNCATES THE DATE OF THE MONTH RESULT STORED IN MONTHLY SALES 
RollingAverage AS (
    SELECT
        month_start,
        total_units,
        AVG(total_units) OVER (
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
			--CREATES A WINDOW FOR PRCEEDING 2 MONTHS AND CURRENT MONTH
        ) AS three_month_avg
    FROM
        MonthlySales
)
--CALCULATES THE ROLLING AVERAGE PER MONTH,ROWS BETWEEN 2 PRECEEDING AND CURRENT ROW SPECIFIES THE WINDOW FRAME BETWEEN CURRENT ROW AND 2 PRECEEDING.
--RESULT STORED IN ROLLING AVERAGE
INSERT INTO RollingAverageResults (month_start, total_units, trend)
SELECT
    month_start AS month,
    total_units,
    CASE
        WHEN three_month_avg > 0 AND total_units > 1.5 * three_month_avg THEN 'Significant Growth'
        WHEN three_month_avg > 0 AND total_units < 0.5 * three_month_avg THEN 'Significant Decline'
        ELSE 'Normal'
    END AS trend
FROM
    RollingAverage;
SELECT *  FROM RollingAverageResults



create table t1(dates VARCHAR(20))
insert into t1 values('2004-04-05'),('06-14-2008'),('08-19-2010')
UPDATE t1
SET dates = 
    CASE
        -- Check if the date is in 'yyyy-mm-dd' format
        WHEN ISDATE(dates) = 1 AND dates LIKE '____-__-__' THEN CONVERT(DATE, dates, 23)
        -- Check if the date is in 'mm-dd-yyyy' format
        WHEN ISDATE(dates) = 1 AND dates LIKE '__-__-____' THEN CONVERT(DATE, dates, 101)
        -- Handle any other cases where the date format is unknown or invalid
        ELSE NULL -- or any default value or action you want
    END
WHERE ISDATE(dates) = 1
select * from t1
CREATE TABLE t2(num VARCHAR(20))
INSERT INTO T2 VALUES('4UD8'),('8HU9'),('90IO')

SELECT dbo.RemoveNonNumericCharacters2(num) AS CleanedValue
FROM t2;


CREATE FUNCTION RemoveNonNumericCharacters2
(
    @inputString VARCHAR(100)
)
RETURNS VARCHAR(100)
AS
BEGIN
    DECLARE @cleanedString VARCHAR(100) = '';
    DECLARE @index INT = 1;
    DECLARE @char CHAR(1);

    WHILE @index <= LEN(@inputString)
    BEGIN
        SET @char = SUBSTRING(@inputString, @index, 1);
        
        IF @char LIKE '[0-9]'
        BEGIN
            SET @cleanedString = @cleanedString + @char;
        END

        SET @index = @index + 1;
    END

    RETURN @cleanedString;
END;

UPDATE t2
SET num = dbo.RemoveNonNumericCharacters2(num);

-- Step 2: Alter the Column Type
-- Alter the column type to NUMERIC after cleaning the data
ALTER TABLE t2
ALTER COLUMN num NUMERIC(18, 2); -- Adjust precision and scale as needed

 select * from t2
 DROP TABLE T1
DROP TABLE t2
DROP FUNCTION dbo.RemoveNonNumericCharacters2
--
declare @char VARCHAR(20)='PYTHON'
DECLARE @index INT=1
DECLARE @OUTPUT CHAR(1)
WHILE @index <=LEN(@char)
BEGIN
SET @OUTPUT= SUBSTRING(@char,@index,1)
print(@OUTPUT)
SET @index=@index +1
END
--