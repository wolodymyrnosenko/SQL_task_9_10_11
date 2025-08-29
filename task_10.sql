-- =========================================
-- Create/Recreate demo database "Hospital"
-- =========================================

IF DB_ID(N'Hospital') IS NOT NULL
BEGIN
    ALTER DATABASE Hospital SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Hospital;
END
GO

CREATE DATABASE Hospital;
GO

USE Hospital;
GO

-- ======================================================
-- TABLE: Departments
-- ======================================================
CREATE TABLE dbo.Departments
(
    Id          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_Departments PRIMARY KEY,
    Building    INT             NOT NULL,
    Financing   MONEY           NOT NULL CONSTRAINT DF_Departments_Financing DEFAULT(0),
    Name        NVARCHAR(100)   NOT NULL,
    CONSTRAINT CK_Departments_Building_Range CHECK (Building BETWEEN 1 AND 5),
    CONSTRAINT CK_Departments_Financing_NonNegative CHECK (Financing >= 0),
    CONSTRAINT CK_Departments_Name_NotEmpty CHECK (LEN(LTRIM(RTRIM(Name))) > 0),
    CONSTRAINT UQ_Departments_Name UNIQUE (Name)
);
GO

-- ======================================================
-- TABLE: Diseases
-- ======================================================
CREATE TABLE dbo.Diseases
(
    Id          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_Diseases PRIMARY KEY,
    Name        NVARCHAR(100)   NOT NULL,
    Severity    INT             NOT NULL CONSTRAINT DF_Diseases_Severity DEFAULT(1),
    CONSTRAINT CK_Diseases_Name_NotEmpty CHECK (LEN(LTRIM(RTRIM(Name))) > 0),
    CONSTRAINT CK_Diseases_Severity_Min CHECK (Severity >= 1),
    CONSTRAINT UQ_Diseases_Name UNIQUE (Name)
);
GO

-- ======================================================
-- TABLE: Doctors
-- ======================================================
CREATE TABLE dbo.Doctors
(
    Id          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_Doctors PRIMARY KEY,
    Name        NVARCHAR(MAX)   NOT NULL,
    Phone       CHAR(10)        NULL,
    Salary      MONEY           NOT NULL,
    Allowance   MONEY           NOT NULL CONSTRAINT DF_Doctors_Allowance DEFAULT(0),
    Surname     NVARCHAR(MAX)   NOT NULL,
    CONSTRAINT CK_Doctors_Name_NotEmpty    CHECK (LEN(LTRIM(RTRIM(Name)))    > 0),
    CONSTRAINT CK_Doctors_Surname_NotEmpty CHECK (LEN(LTRIM(RTRIM(Surname))) > 0),
    CONSTRAINT CK_Doctors_Salary_Positive  CHECK (Salary > 0),
    CONSTRAINT CK_Doctors_Allowance_NonNeg CHECK (Allowance >= 0)
);
GO

-- ======================================================
-- TABLE: Examinations
-- ======================================================
CREATE TABLE dbo.Examinations
(
    Id          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_Examinations PRIMARY KEY,
    DayOfWeek   INT             NOT NULL,
    EndTime     TIME(0)         NOT NULL,
    Name        NVARCHAR(100)   NOT NULL,
    StartTime   TIME(0)         NOT NULL,
    CONSTRAINT CK_Examinations_DayOfWeek_Range CHECK (DayOfWeek BETWEEN 1 AND 7),
    CONSTRAINT CK_Examinations_Start_InRange   CHECK (StartTime >= '08:00' AND StartTime <= '18:00'),
    CONSTRAINT CK_Examinations_End_Greater     CHECK (EndTime > StartTime),
    CONSTRAINT CK_Examinations_Name_NotEmpty   CHECK (LEN(LTRIM(RTRIM(Name))) > 0),
    CONSTRAINT UQ_Examinations_Name UNIQUE (Name)
);
GO

-- ======================================================
-- TABLE: Wards
-- ======================================================
CREATE TABLE dbo.Wards
(
    Id          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_Wards PRIMARY KEY,
    Building    INT             NOT NULL,
    Floor       INT             NOT NULL,
    Name        NVARCHAR(20)    NOT NULL,
    CONSTRAINT CK_Wards_Building_Range CHECK (Building BETWEEN 1 AND 5),
    CONSTRAINT CK_Wards_Floor_Min      CHECK (Floor >= 1),
    CONSTRAINT CK_Wards_Name_NotEmpty  CHECK (LEN(LTRIM(RTRIM(Name))) > 0),
    CONSTRAINT UQ_Wards_Name UNIQUE (Name)
);
GO

-- ======================================================
-- INSERT sample data
-- ======================================================
INSERT INTO dbo.Departments (Building, Financing, Name) VALUES
(1, 10000, N'Cardiology'),
(3, 13000, N'Neurology'),
(5, 25000, N'Oncology'),
(5, 20000, N'Pediatrics'),
(2, 27000, N'Orthopedics');
GO

INSERT INTO dbo.Diseases (Name, Severity) VALUES
(N'Influenza', 2),
(N'Pneumonia', 3),
(N'COVID-19', 4),
(N'Bronchitis', 1),
(N'Tuberculosis', 5);
GO

INSERT INTO dbo.Doctors (Name, Phone, Salary, Allowance, Surname) VALUES
(N'John',  '0501234567', 2000, 500, N'Smith'),
(N'Anna',  '0672345678', 1400, 200, N'Nelson'),
(N'Mark',  '0639876543', 1800, 100, N'Norris'),
(N'Susan', NULL,         900,  100, N'Brown'),
(N'Nick',  '0971112233', 3000, 800, N'Newton');
GO

INSERT INTO dbo.Examinations (DayOfWeek, EndTime, Name, StartTime) VALUES
(1, '09:30', N'Blood Test', '08:30'),
(2, '13:30', N'X-Ray',      '12:00'),
(3, '14:00', N'MRI',        '12:30'),
(4, '11:00', N'Ultrasound', '09:00'),
(5, '16:00', N'CT Scan',    '14:30');
GO

INSERT INTO dbo.Wards (Building, Floor, Name) VALUES
(1, 1, N'WardA'),
(3, 2, N'WardB'),
(4, 1, N'WardC'),
(5, 1, N'WardD'),
(5, 3, N'WardE');
GO

/* =======================================================================
   SELECT QUERIES (1–17) with Ukrainian comments
   ======================================================================= */

-- 1) Вивести вміст таблиці палат
SELECT * FROM dbo.Wards;
GO

-- 2) Вивести прізвища та телефони усіх лікарів
SELECT Surname, Phone
FROM dbo.Doctors;
GO

-- 3) Вивести усі поверхи без повторень, де розміщуються палати
SELECT DISTINCT Floor
FROM dbo.Wards
ORDER BY Floor;
GO

-- 4) Вивести назви захворювань як "Name of Disease" і ступінь їхньої тяжкості як "Severity of Disease"
SELECT Name AS [Name of Disease], Severity AS [Severity of Disease]
FROM dbo.Diseases;
GO

-- 5) Застосувати FROM для трьох таблиць із псевдонімами
SELECT d.Name AS DepartmentName FROM dbo.Departments AS d;
SELECT doc.Surname AS DoctorSurname FROM dbo.Doctors AS doc;
SELECT w.Name AS WardName, w.Building, w.Floor FROM dbo.Wards w;
GO

-- 6) Вивести назви відділень у корпусі 5 з фінансуванням менше 30000
SELECT Name
FROM dbo.Departments
WHERE Building = 5 AND Financing < 30000;
GO

-- 7) Вивести назви відділень у корпусі 3 з фінансуванням у діапазоні 12000–15000
SELECT Name
FROM dbo.Departments
WHERE Building = 3 AND Financing BETWEEN 12000 AND 15000;
GO

-- 8) Вивести назви палат у корпусах 4 і 5 на 1-му поверсі
SELECT Name
FROM dbo.Wards
WHERE Building IN (4, 5) AND Floor = 1;
GO

-- 9) Вивести назви, корпуси та фонди відділень у корпусах 3 або 6,
--    з фондом < 11000 або > 25000
SELECT Name, Building, Financing
FROM dbo.Departments
WHERE Building IN (3, 6)
  AND (Financing < 11000 OR Financing > 25000);
GO

-- 10) Вивести прізвища лікарів, у яких зарплата (ставка + надбавка) > 1500
SELECT Surname
FROM dbo.Doctors
WHERE Salary + Allowance > 1500;
GO

-- 11) Вивести прізвища лікарів, у яких половина ставки > триразова надбавка
SELECT Surname
FROM dbo.Doctors
WHERE (Salary / 2.0) > (Allowance * 3.0);
GO

-- 12) Вивести унікальні назви обстежень у перші три дні тижня
--     з 12:00 до 15:00
SELECT DISTINCT Name
FROM dbo.Examinations
WHERE DayOfWeek IN (1,2,3)
  AND StartTime >= '12:00'
  AND EndTime   <= '15:00';
GO

-- 13) Вивести назви та корпуси відділень у корпусах 1, 3, 8 або 10
SELECT Name, Building
FROM dbo.Departments
WHERE Building IN (1, 3, 8, 10);
GO

-- 14) Вивести назви захворювань, ступінь тяжкості яких ≠ 1 та ≠ 2
SELECT Name
FROM dbo.Diseases
WHERE Severity NOT IN (1,2);
GO

-- 15) Вивести назви відділень, які не у корпусах 1 або 3
SELECT Name
FROM dbo.Departments
WHERE Building NOT IN (1,3);
GO

-- 16) Вивести назви відділень, які у корпусах 1 або 3
SELECT Name
FROM dbo.Departments
WHERE Building IN (1,3);
GO

-- 17) Вивести прізвища лікарів, що починаються з літери 'N'
SELECT Surname
FROM dbo.Doctors
WHERE Surname LIKE N'N%';
GO
