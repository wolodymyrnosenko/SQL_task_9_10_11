IF DB_ID(N'BarbershopDB') IS NOT NULL
BEGIN
    ALTER DATABASE BarbershopDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BarbershopDB;
END;
GO
CREATE DATABASE BarbershopDB;
GO
USE BarbershopDB;
GO

-- Positions: catalog of barber positions
CREATE TABLE dbo.Positions (
    PositionId      INT IDENTITY PRIMARY KEY,
    PositionCode    VARCHAR(50)  NOT NULL UNIQUE,   -- 'chief-barber' | 'senior-barber' | 'junior-barber'
    PositionName    VARCHAR(100) NOT NULL
);
GO

INSERT INTO dbo.Positions(PositionCode, PositionName)
VALUES ('chief-barber','Chief Barber'),
       ('senior-barber','Senior Barber'),
       ('junior-barber','Junior Barber');
GO

-- Services: catalog of services
CREATE TABLE dbo.Services (
    ServiceId       INT IDENTITY PRIMARY KEY,
    ServiceCode     VARCHAR(50)  NOT NULL UNIQUE,
    ServiceName     VARCHAR(200) NOT NULL,
    ServiceDesc     VARCHAR(500) NULL
);
GO

INSERT INTO dbo.Services(ServiceCode, ServiceName, ServiceDesc)
VALUES ('traditional-beard-shave','Traditional Beard Shave','Classic hot towel and straight razor shave'),
       ('haircut-classic','Classic Haircut','Standard men haircut'),
       ('haircut-fade','Fade Haircut','Modern fade haircut'),
       ('mustache-trim','Mustache Trim','Trimming and styling mustache');
GO

-- Barbers: main entity
CREATE TABLE dbo.Barbers (
    BarberId        INT IDENTITY PRIMARY KEY,
    FullName        VARCHAR(200) NOT NULL,
    Gender          VARCHAR(10)  NOT NULL CHECK (Gender IN ('male','female','other')),
    Phone           VARCHAR(30)  NOT NULL,
    Email           VARCHAR(320) NOT NULL,
    DateOfBirth     DATE         NOT NULL,
    HireDate        DATE         NOT NULL,
    PositionId      INT          NOT NULL REFERENCES dbo.Positions(PositionId),
    IsActive        BIT          NOT NULL DEFAULT(1),
    CreatedAt       DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME()),
    UpdatedAt       DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME())
);
GO
CREATE INDEX IX_Barbers_Position ON dbo.Barbers(PositionId);
GO

-- Clients: customers
CREATE TABLE dbo.Clients (
    ClientId        INT IDENTITY PRIMARY KEY,
    FullName        VARCHAR(200) NOT NULL,
    Phone           VARCHAR(30)  NOT NULL,
    Email           VARCHAR(320) NOT NULL,
    CreatedAt       DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME())
);
GO
CREATE UNIQUE INDEX UX_Clients_Phone ON dbo.Clients(Phone);
GO

-- BarberServices: price and duration per barber-service
CREATE TABLE dbo.BarberServices (
    BarberServiceId INT IDENTITY PRIMARY KEY,
    BarberId        INT NOT NULL REFERENCES dbo.Barbers(BarberId),
    ServiceId       INT NOT NULL REFERENCES dbo.Services(ServiceId),
    Price           DECIMAL(10,2) NOT NULL CHECK (Price >= 0),
    DurationMin     INT NOT NULL CHECK (DurationMin BETWEEN 5 AND 480),
    IsActive        BIT NOT NULL DEFAULT(1),
    UNIQUE(BarberId, ServiceId)
);
GO
CREATE INDEX IX_BarberServices_Service ON dbo.BarberServices(ServiceId);
GO

-- BarberAvailability: free time slots per barber
CREATE TABLE dbo.BarberAvailability (
    AvailabilityId  INT IDENTITY PRIMARY KEY,
    BarberId        INT NOT NULL REFERENCES dbo.Barbers(BarberId),
    StartTime       DATETIME2(0) NOT NULL,
    EndTime         DATETIME2(0) NOT NULL,
    CONSTRAINT CK_BarberAvailability_Time CHECK (EndTime > StartTime)
);
GO
CREATE INDEX IX_BarberAvailability_BarberTime ON dbo.BarberAvailability(BarberId, StartTime, EndTime);
GO

-- Appointments: bookings
CREATE TABLE dbo.Appointments (
    AppointmentId   INT IDENTITY PRIMARY KEY,
    BarberId        INT NOT NULL REFERENCES dbo.Barbers(BarberId),
    ClientId        INT NOT NULL REFERENCES dbo.Clients(ClientId),
    StartTime       DATETIME2(0) NOT NULL,
    EndTime         DATETIME2(0) NOT NULL,
    Status          VARCHAR(20) NOT NULL CHECK (Status IN ('scheduled','completed','cancelled','no-show')),
    TotalAmount     DECIMAL(10,2) NOT NULL CHECK (TotalAmount >= 0),
    CreatedAt       DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME()),
    CONSTRAINT CK_Appointments_Time CHECK (EndTime > StartTime)
);
GO
CREATE INDEX IX_Appointments_BarberTime ON dbo.Appointments(BarberId, StartTime, EndTime);
CREATE INDEX IX_Appointments_Client ON dbo.Appointments(ClientId, StartTime);
GO

-- AppointmentServices: multi-service per visit
CREATE TABLE dbo.AppointmentServices (
    AppointmentServiceId INT IDENTITY PRIMARY KEY,
    AppointmentId        INT NOT NULL REFERENCES dbo.Appointments(AppointmentId),
    ServiceId            INT NOT NULL REFERENCES dbo.Services(ServiceId),
    Price                DECIMAL(10,2) NOT NULL CHECK (Price >= 0),
    DurationMin          INT NOT NULL CHECK (DurationMin BETWEEN 5 AND 480)
);
GO
CREATE INDEX IX_AppointmentServices_App ON dbo.AppointmentServices(AppointmentId);
GO

-- Reviews: client ratings and feedback for barbers
-- Rating: 1=very bad, 2=bad, 3=normal, 4=good, 5=great
CREATE TABLE dbo.Reviews (
    ReviewId        INT IDENTITY PRIMARY KEY,
    BarberId        INT NOT NULL REFERENCES dbo.Barbers(BarberId),
    ClientId        INT NOT NULL REFERENCES dbo.Clients(ClientId),
    AppointmentId   INT NULL REFERENCES dbo.Appointments(AppointmentId),
    Rating          TINYINT NOT NULL CHECK (Rating BETWEEN 1 AND 5),
    Feedback        VARCHAR(2000) NULL,
    CreatedAt       DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME())
);
GO
CREATE INDEX IX_Reviews_Barber ON dbo.Reviews(BarberId);
CREATE INDEX IX_Reviews_Client ON dbo.Reviews(ClientId);
GO

-- Single chief-barber rule via filtered unique index
DECLARE @ChiefId INT = (SELECT PositionId FROM dbo.Positions WHERE PositionCode='chief-barber');
CREATE UNIQUE INDEX UX_Barbers_SingleChief ON dbo.Barbers(PositionId) WHERE PositionId = @ChiefId;
GO

-- Trigger: forbid adding/updating barbers younger than 21; and touch UpdatedAt
CREATE TRIGGER dbo.trg_Barbers_MinAge21
ON dbo.Barbers
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE DATEDIFF(YEAR, i.DateOfBirth, CAST(GETDATE() AS DATE))
              - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, i.DateOfBirth, CAST(GETDATE() AS DATE)), i.DateOfBirth) > CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END
            < 21
    )
    BEGIN
        RAISERROR(N'Cannot add/update barber younger than 21 years.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    UPDATE b
    SET UpdatedAt = SYSDATETIME()
    FROM dbo.Barbers b
    INNER JOIN inserted i ON b.BarberId = i.BarberId;
END;
GO

-- Trigger: prevent deleting chief-barber (demote first, then reassign)
CREATE TRIGGER dbo.trg_Barbers_PreventDeleteChief
ON dbo.Barbers
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ChiefId INT = (SELECT PositionId FROM dbo.Positions WHERE PositionCode='chief-barber');
    IF EXISTS (SELECT 1 FROM deleted d WHERE d.PositionId = @ChiefId)
    BEGIN
        RAISERROR(N'Cannot delete the chief-barber.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    DELETE b
    FROM dbo.Barbers b
    INNER JOIN deleted d ON b.BarberId = d.BarberId;
END;
GO

-- View: barbers with positions
CREATE VIEW dbo.vBarbers AS
SELECT 
    b.BarberId, b.FullName, b.Gender, b.Phone, b.Email,
    b.DateOfBirth, b.HireDate, p.PositionCode, p.PositionName, b.IsActive, b.CreatedAt, b.UpdatedAt
FROM dbo.Barbers b
JOIN dbo.Positions p ON p.PositionId = b.PositionId;
GO

-- Stored procedures: business queries

-- All barber names
CREATE OR ALTER PROCEDURE dbo.usp_GetAllBarberNames
AS
BEGIN
    SET NOCOUNT ON;
    SELECT b.BarberId, b.FullName FROM dbo.Barbers b ORDER BY b.FullName;
END;
GO

-- All senior barbers
CREATE OR ALTER PROCEDURE dbo.usp_GetAllSeniorBarbers
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vBarbers WHERE PositionCode='senior-barber' ORDER BY FullName;
END;
GO

-- Barbers for traditional beard shave
CREATE OR ALTER PROCEDURE dbo.usp_BarbersForTraditionalBeardShave
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT b.*
    FROM dbo.vBarbers b
    JOIN dbo.BarberServices bs ON bs.BarberId = b.BarberId AND bs.IsActive = 1
    JOIN dbo.Services s ON s.ServiceId = bs.ServiceId
    WHERE s.ServiceCode = 'traditional-beard-shave';
END;
GO

-- Barbers for a given service name (parameter)
CREATE OR ALTER PROCEDURE dbo.usp_BarbersForService
    @ServiceName VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT b.*
    FROM dbo.vBarbers b
    JOIN dbo.BarberServices bs ON bs.BarberId = b.BarberId AND bs.IsActive = 1
    JOIN dbo.Services s ON s.ServiceId = bs.ServiceId
    WHERE s.ServiceName = @ServiceName;
END;
GO

-- Barbers with experience greater than N years (parameter)
CREATE OR ALTER PROCEDURE dbo.usp_BarbersWithExperienceYears
    @Years INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT *
    FROM dbo.vBarbers
    WHERE DATEDIFF(YEAR, HireDate, GETDATE()) 
          - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, HireDate, GETDATE()), HireDate) > CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END
          > @Years
    ORDER BY FullName;
END;
GO

-- Count seniors and juniors
CREATE OR ALTER PROCEDURE dbo.usp_CountSeniorsAndJuniors
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        SUM(CASE WHEN PositionCode='senior-barber' THEN 1 ELSE 0 END) AS SeniorCount,
        SUM(CASE WHEN PositionCode='junior-barber' THEN 1 ELSE 0 END) AS JuniorCount
    FROM dbo.vBarbers;
END;
GO

-- Regular clients: visited >= @MinVisits times (completed)
CREATE OR ALTER PROCEDURE dbo.usp_GetRegularClients
    @MinVisits INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.ClientId, c.FullName, c.Phone, c.Email, COUNT(*) AS VisitsCount
    FROM dbo.Clients c
    JOIN dbo.Appointments a ON a.ClientId = c.ClientId AND a.Status='completed'
    GROUP BY c.ClientId, c.FullName, c.Phone, c.Email
    HAVING COUNT(*) >= @MinVisits
    ORDER BY VisitsCount DESC, c.FullName;
END;
GO

-- User-defined functions

-- Hello, NAME!
CREATE OR ALTER FUNCTION dbo.ufn_Greet(@Name VARCHAR(200))
RETURNS VARCHAR(210)
AS
BEGIN
    RETURN CONCAT('Hello, ', @Name, '!');
END;
GO

-- Current minute (0..59)
CREATE OR ALTER FUNCTION dbo.ufn_CurrentMinute()
RETURNS INT
AS
BEGIN
    RETURN DATEPART(MINUTE, GETDATE());
END;
GO

-- Current year
CREATE OR ALTER FUNCTION dbo.ufn_CurrentYear()
RETURNS INT
AS
BEGIN
    RETURN DATEPART(YEAR, GETDATE());
END;
GO

-- Is current year even (Yes/No)
CREATE OR ALTER FUNCTION dbo.ufn_IsCurrentYearEven()
RETURNS VARCHAR(3)
AS
BEGIN
    DECLARE @y INT = DATEPART(YEAR, GETDATE());
    RETURN CASE WHEN @y % 2 = 0 THEN 'Yes' ELSE 'No' END;
END;
GO

-- Prime check (Yes/No)
CREATE OR ALTER FUNCTION dbo.ufn_IsPrime(@n INT)
RETURNS VARCHAR(3)
AS
BEGIN
    IF @n < 2 RETURN 'No';
    IF @n IN (2,3) RETURN 'Yes';
    IF @n % 2 = 0 OR @n % 3 = 0 RETURN 'No';
    DECLARE @i INT = 5;
    WHILE (@i * @i) <= @n
    BEGIN
        IF @n % @i = 0 OR @n % (@i + 2) = 0 RETURN 'No';
        SET @i += 6;
    END
    RETURN 'Yes';
END;
GO

-- Sum of min and max of 5 numbers
CREATE OR ALTER FUNCTION dbo.ufn_MinMaxSum(@a INT, @b INT, @c INT, @d INT, @e INT)
RETURNS INT
AS
BEGIN
    DECLARE @min INT = @a, @max INT = @a;
    DECLARE @x TABLE (v INT);
    INSERT INTO @x(v) VALUES (@a),(@b),(@c),(@d),(@e);
    SELECT @min = MIN(v), @max = MAX(v) FROM @x;
    RETURN @min + @max;
END;
GO

-- All even or odd numbers in range [Start..End], @Parity = 'even' | 'odd'
CREATE OR ALTER FUNCTION dbo.ufn_RangeParity(@Start INT, @End INT, @Parity VARCHAR(10))
RETURNS @t TABLE (val INT)
AS
BEGIN
    DECLARE @lo INT = CASE WHEN @Start <= @End THEN @Start ELSE @End END;
    DECLARE @hi INT = CASE WHEN @Start <= @End THEN @End   ELSE @Start END;

    DECLARE @cur INT = @lo;
    WHILE @cur <= @hi
    BEGIN
        IF (@Parity='even' AND @cur % 2 = 0) OR (@Parity='odd' AND @cur % 2 <> 0)
            INSERT INTO @t(val) VALUES (@cur);
        SET @cur += 1;
    END
    RETURN;
END;
GO

-- Utility stored procedures

-- Hello, world!
CREATE OR ALTER PROCEDURE dbo.usp_HelloWorld
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 'Hello, world!' AS Message;
END;
GO

-- Current time
CREATE OR ALTER PROCEDURE dbo.usp_CurrentTime
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(GETDATE() AS TIME(0)) AS CurrentTime;
END;
GO

-- Current date
CREATE OR ALTER PROCEDURE dbo.usp_CurrentDate
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(GETDATE() AS DATE) AS CurrentDate;
END;
GO

-- Sum of three numbers
CREATE OR ALTER PROCEDURE dbo.usp_Sum3
    @a FLOAT, @b FLOAT, @c FLOAT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT (@a + @b + @c) AS Sum3;
END;
GO

-- Average of three numbers
CREATE OR ALTER PROCEDURE dbo.usp_Avg3
    @a FLOAT, @b FLOAT, @c FLOAT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT (@a + @b + @c) / 3.0 AS Avg3;
END;
GO

-- Max of three numbers
CREATE OR ALTER PROCEDURE dbo.usp_Max3
    @a FLOAT, @b FLOAT, @c FLOAT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT (SELECT MAX(v) FROM (VALUES(@a),(@b),(@c)) t(v)) AS Max3;
END;
GO

-- Min of three numbers
CREATE OR ALTER PROCEDURE dbo.usp_Min3
    @a FLOAT, @b FLOAT, @c FLOAT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT (SELECT MIN(v) FROM (VALUES(@a),(@b),(@c)) t(v)) AS Min3;
END;
GO

-- Draw a line of length @length using character @ch
CREATE OR ALTER PROCEDURE dbo.usp_DrawLine
    @length INT,
    @ch     NCHAR(1)
AS
BEGIN
    SET NOCOUNT ON;
    IF @length < 0
    BEGIN
        RAISERROR(N'Length must be non-negative.', 16, 1);
        RETURN;
    END;

    ;WITH E1 AS (SELECT 1 AS n UNION ALL SELECT 1),
         E2 AS (SELECT 1 FROM E1 a, E1 b),
         E4 AS (SELECT 1 FROM E2 a, E2 b),
         E8 AS (SELECT 1 FROM E4 a, E4 b),
         Tally AS (SELECT TOP (@length) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM E8)
    SELECT (SELECT '' + @ch FROM Tally FOR XML PATH(''), TYPE).value('.','NVARCHAR(MAX)') AS Line;
END;
GO

-- Factorial (returns DECIMAL(38,0))
CREATE OR ALTER PROCEDURE dbo.usp_Factorial
    @n INT
AS
BEGIN
    SET NOCOUNT ON;
    IF @n < 0
    BEGIN
        RAISERROR(N'Factorial is not defined for negative numbers.', 16, 1);
        RETURN;
    END;

    DECLARE @res DECIMAL(38,0) = 1;
    DECLARE @i INT = 2;
    WHILE @i <= @n
    BEGIN
        SET @res = @res * @i;
        SET @i += 1;
    END

    SELECT @res AS Factorial;
END;
GO

-- Power: @number ^ @power
CREATE OR ALTER PROCEDURE dbo.usp_Pow
    @number FLOAT,
    @power  FLOAT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT POWER(@number, @power) AS Result;
END;
GO

-- Test data

DECLARE @chief INT  = (SELECT PositionId FROM dbo.Positions WHERE PositionCode='chief-barber');
DECLARE @senior INT = (SELECT PositionId FROM dbo.Positions WHERE PositionCode='senior-barber');
DECLARE @junior INT = (SELECT PositionId FROM dbo.Positions WHERE PositionCode='junior-barber');

INSERT INTO dbo.Barbers(FullName,Gender,Phone,Email,DateOfBirth,HireDate,PositionId)
VALUES ('John Smith','male','+380501112233','john@example.com','1985-03-05','2015-02-01',@chief),
       ('Alex Johnson','male','+380671234567','alex@example.com','1990-07-12','2018-06-01',@senior),
       ('Mark Davis','male','+380931112244','mark@example.com','1998-09-21','2021-01-15',@junior);
GO

INSERT INTO dbo.Clients(FullName,Phone,Email)
VALUES ('Nick Brown','+380661112233','nick@example.com'),
       ('Steve Wilson','+380671114455','steve@example.com'),
       ('Andrew Hall','+380501118899','andrew@example.com');
GO

INSERT INTO dbo.BarberServices(BarberId,ServiceId,Price,DurationMin)
SELECT b.BarberId, s.ServiceId,
       CASE s.ServiceCode 
            WHEN 'traditional-beard-shave' THEN 600
            WHEN 'haircut-classic' THEN 400
            WHEN 'haircut-fade' THEN 500
            WHEN 'mustache-trim' THEN 200
       END,
       CASE s.ServiceCode 
            WHEN 'traditional-beard-shave' THEN 40
            WHEN 'haircut-classic' THEN 30
            WHEN 'haircut-fade' THEN 35
            WHEN 'mustache-trim' THEN 15
       END
FROM dbo.Barbers b
CROSS JOIN dbo.Services s;
GO

INSERT INTO dbo.BarberAvailability(BarberId, StartTime, EndTime)
VALUES (1,'2025-08-31T10:00:00','2025-08-31T14:00:00'),
       (2,'2025-08-31T09:00:00','2025-08-31T12:00:00'),
       (3,'2025-08-31T12:00:00','2025-08-31T16:00:00');
GO

INSERT INTO dbo.Appointments(BarberId,ClientId,StartTime,EndTime,Status,TotalAmount)
VALUES (1,1,'2025-08-01T10:00:00','2025-08-01T10:40:00','completed',600),
       (2,2,'2025-08-02T11:00:00','2025-08-02T11:30:00','completed',400),
       (3,3,'2025-08-03T12:00:00','2025-08-03T12:35:00','scheduled',500);
GO

INSERT INTO dbo.AppointmentServices(AppointmentId,ServiceId,Price,DurationMin)
VALUES (1, (SELECT ServiceId FROM dbo.Services WHERE ServiceCode='traditional-beard-shave'),600,40),
       (2, (SELECT ServiceId FROM dbo.Services WHERE ServiceCode='haircut-classic'),400,30),
       (3, (SELECT ServiceId FROM dbo.Services WHERE ServiceCode='haircut-fade'),500,35);
GO

INSERT INTO dbo.Reviews(BarberId,ClientId,AppointmentId,Rating,Feedback)
VALUES (1,1,1,5,'Excellent shave!'),
       (2,2,2,4,'Good haircut, but had to wait 10 minutes'),
       (1,3,NULL,5,'Great attention to detail.');
GO
