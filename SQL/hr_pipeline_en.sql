/* ============================================================================
 * Project     : HR Attrition Analytics - Employee Attrition Data Pipeline
 * Description : Loads the raw CSV into a staging table, normalizes it into a
 *               star schema (dimension/fact tables), and finally builds a
 *               BI (Tableau) analytics mart view.
 * Flow        : Staging (raw) -> Dimension/Fact (modeling) -> Mart (view)
 * DBMS        : PostgreSQL
 * Author      : Jun Sunghoon
 * ============================================================================ */


/* ----------------------------------------------------------------------------
 * [STEP 1] Create the staging table for raw data ingestion
 *  - A temporary table that maps every CSV column 1:1 without transformation.
 *  - Dropped and recreated if it exists to keep the script idempotent.
 * -------------------------------------------------------------------------- */
DROP TABLE IF EXISTS staging_hr_raw;

CREATE TABLE staging_hr_raw (
    Age INT,                          -- Employee age
    Attrition VARCHAR(10),            -- Attrition flag (Yes/No)
    BusinessTravel VARCHAR(50),       -- Business travel frequency
    DailyRate INT,                    -- Daily pay rate
    Department VARCHAR(50),           -- Department
    DistanceFromHome INT,             -- Distance from home
    Education INT,                    -- Education level (code 1-5)
    EducationField VARCHAR(50),       -- Field of education
    EmployeeCount INT,                -- Employee count (constant, unused)
    EmployeeNumber INT,               -- Employee number (unique identifier)
    EnvironmentSatisfaction INT,      -- Environment satisfaction (1-4)
    Gender VARCHAR(10),               -- Gender
    HourlyRate INT,                   -- Hourly pay rate
    JobInvolvement INT,               -- Job involvement (1-4)
    JobLevel INT,                     -- Job level
    JobRole VARCHAR(50),              -- Job role
    JobSatisfaction INT,              -- Job satisfaction (1-4)
    MaritalStatus VARCHAR(20),        -- Marital status
    MonthlyIncome INT,                -- Monthly income
    MonthlyRate INT,                  -- Monthly pay rate
    NumCompaniesWorked INT,           -- Number of previous companies
    Over18 VARCHAR(5),                -- Over 18 flag (constant 'Y', unused)
    OverTime VARCHAR(5),              -- Overtime flag (Yes/No)
    PercentSalaryHike INT,            -- Salary hike percentage
    PerformanceRating INT,            -- Performance rating
    RelationshipSatisfaction INT,     -- Relationship satisfaction (1-4)
    StandardHours INT,                -- Standard hours (constant, unused)
    StockOptionLevel INT,             -- Stock option level
    TotalWorkingYears INT,            -- Total working years
    TrainingTimesLastYear INT,        -- Training sessions last year
    WorkLifeBalance INT,              -- Work-life balance (1-4)
    YearsAtCompany INT,               -- Years at the company
    YearsInCurrentRole INT,           -- Years in current role
    YearsSinceLastPromotion INT,      -- Years since last promotion
    YearsWithCurrManager INT          -- Years with current manager
);

/* Bulk-load the CSV file into the staging table
 *  - DELIMITER ','  : comma-separated
 *  - CSV HEADER     : skip the first (header) row
 *  - ENCODING UTF8  : avoid garbled multibyte/special characters */
copy staging_hr_raw FROM 'C:/WA_Fn-UseC_-HR-Employee-Attrition.csv' DELIMITER ',' CSV HEADER ENCODING 'UTF8';


/* ----------------------------------------------------------------------------
 * [STEP 2] Drop existing modeling tables
 *  - Drop in child (fact) -> parent (dimension) order due to FK references.
 *  - Ignoring this order would raise referential-integrity errors.
 * -------------------------------------------------------------------------- */
DROP TABLE IF EXISTS fact_compensation_retention;   -- Child fact table 1
DROP TABLE IF EXISTS fact_performance_eval;         -- Child fact table 2
DROP TABLE IF EXISTS dim_employees;                 -- Parent dimension table


/* ----------------------------------------------------------------------------
 * [STEP 3] Create the dimension table: employee master
 *  - Stores slowly-changing basic/job attributes of an employee.
 *  - Uses employee_number as the primary key (PK).
 * -------------------------------------------------------------------------- */
CREATE TABLE dim_employees (
    employee_number      INT PRIMARY KEY,                     -- Employee number (PK)
    age                  INT,                                 -- Age
    gender               VARCHAR(10),                         -- Gender
    education            INT,                                 -- Education level code
    education_field      VARCHAR(50),                         -- Field of education
    marital_status       VARCHAR(20),                         -- Marital status
    department           VARCHAR(50),                         -- Department
    job_role             VARCHAR(50),                         -- Job role
    job_level            INT,                                 -- Job level
    distance_from_home   INT,                                 -- Distance from home
    business_travel      VARCHAR(50),                         -- Business travel frequency
    total_working_years  INT,                                 -- Total working years
    created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- Record creation time
);

COMMENT ON TABLE dim_employees IS 'Employee master dimension: basic profile and job attributes';


/* ----------------------------------------------------------------------------
 * [STEP 4] Create the fact table: performance evaluation & satisfaction
 *  - employee_number is both the PK and an FK referencing dim_employees.
 *  - Enforces a 1:1 relationship (one evaluation per employee).
 * -------------------------------------------------------------------------- */
CREATE TABLE fact_performance_eval (
    employee_number           INT PRIMARY KEY REFERENCES dim_employees(employee_number), -- Employee number (PK/FK)
    performance_rating        INT,   -- Performance rating
    job_involvement           INT,   -- Job involvement
    job_satisfaction          INT,   -- Job satisfaction
    environment_satisfaction  INT,   -- Environment satisfaction
    relationship_satisfaction INT,   -- Relationship satisfaction
    work_life_balance         INT,   -- Work-life balance
    updated_at                TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- Record update time
);

COMMENT ON TABLE fact_performance_eval IS 'Fact table: employee performance evaluation and job satisfaction';


/* ----------------------------------------------------------------------------
 * [STEP 5] Create the fact table: compensation & retention
 *  - Holds core analytic metrics: pay, promotion history, overtime, attrition.
 * -------------------------------------------------------------------------- */
CREATE TABLE fact_compensation_retention (
    employee_number            INT PRIMARY KEY REFERENCES dim_employees(employee_number), -- Employee number (PK/FK)
    monthly_income             INT,          -- Monthly income
    percent_salary_hike        INT,          -- Salary hike percentage
    stock_option_level         INT,          -- Stock option level
    years_at_company           INT,          -- Years at the company
    years_in_current_role      INT,          -- Years in current role
    years_since_last_promotion INT,          -- Years since last promotion
    years_with_curr_manager    INT,          -- Years with current manager
    overtime                   VARCHAR(5),   -- Overtime flag (Yes/No)
    attrition                  VARCHAR(5),   -- Attrition flag ('Yes' or 'No')
    updated_at                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- Record update time
);

COMMENT ON TABLE fact_compensation_retention IS 'Fact table: compensation structure, promotion history, and final attrition';


/* ----------------------------------------------------------------------------
 * [STEP 6] ETL load: staging -> dimension/fact tables
 *  - Must load parent (dim) before children (fact) to satisfy FK constraints.
 * -------------------------------------------------------------------------- */

-- (6-1) Load the employee dimension (DISTINCT removes duplicate employees)
INSERT INTO dim_employees (
    employee_number, age, gender, education, education_field, 
    marital_status, department, job_role, job_level, 
    distance_from_home, business_travel, total_working_years
)
SELECT DISTINCT 
    EmployeeNumber, Age, Gender, Education, EducationField, 
    MaritalStatus, Department, JobRole, JobLevel, 
    DistanceFromHome, BusinessTravel, TotalWorkingYears
FROM staging_hr_raw;

-- (6-2) Load the performance-evaluation fact table
INSERT INTO fact_performance_eval (
    employee_number, performance_rating, job_involvement, 
    job_satisfaction, environment_satisfaction, relationship_satisfaction, 
    work_life_balance
)
SELECT 
    EmployeeNumber, PerformanceRating, JobInvolvement, 
    JobSatisfaction, EnvironmentSatisfaction, RelationshipSatisfaction, 
    WorkLifeBalance
FROM staging_hr_raw;

-- (6-3) Load the compensation/attrition fact table
INSERT INTO fact_compensation_retention (
    employee_number, monthly_income, percent_salary_hike, 
    stock_option_level, years_at_company, years_in_current_role, 
    years_since_last_promotion, years_with_curr_manager, overtime, attrition
)
SELECT 
    EmployeeNumber, MonthlyIncome, PercentSalaryHike, 
    StockOptionLevel, YearsAtCompany, YearsInCurrentRole, 
    YearsSinceLastPromotion, YearsWithCurrManager, OverTime, Attrition
FROM staging_hr_raw;


/* ----------------------------------------------------------------------------
 * [STEP 7] Load validation
 *  - Compare row counts across tables to confirm no rows were lost/duplicated.
 *  - All four columns should be equal if the load succeeded.
 * -------------------------------------------------------------------------- */
SELECT 
    (SELECT COUNT(*) FROM staging_hr_raw)                as staging_count,        -- Source rows
    (SELECT COUNT(*) FROM dim_employees)                 as dim_employee_count,   -- Dimension rows
    (SELECT COUNT(*) FROM fact_performance_eval)         as fact_perf_count,      -- Performance rows
    (SELECT COUNT(*) FROM fact_compensation_retention)   as fact_comp_count;      -- Compensation rows


/* ----------------------------------------------------------------------------
 * [STEP 8] Analytics query: attrition summary by department/job role
 *  - Joins the three tables and aggregates at the department/job-role level.
 *  - Sorted by attrition count desc, then headcount desc.
 * -------------------------------------------------------------------------- */
SELECT 
    e.department,                                                       -- Department
    e.job_role,                                                         -- Job role
    COUNT(e.employee_number)                          as total_employees,     -- Headcount
    ROUND(AVG(c.monthly_income), 2)                   as avg_monthly_income,  -- Avg monthly income
    ROUND(AVG(p.performance_rating), 2)               as avg_performance,     -- Avg performance rating
    SUM(CASE WHEN c.attrition = 'Yes' THEN 1 ELSE 0 END) as attrition_cases   -- Attrition count
FROM dim_employees e
JOIN fact_performance_eval p        ON e.employee_number = p.employee_number
JOIN fact_compensation_retention c  ON e.employee_number = c.employee_number
GROUP BY e.department, e.job_role
ORDER BY attrition_cases DESC, total_employees DESC;


/* ----------------------------------------------------------------------------
 * [STEP 9] Create the analytics mart view: Tableau dashboard only
 *  - Unifies the three tables and converts code values into human-readable labels.
 *  - Derived columns: age grouping, education label, stock-option flag, 0/1 attrition flag.
 *  - Implemented as a VIEW so it always reflects the latest data without touching sources.
 * -------------------------------------------------------------------------- */
CREATE OR REPLACE VIEW mart_hr_attrition_dashboard AS
SELECT
    e.employee_number,
    e.age,
    -- Bucket age into analytic age groups
    CASE 
        WHEN e.age < 30 THEN '20s'
        WHEN e.age >= 30 AND e.age < 40 THEN '30s'
        WHEN e.age >= 40 AND e.age < 50 THEN '40s'
        ELSE '50s and above'
    END AS age_group,
    e.gender,
    e.marital_status,
    -- Map the education code (1-5) to a meaningful label
    CASE e.education
        WHEN 1 THEN 'Below College'
        WHEN 2 THEN 'College'
        WHEN 3 THEN 'Bachelor'
        WHEN 4 THEN 'Master'
        WHEN 5 THEN 'Doctor'
        ELSE 'Unknown'
    END AS education_level,
    e.education_field,
    e.department,
    e.job_role,
    e.job_level,
    e.distance_from_home,
    e.business_travel,
    e.total_working_years,
    p.performance_rating,
    p.job_involvement,
    p.job_satisfaction,
    p.environment_satisfaction,
    p.relationship_satisfaction,
    p.work_life_balance,
    c.monthly_income,
    c.percent_salary_hike,
    c.stock_option_level,
    -- Convert stock-option level into a readable granted/not-granted flag
    CASE WHEN c.stock_option_level > 0 THEN 'Granted' ELSE 'Not Granted' END AS has_stock_option,
    c.years_at_company,
    c.years_in_current_role,
    c.years_since_last_promotion,
    c.years_with_curr_manager,
    c.overtime,
    c.attrition,
    -- Numeric 0/1 flag so attrition can be summed/averaged directly
    CASE WHEN c.attrition = 'Yes' THEN 1 ELSE 0 END AS is_attrition
FROM dim_employees e
INNER JOIN fact_performance_eval p        ON e.employee_number = p.employee_number
INNER JOIN fact_compensation_retention c  ON e.employee_number = c.employee_number;

COMMENT ON VIEW mart_hr_attrition_dashboard IS 'Core HR mart dedicated to Tableau dashboard visualization and data extraction';
