/*Story - The Mystery of the Declining Sales */ 

/* AdventureWorks has been experiencing a decline in sales, and the CEO has tasked the data team to uncover the reasons. 
The data team suspects regional performance, product trends, and customer behavior are involved. */

-----------------------------------------------------------------------------------------------------------------------------

/* Assumptions*/
/* 1. The data ranges from the year 2011 to 2014. Hence We assume that the current year is 2014 */

-----------------------------------------------------------------------------------------------------------------------------

/*Questions */

/* 1. Which region recorded the highest sales in the year 2014? */
SELECT 
    st.Name AS Region,
    SUM(soh.TotalDue) AS TotalSales
FROM 
    [Sales].[SalesOrderHeader] AS soh
JOIN 
    [Sales].[SalesTerritory] AS st ON soh.TerritoryID = st.TerritoryID
WHERE 
    YEAR(soh.OrderDate) = '2014'
GROUP BY 
    st.Name
ORDER BY 
    TotalSales DESC;

/* Answer: Highest sales are recorded in Southwest Region of North America */

-----------------------------------------------------------------------------------------------------------------------------

/* 2. Has any product category seen a consistent decline in sales over the past three years? */

SELECT 
    pc.Name AS ProductCategory,
    ROUND(SUM(CASE WHEN YEAR(soh.OrderDate) = '2012' THEN sod.LineTotal ELSE 0 END),0) AS TotalSalesFor2012,
    ROUND(SUM(CASE WHEN YEAR(soh.OrderDate) = '2013' THEN sod.LineTotal ELSE 0 END),0) AS TotalSalesFor2013,
    ROUND(SUM(CASE WHEN YEAR(soh.OrderDate) = '2014' THEN sod.LineTotal ELSE 0 END),0) AS TotalSalesFor2014
FROM 
    [Sales].[SalesOrderDetail] AS sod
JOIN 
    [Production].[Product] AS p ON sod.ProductID = p.ProductID
JOIN 
    [Production].[ProductSubcategory] AS psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
JOIN 
    [Production].[ProductCategory] AS pc ON psc.ProductCategoryID = pc.ProductCategoryID
JOIN 
    [Sales].[SalesOrderHeader] AS soh ON sod.SalesOrderID = soh.SalesOrderID
GROUP BY 
    pc.Name
ORDER BY 
    pc.Name;

/* Answer: Since we have only 3 years of data with us it is hard to conclude any pattern. 
However, There is steep increase in total sales in the year 2013 compare to the year 2012. 
While there is a plummet in total sales for all there product categories in the year 2014 compared to the year 2013. */

-----------------------------------------------------------------------------------------------------------------------------

/* 3. Which sales representatives failed to meet their quarterly targets this year(2014)? */ 

SELECT 
    --sp.BusinessEntityID,
    CONCAT(p.FirstName, ' ', p.LastName) AS SalesRepName,
    st.Quarter,
    SUM(soh.TotalDue) AS TotalSales
FROM 
    [Sales].[SalesOrderHeader] AS soh
JOIN 
    [Sales].[SalesPerson] AS sp ON soh.SalesPersonID = sp.BusinessEntityID
JOIN 
    [Person].[Person] AS p ON sp.BusinessEntityID = p.BusinessEntityID
CROSS APPLY 
    (SELECT DATEPART(QUARTER, soh.OrderDate) AS Quarter) AS st
WHERE 
    YEAR(soh.OrderDate) = '2014'
GROUP BY 
    --sp.BusinessEntityID, 
	CONCAT(p.FirstName, ' ', p.LastName), st.Quarter
HAVING 
    SUM(soh.TotalDue) < 100000; --  100000 USD is assumed as the target threshold

/* Answer: We have 3 sales representatives - Stephen Jiang, Syed Abbas, and Amy Alberts who didn't meet their targets for the year 2014 */

-----------------------------------------------------------------------------------------------------------------------------

/* Are there customers who have not made any purchases in the last six months(Max date in 2014 - 6 months)? */

WITH LastSixMonthsOrders AS (
    SELECT CustomerID
    FROM [Sales].[SalesOrderHeader]
    WHERE OrderDate >= DATEADD(MONTH, -6, (SELECT MAX(OrderDate) FROM [Sales].[SalesOrderHeader]))
)
SELECT 
    distinct c.CustomerID,
    CONCAT(p.FirstName, ' ', p.LastName) AS CustomerName
FROM 
    [Sales].[Customer] AS c
JOIN 
    [Person].[Person] AS p ON c.PersonID = p.BusinessEntityID
WHERE 
    NOT EXISTS (
        SELECT 1
        FROM LastSixMonthsOrders lso
        WHERE lso.CustomerID = c.CustomerID
    );

/* Answer: We have 8,657 customers who didn't make any purchase in the last months. 
Note : Here today is considered as June 30, 2014 as that was the last day an order was captured in the database.
Hence we are considering from January 1, 2014 of those customers who didn't make any purchase */ 

-----------------------------------------------------------------------------------------------------------------------------

/* 5. What are the top 5 products by sales volume this year, and how do they compare to last year's performance? */

WITH ProductSales AS (
    SELECT 
        p.Name AS Product,
        YEAR(soh.OrderDate) AS Year,
        SUM(sod.OrderQty) AS TotalSalesVolume
    FROM 
        [Sales].[SalesOrderDetail] AS sod
    JOIN 
        [Production].[Product] AS p ON sod.ProductID = p.ProductID
    JOIN 
        [Sales].[SalesOrderHeader] AS soh ON sod.SalesOrderID = soh.SalesOrderID
    WHERE 
        YEAR(soh.OrderDate) IN ('2013', '2014')
    GROUP BY 
        p.Name, YEAR(soh.OrderDate)
)
SELECT 
    ps1.Product,
    ps1.TotalSalesVolume AS QtySalesThisYear,
    ps2.TotalSalesVolume AS QtySalesLastYear
FROM 
    ProductSales ps1
LEFT JOIN 
    ProductSales ps2 ON ps1.Product = ps2.Product AND ps2.Year = '2013'
WHERE 
    ps1.Year = '2014'
ORDER BY 
    ps1.TotalSalesVolume DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;

/* Answer: The top 5 products that contributed to high orderquantity are 
Water Bottle - 30 oz., AWC Logo Cap, Sport-100 Helmet, Blue Patch Kit/8 Patches, Sport-100 Helmet, Red */

-----------------------------------------------------------------------------------------------------------------------------

/* 6. Is there a correlation between discounts offered and sales performance? */

SELECT 
    pc.Name AS ProductCategory,
    ROUND(AVG(sod.LineTotal), 2) AS AverageSales,
    ROUND(AVG(sod.LineTotal * (1 - sod.UnitPriceDiscount)), 2) AS AverageDue,
    ROUND(AVG(sod.LineTotal * sod.UnitPriceDiscount), 2) AS AverageDiscount
FROM 
    [Sales].[SalesOrderDetail] AS sod
JOIN 
    [Production].[Product] AS p ON sod.ProductID = p.ProductID
JOIN 
    [Production].[ProductSubcategory] AS psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
JOIN 
    [Production].[ProductCategory] AS pc ON psc.ProductCategoryID = pc.ProductCategoryID
GROUP BY 
    pc.Name
ORDER BY 
    pc.Name;

/* Note : ROUND(AVG(sod.LineTotal * (1 - sod.UnitPriceDiscount)), 2) AS AverageDue
		  sod.UnitPriceDiscount is the discount rate applied to the item (e.g., 0.1 for a 10% discount).
		  (1 - sod.UnitPriceDiscount) gives the proportion of the price that is actually due (e.g., 0.9 for a 10% discount).
		  sod.LineTotal * (1 - sod.UnitPriceDiscount) calculates the amount due after applying the discount.

		  ROUND(AVG(sod.LineTotal * sod.UnitPriceDiscount), 2) AS AverageDiscount
		  sod.LineTotal * sod.UnitPriceDiscount calculates the actual discount amount for each line item.
*/

/* Answer: More discounts are offered on those products that cost more and are sold more */

-----------------------------------------------------------------------------------------------------------------------------

/* 7. Which region has the highest number of returned orders, and what is the financial impact? */

SELECT 
    st.Name AS Region,
    COUNT(*) AS NumberOfReturns,
    SUM(sod.LineTotal) AS TotalReturnCost
FROM 
    [Production].[TransactionHistory] AS th
JOIN 
    [Sales].[SalesOrderDetail] AS sod ON th.ReferenceOrderID = sod.SalesOrderID
JOIN 
    [Sales].[SalesOrderHeader] AS soh ON sod.SalesOrderID = soh.SalesOrderID
JOIN 
    [Sales].[SalesTerritory] AS st ON soh.TerritoryID = st.TerritoryID
WHERE 
    th.TransactionType = 'R' -- 'R' for returns
GROUP BY 
    st.Name
ORDER BY 
    NumberOfReturns DESC;

/* Answer: There are no returns filed for any region and any date */

-----------------------------------------------------------------------------------------------------------------------------

/* 8. How has the sales channel (online vs. in-store) contributed to the declining sales trend? */

SELECT 
    CASE 
        WHEN soh.OnlineOrderFlag = 1 THEN 'Online'
        ELSE 'In-Store'
    END AS SalesChannel,
    YEAR(soh.OrderDate) AS Year,
    SUM(soh.TotalDue) AS TotalSales
FROM 
    [Sales].[SalesOrderHeader] AS soh
WHERE 
    YEAR(soh.OrderDate) BETWEEN '2012' and '2014'
GROUP BY 
    CASE 
        WHEN soh.OnlineOrderFlag = 1 THEN 'Online'
        ELSE 'In-Store'
    END, 
    YEAR(soh.OrderDate)
ORDER BY 
    Year, SalesChannel;

/* Answer: All the 3 consecutive years, highest sales are recorded from In-stores only */

-----------------------------------------------------------------------------------------------------------------------------

/* 9. What is the overall customer retention rate, and how has it changed over the years? */

WITH CustomerYearlyData AS (
    SELECT 
        c.CustomerID,
        YEAR(soh.OrderDate) AS Year,
        COUNT(DISTINCT soh.SalesOrderID) AS OrderCount
    FROM 
        [Sales].[Customer] AS c
    JOIN 
        [Sales].[SalesOrderHeader] AS soh ON c.CustomerID = soh.CustomerID
    GROUP BY 
        c.CustomerID, YEAR(soh.OrderDate)
),
RetentionRate AS (
    SELECT 
        cy1.Year AS CurrentYear,
        COUNT(DISTINCT cy1.CustomerID) AS TotalCustomers,
        COUNT(DISTINCT cy2.CustomerID) AS RetainedCustomers
    FROM 
        CustomerYearlyData cy1
    LEFT JOIN 
        CustomerYearlyData cy2 
        ON cy1.CustomerID = cy2.CustomerID AND cy1.Year = cy2.Year - 1
    GROUP BY 
        cy1.Year
)
SELECT 
    CurrentYear,
    TotalCustomers,
    RetainedCustomers,
    CASE 
        WHEN TotalCustomers > 0 THEN CAST(RetainedCustomers AS FLOAT) / TotalCustomers * 100
        ELSE 0
    END AS RetentionRate
FROM 
    RetentionRate
ORDER BY 
    CurrentYear;

/* Retention rate was 56% in the year 2013 and Churn was the highest in 85% in the year 2011 */

/* Here's the result story : 
It’s 2014, and AdventureWorks is dealing with a big drop in sales. 
The Southwest region of North America is still doing well, with the highest sales among all regions. 
But overall, things don’t look good. 
Sales improved a lot in 2013 compared to 2012, but in 2014, sales have gone down for all product categories.  
Even top sales reps like Stephen Jiang, Syed Abbas, and Amy Alberts didn’t hit their targets this year. 
On top of that, more than 8,600 customers haven’t bought anything in 2014, with the last recorded orders being on June 30.  
Some products have sold well, like the Water Bottle - 30 oz., AWC Logo Cap, Sport-100 Helmets (Blue and Red), and the Blue Patch Kit. 
The company has been offering bigger discounts on the more expensive and popular products, which might boost short-term sales but could hurt profits later.  
Interestingly, there haven’t been any product returns recorded for any region or date. 
For all three years, in-store sales have been the top performer, showing that physical stores still bring in the most business.  
The customer trends are also clear. 
Retention was 56% in 2013, but the company remembers the tough times in 2011 when 85% of customers stopped buying. 
As AdventureWorks looks ahead, the data not only highlights the problems but also points out areas where they can improve and grow. 
*/