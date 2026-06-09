/* ============================================================================
 * 프로젝트  : HR Attrition Analytics - 임직원 이탈(Attrition) 분석 데이터 파이프라인
 * 설명      : 원본 CSV를 적재(Staging)한 뒤, 스타 스키마(차원/사실 테이블)로
 *             정규화하고, 최종적으로 BI(태블로) 분석용 마트 뷰를 생성한다.
 * 구조      : Staging(원본) → Dimension/Fact(모델링) → Mart(분석 뷰)
 * DBMS      : PostgreSQL
 * 작성자    : 전성훈
 * ============================================================================ */


/* ----------------------------------------------------------------------------
 * [1단계] 원본 데이터 적재용 스테이징(Staging) 테이블 생성
 *  - CSV의 모든 컬럼을 변형 없이 1:1로 받는 임시 테이블.
 *  - 이미 존재하면 삭제 후 재생성하여 멱등성(반복 실행 안전성)을 보장한다.
 * -------------------------------------------------------------------------- */
DROP TABLE IF EXISTS staging_hr_raw;

CREATE TABLE staging_hr_raw (
    Age INT,                          -- 나이
    Attrition VARCHAR(10),            -- 이탈 여부 (Yes/No)
    BusinessTravel VARCHAR(50),       -- 출장 빈도
    DailyRate INT,                    -- 일급(일일 급여율)
    Department VARCHAR(50),           -- 부서
    DistanceFromHome INT,             -- 집과의 거리
    Education INT,                    -- 교육 수준 (1~5 코드값)
    EducationField VARCHAR(50),       -- 전공 분야
    EmployeeCount INT,                -- 사원 수 (전체 동일 값, 분석 미사용)
    EmployeeNumber INT,               -- 사원 번호 (고유 식별자)
    EnvironmentSatisfaction INT,      -- 근무 환경 만족도 (1~4)
    Gender VARCHAR(10),               -- 성별
    HourlyRate INT,                   -- 시급
    JobInvolvement INT,               -- 업무 몰입도 (1~4)
    JobLevel INT,                     -- 직급 레벨
    JobRole VARCHAR(50),              -- 직무
    JobSatisfaction INT,              -- 직무 만족도 (1~4)
    MaritalStatus VARCHAR(20),        -- 결혼 상태
    MonthlyIncome INT,                -- 월 소득
    MonthlyRate INT,                  -- 월 급여율
    NumCompaniesWorked INT,           -- 이전 근무 회사 수
    Over18 VARCHAR(5),                -- 18세 이상 여부 (전체 'Y', 분석 미사용)
    OverTime VARCHAR(5),              -- 초과근무 여부 (Yes/No)
    PercentSalaryHike INT,            -- 급여 인상률(%)
    PerformanceRating INT,            -- 인사 평가 등급
    RelationshipSatisfaction INT,     -- 대인관계 만족도 (1~4)
    StandardHours INT,                -- 표준 근무 시간 (전체 동일, 분석 미사용)
    StockOptionLevel INT,             -- 스톡옵션 레벨
    TotalWorkingYears INT,            -- 총 경력 연수
    TrainingTimesLastYear INT,        -- 작년 교육 횟수
    WorkLifeBalance INT,              -- 워라밸 수준 (1~4)
    YearsAtCompany INT,               -- 현 회사 근속 연수
    YearsInCurrentRole INT,           -- 현 직무 수행 연수
    YearsSinceLastPromotion INT,      -- 마지막 승진 이후 연수
    YearsWithCurrManager INT          -- 현 관리자와 함께한 연수
);

/* CSV 파일을 스테이징 테이블로 일괄 적재
 *  - DELIMITER ','  : 쉼표 구분
 *  - CSV HEADER     : 첫 행(헤더)은 건너뜀
 *  - ENCODING UTF8  : 한글/특수문자 깨짐 방지 */
copy staging_hr_raw FROM 'C:/WA_Fn-UseC_-HR-Employee-Attrition.csv' DELIMITER ',' CSV HEADER ENCODING 'UTF8';


/* ----------------------------------------------------------------------------
 * [2단계] 기존 모델링 테이블 삭제
 *  - 외래키(FK) 참조 관계 때문에 자식(Fact) → 부모(Dimension) 순서로 삭제한다.
 *  - 순서를 지키지 않으면 참조 무결성 오류가 발생할 수 있다.
 * -------------------------------------------------------------------------- */
DROP TABLE IF EXISTS fact_compensation_retention;   -- 자식 Fact 테이블 1
DROP TABLE IF EXISTS fact_performance_eval;         -- 자식 Fact 테이블 2
DROP TABLE IF EXISTS dim_employees;                 -- 부모 Dim 테이블


/* ----------------------------------------------------------------------------
 * [3단계] 차원(Dimension) 테이블 생성 : 사원 마스터
 *  - 잘 변하지 않는 사원의 기본/직무 속성을 보관한다.
 *  - employee_number 를 기본키(PK)로 사용한다.
 * -------------------------------------------------------------------------- */
CREATE TABLE dim_employees (
    employee_number      INT PRIMARY KEY,                     -- 사원 번호 (PK)
    age                  INT,                                 -- 나이
    gender               VARCHAR(10),                         -- 성별
    education            INT,                                 -- 교육 수준 코드
    education_field      VARCHAR(50),                         -- 전공 분야
    marital_status       VARCHAR(20),                         -- 결혼 상태
    department           VARCHAR(50),                         -- 부서
    job_role             VARCHAR(50),                         -- 직무
    job_level            INT,                                 -- 직급 레벨
    distance_from_home   INT,                                 -- 집과의 거리
    business_travel      VARCHAR(50),                         -- 출장 빈도
    total_working_years  INT,                                 -- 총 경력 연수
    created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- 레코드 생성 시각
);

COMMENT ON TABLE dim_employees IS 'Employee master dimension: basic profile and job attributes';


/* ----------------------------------------------------------------------------
 * [4단계] Fact 테이블 생성 : 인사평가 & 만족도
 *  - employee_number 는 PK이자 dim_employees 를 참조하는 FK이다.
 *  - 1:1 관계(사원 1명당 평가 1건)를 보장한다.
 * -------------------------------------------------------------------------- */
CREATE TABLE fact_performance_eval (
    employee_number           INT PRIMARY KEY REFERENCES dim_employees(employee_number), -- 사원 번호 (PK/FK)
    performance_rating        INT,   -- 인사 평가 등급
    job_involvement           INT,   -- 업무 몰입도
    job_satisfaction          INT,   -- 직무 만족도
    environment_satisfaction  INT,   -- 근무 환경 만족도
    relationship_satisfaction INT,   -- 대인관계 만족도
    work_life_balance         INT,   -- 워라밸 수준
    updated_at                TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- 레코드 갱신 시각
);

COMMENT ON TABLE fact_performance_eval IS 'Fact table: employee performance evaluation and job satisfaction';


/* ----------------------------------------------------------------------------
 * [5단계] Fact 테이블 생성 : 보상 & 이탈
 *  - 급여, 승진 이력, 초과근무, 최종 이탈 여부 등 분석 핵심 지표를 보관한다.
 * -------------------------------------------------------------------------- */
CREATE TABLE fact_compensation_retention (
    employee_number            INT PRIMARY KEY REFERENCES dim_employees(employee_number), -- 사원 번호 (PK/FK)
    monthly_income             INT,          -- 월 소득
    percent_salary_hike        INT,          -- 급여 인상률(%)
    stock_option_level         INT,          -- 스톡옵션 레벨
    years_at_company           INT,          -- 현 회사 근속 연수
    years_in_current_role      INT,          -- 현 직무 수행 연수
    years_since_last_promotion INT,          -- 마지막 승진 이후 연수
    years_with_curr_manager    INT,          -- 현 관리자와 함께한 연수
    overtime                   VARCHAR(5),   -- 초과근무 여부 (Yes/No)
    attrition                  VARCHAR(5),   -- 이탈(퇴사) 여부 ('Yes' 또는 'No')
    updated_at                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- 레코드 갱신 시각
);

COMMENT ON TABLE fact_compensation_retention IS 'Fact table: compensation structure, promotion history, and final attrition';


/* ----------------------------------------------------------------------------
 * [6단계] 데이터 적재(ETL) : 스테이징 → Dim/Fact 테이블
 *  - 반드시 부모(dim) → 자식(fact) 순서로 적재해야 FK 제약을 위반하지 않는다.
 * -------------------------------------------------------------------------- */

-- (6-1) 사원 Dim 테이블 적재 (DISTINCT로 중복 사원 제거)
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

-- (6-2) 인사평가 Fact 테이블 적재
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

-- (6-3) 보상/이탈 Fact 테이블 적재
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
 * [7단계] 적재 검증 (Validation)
 *  - 각 테이블의 건수를 비교하여 누락/중복 없이 적재되었는지 확인한다.
 *  - 정상이라면 네 컬럼의 값이 모두 동일해야 한다.
 * -------------------------------------------------------------------------- */
SELECT 
    (SELECT COUNT(*) FROM staging_hr_raw)                as staging_count,        -- 원본 건수
    (SELECT COUNT(*) FROM dim_employees)                 as dim_employee_count,   -- 사원 차원 건수
    (SELECT COUNT(*) FROM fact_performance_eval)         as fact_perf_count,      -- 인사평가 건수
    (SELECT COUNT(*) FROM fact_compensation_retention)   as fact_comp_count;      -- 보상/이탈 건수


/* ----------------------------------------------------------------------------
 * [8단계] 분석 쿼리 : 부서/직무별 이탈 현황 요약
 *  - 세 테이블을 조인하여 부서·직무 단위로 집계한다.
 *  - 이탈 건수 많은 순 → 인원 많은 순으로 정렬한다.
 * -------------------------------------------------------------------------- */
SELECT 
    e.department,                                                             -- 부서
    e.job_role,                                                               -- 직무
    COUNT(e.employee_number)                          as total_employees,     -- 총 인원
    ROUND(AVG(c.monthly_income), 2)                   as avg_monthly_income,  -- 평균 월 소득
    ROUND(AVG(p.performance_rating), 2)               as avg_performance,     -- 평균 평가 등급
    SUM(CASE WHEN c.attrition = 'Yes' THEN 1 ELSE 0 END) as attrition_cases   -- 이탈 건수
FROM dim_employees e
JOIN fact_performance_eval p        ON e.employee_number = p.employee_number
JOIN fact_compensation_retention c  ON e.employee_number = c.employee_number
GROUP BY e.department, e.job_role
ORDER BY attrition_cases DESC, total_employees DESC;


/* ----------------------------------------------------------------------------
 * [9단계] 분석 마트(Mart) 뷰 생성 : 태블로 대시보드 전용
 *  - 세 테이블을 통합하고, 코드값을 사람이 읽기 쉬운 라벨로 가공한다.
 *  - 연령대 그룹핑, 학력 라벨링, 스톡옵션 부여 여부, 이탈 플래그(0/1) 등 파생 컬럼 포함.
 *  - 뷰(View)로 만들어 원본을 건드리지 않고 항상 최신 데이터를 조회한다.
 * -------------------------------------------------------------------------- */
CREATE OR REPLACE VIEW mart_hr_attrition_dashboard AS
SELECT
    e.employee_number,
    e.age,
    -- 나이를 분석용 연령대 구간으로 변환
    CASE 
        WHEN e.age < 30 THEN '20대'
        WHEN e.age >= 30 AND e.age < 40 THEN '30대'
        WHEN e.age >= 40 AND e.age < 50 THEN '40대'
        ELSE '50대 이상'
    END AS age_group,
    e.gender,
    e.marital_status,
    -- 교육 수준 코드(1~5)를 의미 있는 라벨로 변환
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
    -- 스톡옵션 부여 여부를 가시성 좋게 변환
    CASE WHEN c.stock_option_level > 0 THEN '부여' ELSE '미부여' END AS has_stock_option,
    c.years_at_company,
    c.years_in_current_role,
    c.years_since_last_promotion,
    c.years_with_curr_manager,
    c.overtime,
    c.attrition,
    -- 이탈 여부를 집계(SUM/AVG)에 바로 쓸 수 있도록 0/1 숫자 플래그로 변환
    CASE WHEN c.attrition = 'Yes' THEN 1 ELSE 0 END AS is_attrition
FROM dim_employees e
INNER JOIN fact_performance_eval p        ON e.employee_number = p.employee_number
INNER JOIN fact_compensation_retention c  ON e.employee_number = c.employee_number;

COMMENT ON VIEW mart_hr_attrition_dashboard IS 'Core HR mart dedicated to Tableau dashboard visualization and data extraction';
