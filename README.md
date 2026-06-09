
# HR-ATTRITION-ANALYTICS — Tableau Portfolio

> Advanced Tableau BI solution for HR analytics. Features parameter-driven dynamic views, set actions, and cohort analysis to identify high-performer churn and workforce attrition trends.

![Status](https://img.shields.io/badge/status-completed-success)
![Tableau](https://img.shields.io/badge/Tableau-2024.1-E97627?logo=tableau&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-CSV%20Relations-336791)

---

## 🎯 Project Overview

This portfolio reconstructs the analytics workflow of a strategic HR organization, focusing on actionable insights for talent retention. Built with Tableau, the dashboard provides a deep dive into workforce attrition, directly addressing key responsibilities of a Senior Data Analyst:

| Dashboard | JD Responsibility | Key Question Answered |
|---|---|---|
| **1. Executive Attrition Overview** | Executive Reporting & Analytics | What is the overall attrition rate and which departments are at risk? |
| **2. Demographic Deep Dive** | Workforce Diversity Analysis | How do age, gender, and education impact employee turnover? |
| **3. Engagement Correlation** | Employee Survey Analysis | Which satisfaction metrics strongly correlate with employee exits? |
| **4. Talent Insights Deep Dive** | Talent Retention Strategy | Are we losing top-tier talent due to uncompetitive compensation? |

---

## 🛠 Tech Stack

- **Data Model** - Flat HR dataset normalized for BI consumption
- **Tableau Desktop 2024.1** — Relationship-based data modeling, LOD expressions, calculated fields
- **UI/UX Design** — Advanced padding structures (Card UI), Custom typography alignment (Gantt-aligned text tables)
---

## 📊 Dashboard: HR Attrition Dashboard

**Audience**: CHRO, HR Executives

![Dashboard](./screenshots/Overview.png)

### Key Insights
- **16.1%** Overall Attrition Rate (237 voluntary exits out of 1,470 employees).
- Peak Attrition Tenure: **24.9%** of total attrition occurs specifically at the 1-Year mark, signaling a critical gap in early-tenure retention programs.
- Job Role Risk: **Sales Executives and Laboratory Technicians** demonstrate the highest volume of turnover.
- Engagement Drivers: Employees scoring **1 in Environment Satisfaction and Job Involvement** account for a disproportionately large share of exits.
- High-Performer Attrition Risk: Identified critical cases (e.g., R&D Research Scientists with a Performance Rating of 4) leaving despite receiving **20%+ salary hikes**.

### 💡 Actionable Recommendations (Strategic Next Steps)

Based on the diagnostic insights, the following data-driven interventions are recommended to leadership:

* **Targeted "Year-1" Retention Program:** Since 24.9% of attrition peaks at the 1-year mark, HR should implement proactive milestone check-ins at 3, 6, and 9 months, specifically focusing on onboarding alignment and early career pathing.
* **Compensation Realignment for R&D Top Talent:** The flight risk of High Performers (Rating 4+) in R&D suggests current salary hikes (even at 20%) are lagging behind the market rate. Recommend an immediate compensation benchmark review and targeted retention bonuses for top-quartile engineers.
* **Work Environment Intervention:** Establish immediate focus groups for employees who scored '1' in Environment Satisfaction to identify specific pain points (e.g., remote work flexibility, facility conditions) and deploy quick-win improvements to halt the immediate churn.
  
### Components
- 3 KPI Cards (Attrition Rate, Total Attrition, Current Employees)
- Demographics Toggles: Donut charts (Gender), Bar charts (Age, Education) with parameter-driven dimension swapping
- Heatmap: Survey Score correlation vs. Attrition volume
- Gantt-aligned Text Table: High Performer Attrition detailed list

---

## 🗂️ Logical Data Model

Unlike traditional star schemas, this project utilizes a **denormalized flat file architecture** optimized for rapid BI consumption and extract performance. The dataset (`~1.5K rows, 35 columns`) is logically partitioned into four analytical domains:

```
[ WA_Fn-UseC_-HR-Employee-Attrition.csv ]
 │
 ├── 🧑‍🤝‍🧑 Demographics
 │   ├── Age, Gender
 │   └── Education_Level, Education_Field
 │
 ├── 🏢 Job Information
 │   ├── Department, Job_Role, Job_Level
 │   ├── Years_At_Company, Years_In_Current_Role
 │   └── Monthly_Income, Percent_Salary_Hike
 │
 ├── 📊 Survey & Performance
 │   ├── Environment_Satisfaction    # (1-4)
 │   ├── Job_Satisfaction            # (1-4)
 │   ├── Job_Involvement             # (1-4)
 │   ├── Relationship_Satisfaction   # (1-4)
 │   ├── Work_Life_Balance           # (1-4)
 │   └── Performance_Rating          # (3-4)
 │
 └── 🎯 Target Variable
     └── Attrition (Yes / No)
```

---

## 📁 Repository Structure

```
HR-ATTRITION-ANALYTICS/
├── README.md                                    # Project overview & setup guide
├── SQL                                          # Data pipeline SQL scripts
│   ├── hr_pipeline_en.sql                       # ETL pipeline (English comments)
│   └── hr_pipeline_ko.sql                       # ETL pipeline (Korean comments)
├── data/
│   └── WA_Fn-UseC_-HR-Employee-Attrition.csv    # Source data
├── tableau/
│   └── hr_attrition_dashboard.twbx              # Packaged Tableau workbook
└── screenshots/                                 # Dashboard screenshots
    └── overview.png
```

---

## 🎨 Design Principles

This portfolio adopts the following design philosophy:

- **UI Architecture** — #FFFFFF floating containers on a #F4F6F8 background with calculated 4-8px outer padding.
- **Visual Hierarchy** — Dominant KPI numbers at the top, supported by high-contrast section headers (e.g., O V E R V I E W)
- **Color discipline** — Strict usage of vibrant orange (#F28E2B), exclusively for the target metric (Attrition) against neutral slate grays.
- **Typography** — Tableau Book / Tableau Semibold / Tableau Bold

---

## 📌 Key Calculated Fields (Tableau)

This dashboard heavily utilizes Level of Detail (LOD) expressions and Advanced Table Calculations to maintain accurate aggregations across dynamic views.

```
// 1. Dynamic Tenure X-Axis [Parameter-Driven Grouping]
// Dynamically alters the granularity of the x-axis based on user selection (1Y, 3Y, 5Y)
IF [Toggle - Tenure Bin] = 1 THEN
    IF [Years At Company] = 0 THEN '< 1'
    ELSEIF [Years At Company] = 1 THEN '1'
    ELSEIF [Years At Company] >= 11 THEN '11+'
    ELSE STR([Years At Company]) END
ELSEIF [Toggle - Tenure Bin] = 3 THEN
    IF [Years At Company] >= 12 THEN '12+'
    ELSE STR(INT([Years At Company]/3) * 3) + ' ~ ' + STR(INT([Years At Company]/3) * 3 + 2) END
ELSEIF [Toggle - Tenure Bin] = 5 THEN
    IF [Years At Company] >= 15 THEN '15+ '
    ELSE STR(INT([Years At Company]/5) * 5) + ' ~ ' + STR(INT([Years At Company]/5) * 5 + 4) END
END

// 2. Attrition Count per Bin [FIXED LOD]
// Calculates total attrition fixed to the dynamically generated tenure bins
{ FIXED [Dynamic Tenure X-Axis] : SUM([Is Attrition]) }

// 3. Max Attrition Count [Nested LOD]
// Identifies the peak attrition value to dynamically adjust axis ranges or trigger highlights
{ MAX([Attrition Count per Bin]) }

// 4. Attrition Rate % [EXCLUDE LOD]
// Ensures the denominator (Total Employees) remains static even when attrition status is filtered
SUM(IF [Attrition] = 'Yes' THEN 1 ELSE 0 END) 
/ 
MIN({ EXCLUDE [Attrition] : COUNTD([Employee Number]) })

// 5. Color Intensity Normalization [Advanced Table Calculation]
// Normalizes color gradients independently for Attrition (0 to 1) and Retention (0 to -1)
IF MIN([Switch Attrition/Retention 2]) = 'Attrition employees' THEN
    (COUNTD([Employee Number]) - WINDOW_MIN(COUNTD([Employee Number])))
    / 
    (WINDOW_MAX(COUNTD([Employee Number])) - WINDOW_MIN(COUNTD([Employee Number])))

ELSEIF MIN([Switch Attrition/Retention 2]) = 'Current employees' THEN
    - ( (COUNTD([Employee Number]) - WINDOW_MIN(COUNTD([Employee Number])))
    / 
    (WINDOW_MAX(COUNTD([Employee Number])) - WINDOW_MIN(COUNTD([Employee Number]))) )
ELSE 
    0
END
```

---

## 📬 Contact

**[Sunghoon Jun]** — Data Analyst
- 📧 trixar17@gmail.com
- 💼 [LinkedIn](https://www.linkedin.com/in/trixar17)
- 📊 [Tableau Public](https://public.tableau.com/app/profile/sunghoon.jun)
- 🧾 [Notion](https://www.notion.so/HR-ATTRITION-DASHBOARD-PORTFOLIO-379b35986d7980479fccc5e7019aca1b)

---

## 📄 License

This project uses **synthetic data only**. Built for portfolio purposes.

