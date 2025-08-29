-- ============================================
-- CREATE DATABASE
-- ============================================
CREATE DATABASE student_grading;
GO

USE student_grading;
GO

-- ============================================
-- 1) SCHEMA
-- ============================================

-- Таблиця груп
CREATE TABLE groups (
    group_id      INT IDENTITY(1,1) PRIMARY KEY,
    group_name    VARCHAR(100) NOT NULL UNIQUE
);
GO

-- Таблиця студентів
CREATE TABLE students (
    student_id    INT IDENTITY(1,1) PRIMARY KEY,
    full_name     VARCHAR(200) NOT NULL,
    city          VARCHAR(100) NOT NULL,
    country       VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    email         VARCHAR(255) NOT NULL,
    phone         VARCHAR(50)  NOT NULL,
    group_id      INT NOT NULL FOREIGN KEY REFERENCES groups(group_id)
);
GO

-- Таблиця предметів
CREATE TABLE subjects (
    subject_id    INT IDENTITY(1,1) PRIMARY KEY,
    subject_name  VARCHAR(150) NOT NULL UNIQUE
);
GO

-- Таблиця оцінок
CREATE TABLE grades (
    grade_id      INT IDENTITY(1,1) PRIMARY KEY,
    student_id    INT NOT NULL FOREIGN KEY REFERENCES students(student_id),
    subject_id    INT NOT NULL FOREIGN KEY REFERENCES subjects(subject_id),
    academic_year INT NOT NULL,
    term          VARCHAR(30) NOT NULL,
    grade         DECIMAL(5,2) NOT NULL CHECK (grade >= 0 AND grade <= 100)
);
GO

CREATE INDEX ix_grades_student_year ON grades(student_id, academic_year);
CREATE INDEX ix_grades_subject      ON grades(subject_id);
GO

-- ============================================
-- 2) VIEW (агрегація середніх, мін/макс предметів)
-- ============================================
CREATE OR ALTER VIEW v_student_year_stats AS
WITH subject_avg AS (
    SELECT
        g.student_id,
        g.academic_year,
        g.subject_id,
        AVG(g.grade) AS subject_avg_grade
    FROM grades g
    GROUP BY g.student_id, g.academic_year, g.subject_id
),
with_extremes AS (
    SELECT
        sa.student_id,
        sa.academic_year,
        sa.subject_id,
        s.subject_name,
        sa.subject_avg_grade,
        MIN(sa.subject_avg_grade) OVER (PARTITION BY sa.student_id, sa.academic_year) AS min_avg_year,
        MAX(sa.subject_avg_grade) OVER (PARTITION BY sa.student_id, sa.academic_year) AS max_avg_year,
        FIRST_VALUE(s.subject_name) OVER (
            PARTITION BY sa.student_id, sa.academic_year
            ORDER BY sa.subject_avg_grade ASC, s.subject_name ASC
        ) AS min_subject_name,
        FIRST_VALUE(s.subject_name) OVER (
            PARTITION BY sa.student_id, sa.academic_year
            ORDER BY sa.subject_avg_grade DESC, s.subject_name ASC
        ) AS max_subject_name
    FROM subject_avg sa
    JOIN subjects s ON s.subject_id = sa.subject_id
),
year_agg AS (
    SELECT
        g.student_id,
        g.academic_year,
        AVG(g.grade) AS avg_grade_year
    FROM grades g
    GROUP BY g.student_id, g.academic_year
),
pick_one AS (
    SELECT DISTINCT
        we.student_id,
        we.academic_year,
        ya.avg_grade_year,
        we.min_avg_year,
        we.max_avg_year,
        we.min_subject_name,
        we.max_subject_name
    FROM with_extremes we
    JOIN year_agg ya
      ON ya.student_id = we.student_id
     AND ya.academic_year = we.academic_year
)
SELECT
    st.student_id,
    st.full_name,
    st.city,
    st.country,
    st.date_of_birth,
    st.email,
    st.phone,
    gr.group_name,
    po.academic_year,
    ROUND(po.avg_grade_year, 2) AS avg_grade_year,
    ROUND(po.min_avg_year, 2)   AS min_avg_year,
    ROUND(po.max_avg_year, 2)   AS max_avg_year,
    po.min_subject_name,
    po.max_subject_name
FROM pick_one po
JOIN students st ON st.student_id = po.student_id
JOIN groups   gr ON gr.group_id   = st.group_id;
GO

-- ============================================
-- 3) DEMO DATA
-- ============================================

INSERT INTO groups (group_name) VALUES
('CS-101'),
('IT-202');
GO

INSERT INTO students (full_name, city, country, date_of_birth, email, phone, group_id) VALUES
('John Smith', 'London', 'UK', '2002-03-14', 'john.smith@example.com', '+441234567890', 1),
('Emily Johnson', 'New York', 'USA', '2001-11-25', 'emily.johnson@example.com', '+12125552345', 1),
('Oleh Petrenko', 'Kyiv', 'Ukraine', '2003-05-09', 'oleh.petrenko@example.com', '+380671234567', 2);
GO

INSERT INTO subjects (subject_name) VALUES
('Mathematics'),
('Physics'),
('History'),
('Programming');
GO

-- John Smith
INSERT INTO grades (student_id, subject_id, academic_year, term, grade) VALUES
(1, 1, 2024, 'Fall',   85),
(1, 1, 2024, 'Spring', 90),
(1, 2, 2024, 'Fall',   78),
(1, 2, 2024, 'Spring', 80),
(1, 3, 2024, 'Fall',   92),
(1, 4, 2024, 'Spring', 88);
GO

-- Emily Johnson
INSERT INTO grades (student_id, subject_id, academic_year, term, grade) VALUES
(2, 1, 2024, 'Fall',   60),
(2, 1, 2024, 'Spring', 65),
(2, 2, 2024, 'Fall',   55),
(2, 2, 2024, 'Spring', 58),
(2, 3, 2024, 'Fall',   70),
(2, 4, 2024, 'Spring', 72);
GO

-- Oleh Petrenko
INSERT INTO grades (student_id, subject_id, academic_year, term, grade) VALUES
(3, 1, 2024, 'Fall',   95),
(3, 1, 2024, 'Spring', 92),
(3, 2, 2024, 'Fall',   88),
(3, 2, 2024, 'Spring', 90),
(3, 3, 2024, 'Fall',   84),
(3, 4, 2024, 'Spring', 96);
GO

-- ============================================
-- 4) SAMPLE QUERIES
-- ============================================

-- All info
SELECT * FROM v_student_year_stats;
GO

-- All student names
SELECT full_name FROM students ORDER BY full_name;
GO

-- All yearly averages
SELECT full_name, academic_year, avg_grade_year
FROM v_student_year_stats;
GO

-- Students with min grade > 60
SELECT full_name, academic_year, min_avg_year
FROM v_student_year_stats
WHERE min_avg_year > 60;
GO

-- Unique countries
SELECT DISTINCT country FROM students ORDER BY country;
GO

-- Unique cities
SELECT DISTINCT city FROM students ORDER BY city;
GO

-- Unique groups
SELECT DISTINCT group_name FROM groups ORDER BY group_name;
GO
