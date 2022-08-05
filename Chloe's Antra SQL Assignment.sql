-- Chloe's Assignment

--1

USE WideWorldImporters;

WITH 
	cte_company_number (PersonID, FullName, FaxNumber, PhoneNumber, company_FaxNumber, company_PhoneNumber)
	AS
	(
		SELECT 
			p.PersonID,
			p.FullName,
			p.FaxNumber,
			p.PhoneNumber,
			s.FaxNumber,
			s.PhoneNumber
		FROM Application.People p
		JOIN Purchasing.Suppliers s
		ON p.PersonID = s.PrimaryContactPersonID or p.PersonID = s.AlternateContactPersonID
		UNION
		SELECT 
			p.PersonID,
			p.FullName,
			p.FaxNumber,
			p.PhoneNumber,
			c.FaxNumber,
			c.PhoneNumber
		FROM Application.People p
		JOIN Sales.Customers c
		ON p.PersonID = c.PrimaryContactPersonID or p.PersonID = c.AlternateContactPersonID
		WHERE p.FullName != c.CustomerName
	)
SELECT
	p.FullName,
	p.FaxNumber,
	p.PhoneNumber,
	temp.company_FaxNumber,
	temp.company_PhoneNumber
FROM Application.People p
LEFT JOIN cte_company_number temp
ON p.PersonID = temp.PersonID
ORDER BY p.PersonID
OFFSET 1 ROWS;

--2
SELECT
	c.CustomerName
FROM Sales.Customers c
LEFT JOIN Application.People p
ON c.PrimaryContactPersonID = p.PersonID
WHERE c.PhoneNumber = p.PhoneNumber AND
	c.CustomerName != p.FullName;

--3
WITH sales_before_2016
	AS
	(
		SELECT DISTINCT
			CustomerID
		FROM Sales.Invoices
		WHERE InvoiceDate < '2016-01-01'
	)
SELECT cte.CustomerID
FROM sales_before_2016 cte
WHERE cte.CustomerID NOT IN (
	SELECT DISTINCT
		CustomerID
	FROM Sales.Invoices
	WHERE InvoiceDate >= '2016-01-01');

--4
WITH cte_ID_quantity
	AS
	(
		SELECT 
			sit.StockItemID,
			SUM(sit.Quantity) AS total_quantity
		FROM Purchasing.PurchaseOrders po
		LEFT JOIN Warehouse.StockItemTransactions sit
		ON po.PurchaseOrderID = sit.PurchaseOrderID
		WHERE YEAR(po.OrderDate) = 2013
		GROUP BY StockItemID
	)
SELECT
	si.StockItemName,
	cte.total_quantity AS total_quantity
FROM cte_ID_quantity cte
JOIN Warehouse.StockItems si
ON cte.StockItemID = si.StockItemID
ORDER BY total_quantity DESC;

--5
SELECT DISTINCT si.StockItemName
FROM Warehouse.StockItems si
JOIN Sales.OrderLines ol
ON si.StockItemID = ol.StockItemID
WHERE LEN(ol.Description) >= 10
ORDER BY StockItemName;

--6
WITH cte_stockitem_city
	AS
	(
		SELECT 
			sit.StockItemID,
			c.DeliveryCityID
		FROM Warehouse.StockItemTransactions sit
		JOIN Sales.Customers c
		ON sit.customerID = c.CustomerID
		WHERE YEAR(sit.TransactionOccurredWhen) = 2014
	),
	cte_city_state
	AS
	(
		SELECT
			CityID,
			StateProvinceName
		FROM Application.Cities c
		JOIN Application.StateProvinces sp
		ON c.StateProvinceID = sp.StateProvinceID
	)
SELECT DISTINCT si.StockItemName
FROM cte_stockitem_city csc
JOIN cte_city_state ccs
ON csc.DeliveryCityID = ccs.CityID
JOIN Warehouse.StockItems si
ON csc.StockItemID = si.StockItemID
WHERE ccs.StateProvinceName = 'Alabama' OR
	ccs.StateProvinceName = 'Georgia';

--7
WITH cte_order_day
	AS
	(
		SELECT
			o.CustomerID,
			o.OrderID,
			DATEDIFF(DAY, o.OrderDate, CONVERT(date, i.ConfirmedDeliveryTime)) AS processing_days
		FROM Sales.Invoices i
		JOIN Sales.Orders o
		ON i.OrderID = o.OrderID
	),
	cte_customer_state
	AS
	(
		SELECT
			cus.CustomerID,
			sp.StateProvinceName
		FROM Sales.Customers cus
		JOIN Application.Cities cit
		ON cus.DeliveryCityID = cit.CityID
		JOIN Application.StateProvinces sp
		ON cit.StateProvinceID = sp.StateProvinceID
	)
SELECT 
	ccs.StateProvinceName,
	AVG(cod.processing_days) AS avg_processing_day
FROM cte_order_day cod
JOIN cte_customer_state ccs
ON cod.CustomerID = ccs.CustomerID
GROUP BY StateProvinceName;

--8
WITH order_month
	AS
	(
		SELECT
			o.CustomerID,
			o.OrderID,
			MONTH(o.OrderDate) AS month,
			DATEDIFF(DAY, o.OrderDate, CONVERT(date, i.ConfirmedDeliveryTime)) AS processing_days
		FROM Sales.Invoices i
		JOIN Sales.Orders o
		ON i.OrderID = o.OrderID
	),
	order_state
	AS
	(
		SELECT
			cus.CustomerID,
			sp.StateProvinceName
		FROM Sales.Customers cus
		JOIN Application.Cities cit
		ON cus.DeliveryCityID = cit.CityID
		JOIN Application.StateProvinces sp
		ON cit.StateProvinceID = sp.StateProvinceID
	)
SELECT 
	os.StateProvinceName,
	om.month,
	AVG(om.processing_days) AS avg_processing_day
FROM order_month om
JOIN order_state os
ON om.CustomerID = os.CustomerID
GROUP BY StateProvinceName, om.month
ORDER BY StateProvinceName, om.month;

--9
SELECT
	si.StockItemName
FROM Warehouse.StockItemTransactions sit
JOIN Warehouse.StockItems si
ON sit.StockItemID = si.StockItemID
WHERE YEAR(sit.TransactionOccurredWhen) = 2015
GROUP BY sit.StockItemID, si.StockItemName
HAVING SUM(Quantity) >= 0;

--10
WITH item_order
	AS
	(
		SELECT
			i.CustomerID,
			SUM(ABS(sit.Quantity)) AS quantity
		FROM Sales.Invoices i
		JOIN Warehouse.StockItemTransactions sit
		ON i.InvoiceID = sit.InvoiceID
		JOIN Sales.Orders o
		ON i.OrderID = o.OrderID
		WHERE YEAR(o.OrderDate) = 2016 AND
			sit.StockItemID IN (
				SELECT
					StockItemID
				FROM Warehouse.StockItems si
				WHERE StockItemName LIKE '%mug%')
		GROUP BY i.CustomerID
		HAVING SUM(ABS(sit.Quantity)) <= 10
	)
SELECT
	c.CustomerName,
	c.PhoneNumber,
	p.FullName AS primary_contact_name
FROM item_order io
JOIN Sales.Customers c
ON c.CustomerID = io.CustomerID
JOIN Application.People p
ON c.PrimaryContactPersonID = p.PersonID;

--11
SELECT
	CityName
FROM Application.Cities
WHERE ValidFrom > '2015-01-01';

--12
WITH order_detail
	AS
	(
		SELECT
			s.StockItemName,
			o.CustomerID,
			ol.Quantity
		FROM Sales.Orders o
		JOIN Sales.OrderLines ol
		ON o.OrderID = ol.OrderID
		JOIN Warehouse.StockItems s
		ON ol.StockItemID = s.StockItemID
		WHERE o.OrderDate = '2014-07-01'
	),
	customer_detail
	AS
	(
		SELECT
			cust.CustomerID,
			cust.CustomerName,
			p.FullName AS customer_contact_name,
			cust.PhoneNumber,
			cust.DeliveryAddressLine1,
			cust.DeliveryAddressLine2,
			citi.StateProvinceID,
			citi.CityName
		FROM Sales.Customers cust
		JOIN Application.People p
		ON cust.PrimaryContactPersonID = p.PersonID
		JOIN Application.Cities citi
		ON cust.DeliveryCityID = citi.CityID
	)
SELECT
	od.StockItemName,
	cd.DeliveryAddressLine1,
	cd.DeliveryAddressLine2,
	sp.StateProvinceName,
	cd.CityName,
	cou.CountryName,
	cd.CustomerName,
	cd.customer_contact_name,
	cd.PhoneNumber AS customer_phone,
	od.Quantity
FROM order_detail od
JOIN customer_detail cd
ON od.CustomerID = cd.CustomerID
JOIN Application.StateProvinces sp
ON cd.StateProvinceID = sp.StateProvinceID
JOIN Application.Countries cou
ON sp.CountryID = cou.CountryID;

--13
WITH stock_sold
	AS
	(
		SELECT
			sg.StockGroupName,
			sg.StockGroupID,
			sis.StockItemID,
			ABS(SUM(sit.Quantity)) AS quantity_sold
		FROM Warehouse.StockItemTransactions sit
		JOIN Warehouse.StockItemStockGroups sis
		ON sit.StockItemID = sis.StockItemID
		JOIN Warehouse.StockGroups sg
		ON sis.StockGroupID = sg.StockGroupID
		WHERE sit.SupplierID IS NULL
		GROUP BY StockGroupName, sg.StockGroupID, sis.StockItemID
	),
	stock_purchased
	AS
	(
		SELECT
			sg.StockGroupName,
			sg.StockGroupID,
			sis.StockItemID,
			SUM(sit.Quantity) AS quantity_purchased
		FROM Warehouse.StockItemTransactions sit
		JOIN Warehouse.StockItemStockGroups sis
		ON sit.StockItemID = sis.StockItemID
		JOIN Warehouse.StockGroups sg
		ON sis.StockGroupID = sg.StockGroupID
		WHERE sit.CustomerID IS NULL
		GROUP BY StockGroupName, sg.StockGroupID, sis.StockItemID
	),
	stock_per_group
	AS
	(
		SELECT
			sisg.StockGroupID,
			SUM(sih.QuantityOnHand) AS stock_quantity
		FROM Warehouse.StockItemStockGroups sisg
		JOIN Warehouse.StockItemHoldings sih
		ON sisg.StockItemID = sih.StockItemID
		GROUP BY sisg.StockGroupID
	)
SELECT
	ss.StockGroupName,
	SUM(ss.quantity_sold) AS quantity_sold,
	SUM(sp.quantity_purchased) AS quantity_purchased,
	SUM(sp.quantity_purchased - ss.quantity_sold) AS remaining_stock_quantity
FROM stock_per_group spg
JOIN stock_sold ss
ON spg.StockGroupID = ss.StockGroupID
JOIN stock_purchased sp
ON ss.StockItemID = sp.StockItemID
GROUP BY ss.StockGroupName;

--14
WITH cte1
	AS
	(
		SELECT
			c.DeliveryCityID,
			sit.StockItemID,
			DENSE_RANK() OVER(PARTITION BY c.DeliveryCityID ORDER BY SUM(ABS(sit.Quantity)) DESC) AS q_rank
		FROM Warehouse.StockItemTransactions sit
		RIGHT JOIN Sales.Customers c
		ON sit.CustomerID = c.CustomerID
		WHERE YEAR(sit.TransactionOccurredWhen) = 2016
		GROUP BY c.DeliveryCityID, sit.StockItemID
	),
	cte2
	AS
	(
		SELECT
			cte1.DeliveryCityID,
			cte1.StockItemID,
			cte1.q_rank
		FROM cte1
		WHERE q_rank = 1
	),
	cte3 
	AS
	(
		SELECT
			Cities.CityID,
			StateProvinces.CountryID,
			StateProvinces.StateProvinceName,
			Cities.CityName
		FROM Application.Cities
		JOIN Application.StateProvinces
		ON Cities.StateProvinceID = StateProvinces.StateProvinceID
		WHERE StateProvinces.CountryID = 230
	)
SELECT DISTINCT
	cte3.StateProvinceName,
	cte3.CityName,
	CASE
		WHEN si.StockItemName IS NULL THEN 'No Sales'
		ELSE si.StockItemName
	END AS most_delivered_stockitem
FROM cte3
LEFT JOIN cte2
ON cte3.CityID = cte2.DeliveryCityID
LEFT JOIN Warehouse.StockItems si
ON cte2.StockItemID = si.StockItemID
ORDER BY StateProvinceName, CityName;

--15
SELECT OrderID
FROM Sales.Invoices
WHERE JSON_QUERY(ReturnedDeliveryData, '$.Events[1]') IS NOT NULL AND 
	JSON_QUERY(ReturnedDeliveryData, '$.Events[2]') IS NOT NULL

--16
SELECT
	si.StockItemName
FROM Warehouse.StockItems si
WHERE JSON_VALUE(CustomFields, '$.CountryOfManufacture') = 'China';

--17
SELECT
	JSON_VALUE(si.CustomFields, '$.CountryOfManufacture') AS country_of_manufacture,
	SUM(ol.Quantity) AS total_quantity
FROM Sales.OrderLines ol
JOIN Warehouse.StockItems si
ON ol.StockItemID = si.StockItemID
JOIN Sales.Orders o
ON ol.OrderID = o.OrderID
WHERE YEAR(o.OrderDate) = 2015
GROUP BY JSON_VALUE(si.CustomFields, '$.CountryOfManufacture');

--18
GO
CREATE VIEW [total_quantity_sold_by_stockgroup_2013_2017] AS
SELECT
	StockGroupName,
	[2013],
	[2014],
	[2015],
	[2016],
	[2017]
FROM
(SELECT
	sg.StockGroupName,
	YEAR(o.OrderDate) AS year_of_order,
	ol.Quantity
FROM Sales.Orders o
JOIN Sales.OrderLines ol
ON o.OrderID = ol.OrderID
JOIN Warehouse.StockItemStockGroups sisg
ON ol.StockItemID = sisg.StockItemID
JOIN Warehouse.StockGroups sg
ON sisg.StockGroupID = sg.StockGroupID) AS source_table
PIVOT
(
SUM(Quantity)
FOR year_of_order IN
([2013], [2014],[2015], [2016], [2017])
) AS pvt
GO

--19
DECLARE
	@stockgroups NVARCHAR(MAX) = '';
SELECT
	@stockgroups += QUOTENAME(StockGroupName) + ','
FROM Warehouse.StockGroups
ORDER BY StockGroupName;

SET @stockgroups = LEFT(@stockgroups, LEN(@stockgroups) - 1)
PRINT @stockgroups;

GO
CREATE VIEW [total_quantity_sold_per_stockgroup_2013_2017] AS
SELECT
	year_of_order,
	[Airline Novelties],
	[Clothing],
	[Computing Novelties],
	[Furry Footwear],
	[Mugs],
	[Novelty Items],
	[Packaging Materials],
	[Toys],
	[T-Shirts],
	[USB Novelties]
FROM
(SELECT
	sg.StockGroupName,
	YEAR(o.OrderDate) AS year_of_order,
	ol.Quantity
FROM Sales.Orders o
JOIN Sales.OrderLines ol
ON o.OrderID = ol.OrderID
JOIN Warehouse.StockItemStockGroups sisg
ON ol.StockItemID = sisg.StockItemID
JOIN Warehouse.StockGroups sg
ON sisg.StockGroupID = sg.StockGroupID) AS source_table
PIVOT
(
SUM(Quantity)
FOR StockGroupName IN
([Airline Novelties],[Clothing],[Computing Novelties],[Furry Footwear],
	[Mugs],[Novelty Items],[Packaging Materials],[Toys],[T-Shirts],[USB Novelties])
) AS pvt
GO

--20
GO
CREATE FUNCTION Sales.order_total
(
	@order_id INT
)
RETURNS FLOAT
AS
BEGIN
	DECLARE @order_total AS FLOAT;

	SELECT @order_total = ROUND(SUM(ol.Quantity * ol.UnitPrice * (1 + ol.TaxRate) * 0.01) ,2)
	FROM Sales.Orders o
	JOIN Sales.OrderLines ol
	ON o.OrderID = ol.OrderID
	GROUP BY o.OrderID
		HAVING o.OrderID = @order_id;

	RETURN @order_total;
END
GO
SELECT
	*,
	Sales.order_total(OrderID) AS order_total
FROM Sales.Invoices;
	
--21
GO
CREATE SCHEMA ods;
GO
CREATE TABLE ods.Orders (
	order_id INT PRIMARY KEY,
	order_date DATE NOT NULL,
	order_total FLOAT NOT NULL,
	customer_id INT NOT NULL
)
GO

CREATE PROCEDURE [dbo].[sp_order_date]
@OrderDate DATE
AS
BEGIN
	BEGIN TRY
		BEGIN Tran;
		
		INSERT INTO ods.Orders
		SELECT
			so.OrderID,
			so.OrderDate,
			Sales.order_total(so.OrderID) AS order_total,
			so.CustomerID
		FROM Sales.Orders so
		WHERE so.OrderDate = @OrderDate;
		
		COMMIT Tran;
	END TRY
	BEGIN CATCH
		PRINT ERROR_MESSAGE();
		PRINT 'Orders already existed in ods.Orders';
		ROLLBACK Tran;
	END CATCH
END
GO

-- insert orders on 2013-01-01
EXEC sp_order_date
	@OrderDate = '2013-01-01'
GO

-- insert orders on 2013-01-02
EXEC sp_order_date
	@OrderDate = '2013-01-02'
GO

-- insert orders on 2013-01-03
EXEC sp_order_date
	@OrderDate = '2013-01-03'
GO

-- insert orders on 2013-01-04
EXEC sp_order_date
	@OrderDate = '2013-01-04'
GO

-- insert orders on 2013-01-05
EXEC sp_order_date
	@OrderDate = '2013-01-05'
GO

--22
SELECT
	StockItemID,
	StockItemname,
	SupplierID,
	ColorID,
	UnitPackageID,
	OuterPackageID,
	Brand,
	Size,
	LeadTimeDays,
	QuantityPerOuter,
	IsChillerStock,
	Barcode,
	TaxRate,
	UnitPrice,
	RecommendedRetailPrice,
	TypicalWeightPerUnit,
	MarketingComments,
	InternalComments,
	JSON_VALUE(CustomFields, '$.CountryOfManufacture') AS CountryOfManufacture,
	JSON_VALUE(CustomFields, '$.Range') AS Range,
	JSON_VALUE(CustomFields, '$.Shelflife') AS Shelflife
INTO ods.StockItem
FROM Warehouse.StockItems;

--23
GO
ALTER PROCEDURE [dbo].[sp_order_date]
@OrderDate DATE
AS
BEGIN
	BEGIN TRY
		BEGIN Tran;
		
		DELETE FROM ods.Orders
		WHERE order_date < @OrderDate;
		INSERT INTO ods.Orders
		SELECT
			so.OrderID,
			so.OrderDate,
			Sales.order_total(so.OrderID) AS order_total,
			so.CustomerID
		FROM Sales.Orders so
		WHERE so.OrderDate BETWEEN DATEADD(DAY, 1, @OrderDate) AND DATEADD(DAY, 7, @OrderDate);
		
		COMMIT Tran;
	END TRY
	BEGIN CATCH
		PRINT ERROR_MESSAGE();
		PRINT 'Orders are up-to-date.';
		ROLLBACK Tran;
	END CATCH
END
GO

--24
DECLARE @missing_order AS NVARCHAR(MAX) = N'{
   "PurchaseOrders":[
      {
         "StockItemName":"Panzer Video Game",
         "Supplier":"7",
         "UnitPackageId":"1",
         "OuterPackageId":[
            6,
            7
         ],
         "Brand":"EA Sports",
         "LeadTimeDays":"5",
         "QuantityPerOuter":"1",
         "TaxRate":"6",
         "UnitPrice":"59.99",
         "RecommendedRetailPrice":"69.99",
         "TypicalWeightPerUnit":"0.5",
         "CountryOfManufacture":"Canada",
         "Range":"Adult",
         "OrderDate":"2018-01-01",
         "DeliveryMethod":"Post",
         "ExpectedDeliveryDate":"2018-02-02",
         "SupplierReference":"WWI2308"
      },
      {
         "StockItemName":"Panzer Video Game",
         "Supplier":"5",
         "UnitPackageId":"1",
         "OuterPackageId":[7],
         "Brand":"EA Sports",
         "LeadTimeDays":"5",
         "QuantityPerOuter":"1",
         "TaxRate":"6",
         "UnitPrice":"59.99",
         "RecommendedRetailPrice":"69.99",
         "TypicalWeightPerUnit":"0.5",
         "CountryOfManufacture":"Canada",
         "Range":"Adult",
         "OrderDate":"2018-01-25",
         "DeliveryMethod":"Post",
         "ExpectedDeliveryDate":"2018-02-02",
         "SupplierReference":"269622390"
      }
   ]
}'

SELECT
	StockItems.StockItemName,
	StockItems.Supplier,
	StockItems.UnitPackageId,
	OuterPackageId.value AS OuterPackageId,
	StockItems.Brand,
	StockItems.LeadTimeDays,
	StockItems.QuantityPerOuter,
	StockItems.TaxRate,
	StockItems.UnitPrice,
	StockItems.RecommendedRetailPrice,
	StockItems.TypicalWeightPerUnit,
	StockItems.CountryOfManufacture,
	StockItems.Range,
	StockItems.OrderDate,
	StockItems.DeliveryMethod,
	StockItems.ExpectedDeliveryDate,
	StockItems.SupplierReference
FROM OPENJSON(@missing_order)
	WITH
		(	
			PurchaseOrders NVARCHAR(MAX) AS JSON
		) AS PurchaseOrders 
CROSS APPLY OPENJSON(PurchaseOrders.PurchaseOrders)
	WITH
		(
			StockItemName NVARCHAR(100),
			Supplier INT,
			UnitPackageId INT,
			OuterPackageId NVARCHAR(MAX) AS JSON,
			Brand NVARCHAR(100),
			LeadTimeDays INT,
			QuantityPerOuter INT,
			TaxRate INT,
			UnitPrice FLOAT,
			RecommendedRetailPrice FLOAT,
			TypicalWeightPerUnit FLOAT,
			CountryOfManufacture NVARCHAR(100),
			Range NVARCHAR(100),
			OrderDate DATE,
			DeliveryMethod NVARCHAR(100),
			ExpectedDeliveryDate DATE,
			SupplierReference NVARCHAR(100)
		) AS StockItems
CROSS APPLY OPENJSON(StockItems.OuterPackageId) AS OuterPackageId;