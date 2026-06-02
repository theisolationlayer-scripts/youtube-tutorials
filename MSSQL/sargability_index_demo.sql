/*******************************************************************************
  THE ISOLATION LAYER - www.youtube.com/@theisolationlayer
  Setup demo data and illustrate sargability - index seek versus scan

  IMPORTANT: Always test scripts in a development/staging environment before 
  running in production. The author is not responsible for any impact, data 
  loss, or downtime resulting from the use of this script.
*******************************************************************************/

USE MARKETING;
GO

-- 1. Drop existing tables if re-running
IF OBJECT_ID('Sales.Orders', 'U') IS NOT NULL DROP TABLE Sales.Orders;
--IF OBJECT_ID('Sales.Customers', 'U') IS NOT NULL DROP TABLE Sales.Customers;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Sales')
BEGIN
    -- Dynamic SQL allows us to bypass the "CREATE SCHEMA must be the first statement in a batch" rule
    EXEC('CREATE SCHEMA Sales;');
END
GO

CREATE TABLE Sales.Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME NOT NULL,
    OrderTotal DECIMAL(18,2) NOT NULL,
    OrderStatus VARCHAR(20) NOT NULL
);
GO

-- Generate random dates between 2021-01-01 and 2025-12-31
WITH DateGenerator AS (
    SELECT 
        TOP 100000
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum,
        CAST(ABS(CHECKSUM(NEWID())) % 1000 + 1 AS INT) AS RandomCustomerID,
        DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 1825, '2021-01-01') AS RandomDate,
        CAST(ABS(CHECKSUM(NEWID())) % 500 + 5.50 AS DECIMAL(18,2)) AS RandomTotal
    FROM sys.all_columns a CROSS JOIN sys.all_columns b
)
INSERT INTO Sales.Orders (CustomerID, OrderDate, OrderTotal, OrderStatus)
SELECT 
    RandomCustomerID,
    RandomDate,
    RandomTotal,
    CASE WHEN RowNum % 10 = 0 THEN 'Pending' ELSE 'Shipped' END
FROM DateGenerator;
GO

-- 4. Create the Non-Clustered Index we want to test
CREATE NONCLUSTERED INDEX IX_Orders_OrderDate 
ON Sales.Orders (OrderDate) 
INCLUDE (OrderTotal);
GO

-- ❌ THE NON-SARGABLE WAY (Index Scan)
-- The engine must evaluate the YEAR() function for all 100,000 rows.
SELECT OrderID, OrderDate, OrderTotal
FROM Sales.Orders
WHERE YEAR(OrderDate) = 2024;

--  THE SARGABLE WAY (Index Seek)
-- Using a literal boundary allows the engine to jump straight to the data range.
SELECT OrderID, OrderDate, OrderTotal
FROM Sales.Orders
WHERE OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01';


-- Let's quickly add an index on Status for this test
CREATE NONCLUSTERED INDEX IX_Orders_Status ON Sales.Orders (OrderStatus);
GO

-- ❌ THE NON-SARGABLE WAY (Index Scan / Full Scan)
-- Wrapping the column in LEFT() forces an evaluation on every row.
SELECT OrderID, OrderStatus 
FROM Sales.Orders
WHERE LEFT(OrderStatus, 3) = 'Pen';

--  THE SARGABLE WAY (Index Seek)
-- A trailing wildcard allows standard B-Tree navigation.
SELECT OrderID, OrderStatus
FROM Sales.Orders
WHERE OrderStatus LIKE 'Pen%'; 
