use master;
go

if db_id('Stage') is not null
begin;
    alter database Stage set single_user with rollback immediate;
    drop database Stage;
end;
go

create database Stage;
go

use Stage;
go

create schema AW authorization dbo;
go

USE Stage;
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------
IF EXISTS (SELECT * from sys.objects WHERE object_id = OBJECT_ID(N'[AW].[BusinessEntity]') AND type IN (N'U'))
DROP TABLE [AW].[BusinessEntity]
GO

CREATE TABLE [AW].[BusinessEntity]
(
-- Columns Definition
	[BusinessEntityID] int IDENTITY(1,1) NOT NULL 
,	[rowguid] uniqueidentifier NOT NULL 
,	[ModifiedDate] datetime NOT NULL 
,	[LoadDateTime] datetime NOT NULL 

-- Constraints

)
ON "default"
WITH (DATA_COMPRESSION = NONE)
GO

-------------------------------------------------------------------





SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------
IF EXISTS (SELECT * from sys.objects WHERE object_id = OBJECT_ID(N'[AW].[ContactType]') AND type IN (N'U'))
DROP TABLE [AW].[ContactType]
GO

CREATE TABLE [AW].[ContactType]
(
-- Columns Definition
	[ContactTypeID] int IDENTITY(1,1) NOT NULL 
,	[Name] nvarchar(50) NOT NULL 
,	[ModifiedDate] datetime NOT NULL 
,	[LoadDateTime] datetime NOT NULL 

-- Constraints

)
ON "default"
WITH (DATA_COMPRESSION = NONE)
GO

-------------------------------------------------------------------





SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------
IF EXISTS (SELECT * from sys.objects WHERE object_id = OBJECT_ID(N'[AW].[CountryRegion]') AND type IN (N'U'))
DROP TABLE [AW].[CountryRegion]
GO

CREATE TABLE [AW].[CountryRegion]
(
-- Columns Definition
	[CountryRegionCode] nvarchar(3) NOT NULL 
,	[Name] nvarchar(50) NOT NULL 
,	[ModifiedDate] datetime NOT NULL 
,	[LoadDateTime] datetime NOT NULL 

-- Constraints

)
ON "default"
WITH (DATA_COMPRESSION = NONE)
GO

-------------------------------------------------------------------





SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------
IF EXISTS (SELECT * from sys.objects WHERE object_id = OBJECT_ID(N'[AW].[Department]') AND type IN (N'U'))
DROP TABLE [AW].[Department]
GO

CREATE TABLE [AW].[Department]
(
-- Columns Definition
	[DepartmentID] smallint IDENTITY(1,1) NOT NULL 
,	[Name] nvarchar(50) NOT NULL 
,	[GroupName] nvarchar(50) NOT NULL 
,	[ModifiedDate] datetime NOT NULL 
,	[LoadDateTime] datetime NOT NULL 

-- Constraints

)
ON "default"
WITH (DATA_COMPRESSION = NONE)
GO

-------------------------------------------------------------------





SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------
IF EXISTS (SELECT * from sys.objects WHERE object_id = OBJECT_ID(N'[AW].[Location]') AND type IN (N'U'))
DROP TABLE [AW].[Location]
GO

CREATE TABLE [AW].[Location]
(
-- Columns Definition
	[LocationID] smallint IDENTITY(1,1) NOT NULL 
,	[Name] nvarchar(50) NOT NULL 
,	[CostRate] smallmoney NOT NULL 
,	[Availability] decimal(8,2) NOT NULL 
,	[ModifiedDate] datetime NOT NULL 
,	[LoadDateTime] datetime NOT NULL 

-- Constraints

)
ON "default"
WITH (DATA_COMPRESSION = NONE)
GO

-------------------------------------------------------------------





SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------
IF EXISTS (SELECT * from sys.objects WHERE object_id = OBJECT_ID(N'[AW].[Person]') AND type IN (N'U'))
DROP TABLE [AW].[Person]
GO

CREATE TABLE [AW].[Person]
(
-- Columns Definition
	[BusinessEntityID] int NOT NULL 
,	[PersonType] nchar(2) NOT NULL 
,	[NameStyle] bit NOT NULL 
,	[Title] nvarchar(8) 
,	[FirstName] nvarchar(50) NOT NULL 
,	[MiddleName] nvarchar(50) 
,	[LastName] nvarchar(50) NOT NULL 
,	[Suffix] nvarchar(10) 
,	[EmailPromotion] int NOT NULL 
,	[AdditionalContactInfo] xml 
,	[Demographics] xml 
,	[rowguid] uniqueidentifier NOT NULL 
,	[ModifiedDate] datetime NOT NULL 
,	[LoadDateTime] datetime NOT NULL 

-- Constraints

)
ON "default"
WITH (DATA_COMPRESSION = NONE)
GO

-------------------------------------------------------------------





SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------
IF EXISTS (SELECT * from sys.objects WHERE object_id = OBJECT_ID(N'[AW].[Product]') AND type IN (N'U'))
DROP TABLE [AW].[Product]
GO

CREATE TABLE [AW].[Product]
(
-- Columns Definition
	[ProductID] int IDENTITY(1,1) NOT NULL 
,	[Name] nvarchar(50) NOT NULL 
,	[ProductNumber] nvarchar(25) NOT NULL 
,	[MakeFlag] bit NOT NULL 
,	[FinishedGoodsFlag] bit NOT NULL 
,	[Color] nvarchar(15) 
,	[SafetyStockLevel] smallint NOT NULL 
,	[ReorderPoint] smallint NOT NULL 
,	[StandardCost] money NOT NULL 
,	[ListPrice] money NOT NULL 
,	[Size] nvarchar(5) 
,	[SizeUnitMeasureCode] nchar(3) 
,	[WeightUnitMeasureCode] nchar(3) 
,	[Weight] decimal(8,2) 
,	[DaysToManufacture] int NOT NULL 
,	[ProductLine] nchar(2) 
,	[Class] nchar(2) 
,	[Style] nchar(2) 
,	[ProductSubcategoryID] int 
,	[ProductModelID] int 
,	[SellStartDate] datetime NOT NULL 
,	[SellEndDate] datetime 
,	[DiscontinuedDate] datetime 
,	[rowguid] uniqueidentifier NOT NULL 
,	[ModifiedDate] datetime NOT NULL 
,	[LoadDateTime] datetime NOT NULL 

-- Constraints

)
ON "default"
WITH (DATA_COMPRESSION = NONE)
GO

-------------------------------------------------------------------






SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------
IF EXISTS (SELECT * from sys.objects WHERE object_id = OBJECT_ID(N'[AW].[ProductCategory]') AND type IN (N'U'))
DROP TABLE [AW].[ProductCategory]
GO

CREATE TABLE [AW].[ProductCategory]
(
-- Columns Definition
	[ProductCategoryID] int IDENTITY(1,1) NOT NULL 
,	[Name] nvarchar(50) NOT NULL 
,	[rowguid] uniqueidentifier NOT NULL 
,	[ModifiedDate] datetime NOT NULL 
,	[LoadDateTime] datetime NOT NULL 

-- Constraints

)
ON "default"
WITH (DATA_COMPRESSION = NONE)
GO

-------------------------------------------------------------------





SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------
IF EXISTS (SELECT * from sys.objects WHERE object_id = OBJECT_ID(N'[AW].[ProductCostHistory]') AND type IN (N'U'))
DROP TABLE [AW].[ProductCostHistory]
GO

CREATE TABLE [AW].[ProductCostHistory]
(
-- Columns Definition
	[ProductID] int NOT NULL 
,	[StartDate] datetime NOT NULL 
,	[EndDate] datetime 
,	[StandardCost] money NOT NULL 
,	[ModifiedDate] datetime NOT NULL 
,	[LoadDateTime] datetime NOT NULL 

-- Constraints

)
ON "default"
WITH (DATA_COMPRESSION = NONE)
GO

-------------------------------------------------------------------





SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------
IF EXISTS (SELECT * from sys.objects WHERE object_id = OBJECT_ID(N'[AW].[ProductDescription]') AND type IN (N'U'))
DROP TABLE [AW].[ProductDescription]
GO

CREATE TABLE [AW].[ProductDescription]
(
-- Columns Definition
	[ProductDescriptionID] int IDENTITY(1,1) NOT NULL 
,	[Description] nvarchar(400) NOT NULL 
,	[rowguid] uniqueidentifier NOT NULL 
,	[ModifiedDate] datetime NOT NULL 
,	[LoadDateTime] datetime NOT NULL 

-- Constraints

)
ON "default"
WITH (DATA_COMPRESSION = NONE)
GO

-------------------------------------------------------------------





SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------
IF EXISTS (SELECT * from sys.objects WHERE object_id = OBJECT_ID(N'[AW].[ProductModel]') AND type IN (N'U'))
DROP TABLE [AW].[ProductModel]
GO

CREATE TABLE [AW].[ProductModel]
(
-- Columns Definition
	[ProductModelID] int IDENTITY(1,1) NOT NULL 
,	[Name] nvarchar(50) NOT NULL 
,	[CatalogDescription] xml 
,	[Instructions] xml 
,	[rowguid] uniqueidentifier NOT NULL 
,	[ModifiedDate] datetime NOT NULL 
,	[LoadDateTime] datetime NOT NULL 

-- Constraints

)
ON "default"
WITH (DATA_COMPRESSION = NONE)
GO

-------------------------------------------------------------------





SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------
IF EXISTS (SELECT * from sys.objects WHERE object_id = OBJECT_ID(N'[AW].[ProductReview]') AND type IN (N'U'))
DROP TABLE [AW].[ProductReview]
GO

CREATE TABLE [AW].[ProductReview]
(
-- Columns Definition
	[ProductReviewID] int IDENTITY(1,1) NOT NULL 
,	[ProductID] int NOT NULL 
,	[ReviewerName] nvarchar(50) NOT NULL 
,	[ReviewDate] datetime NOT NULL 
,	[EmailAddress] nvarchar(50) NOT NULL 
,	[Rating] int NOT NULL 
,	[Comments] nvarchar(3850) 
,	[ModifiedDate] datetime NOT NULL 
,	[LoadDateTime] datetime NOT NULL 

-- Constraints

)
ON "default"
WITH (DATA_COMPRESSION = NONE)
GO

-------------------------------------------------------------------






SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------
IF EXISTS (SELECT * from sys.objects WHERE object_id = OBJECT_ID(N'[AW].[Shift]') AND type IN (N'U'))
DROP TABLE [AW].[Shift]
GO

CREATE TABLE [AW].[Shift]
(
-- Columns Definition
	[ShiftID] tinyint IDENTITY(1,1) NOT NULL 
,	[Name] nvarchar(50) NOT NULL 
,	[StartTime] time(7) NOT NULL 
,	[EndTime] time(7) NOT NULL 
,	[ModifiedDate] datetime NOT NULL 
,	[LoadDateTime] datetime NOT NULL 

-- Constraints

)
ON "default"
WITH (DATA_COMPRESSION = NONE)
GO

-------------------------------------------------------------------
