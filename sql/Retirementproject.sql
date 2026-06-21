

--- database creation
CREATE DATABASE IF NOT EXISTS retirement_claims_db;
USE retirement_claims_db;
CREATE TABLE retirement_claims (
    claim_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL,
    claim_date DATE NOT NULL,
    settlement_date DATE,
    claim_amount DECIMAL(15 , 2 ) NOT NULL,
    settled_amount DECIMAL(15 , 2 ),
    claim_status VARCHAR(20) NOT NULL,
    rejection_reason VARCHAR(100),
    agent_id VARCHAR(50),
    region VARCHAR(20),
    claim_type VARCHAR(50),
    turnaround_days INT
);

TRUNCATE TABLE retirement_claims;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/retirement_claims.csv'
INTO TABLE retirement_claims
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(claim_id, member_id, claim_date, @settlement_date, claim_amount, 
 settled_amount, claim_status, @rejection_reason, agent_id, 
 region, claim_type, @turnaround_days)
SET 
    settlement_date = NULLIF(@settlement_date, ''),
    rejection_reason = NULLIF(@rejection_reason, ''),
    turnaround_days = IF(@turnaround_days = '', NULL, CAST(@turnaround_days AS UNSIGNED));
   

SELECT *
FROM retirement_claims;

SELECT COUNT(*) as total_rows FROM retirement_claims;

--- the overall settlement rate (% of claims approved)

CREATE VIEW v_settlement_rate AS
SELECT
COUNT(*) AS total_claims,
SUM(claim_status = 'Rejected') AS rejected_claims,
SUM(claim_status = 'Pending') AS pending_claims,
SUM(claim_status = 'Settled') AS settled_claims,
ROUND(SUM(claim_status = 'Settled') / COUNT(*) * 100, 2) AS settlement_rate 
FROM retirement_claims;

--- the total claimed vs total settled amount?
CREATE VIEW v_toatal_vs_settled AS
SELECT 
    ROUND(SUM(claim_amount), 2) AS total_claimed,
    ROUND(SUM(settled_amount), 2) AS settled_amount
FROM
    retirement_claims;

---- Average claim amount by claim type 

CREATE VIEW v_avg_claim_amt AS
SELECT DISTINCT
claim_type,
AVG(claim_amount) OVER(PARTITION BY claim_type) AS avg_claim_amt
FROM
retirement_claims
ORDER BY avg_claim_amt DESC;

--- most common rejection reason

CREATE VIEW v__rejection_reasons AS
SELECT rejection_reason, COUNT(claim_id) AS total_count
FROM retirement_claims
WHERE claim_status = 'Rejected'
GROUP BY rejection_reason
ORDER BY total_count DESC;

--- rejection rate per claim_type

CREATE VIEW v_rejection_reason_per_claim_type AS
WITH claim_stats_type AS (
    SELECT 
        claim_type,
        claim_status,
        COUNT(*) OVER (PARTITION BY claim_type) as total_claims,
        SUM(claim_status = 'Rejected') OVER (PARTITION BY claim_type) as rejected_claims
    FROM retirement_claims
)
SELECT DISTINCT
    claim_type,
    total_claims,
    rejected_claims,
    ROUND(rejected_claims * 100.0 / total_claims, 2) as rejection_rate_type
FROM claim_stats_type
ORDER BY rejection_rate_type DESC;

--- rejection_rate per region

CREATE VIEW v_rejection_rate_per_region AS
WITH claim_stats_region AS (
SELECT
region, 
claim_status,
COUNT(*) OVER(PARTITION BY region) AS total_claims,
SUM(claim_status = 'Rejected') OVER(PARTITION BY region) AS rejected_claims
FROM retirement_claims)

SELECT DISTINCT
region,
total_claims,
rejected_claims,
ROUND(rejected_claims/total_claims * 100 , 2) AS rejection_rate_region
FROM
claim_stats_region
ORDER BY rejection_rate_region DESC;

--- Which agent has fastest turnaround


CREATE VIEW v_avg_turnaround_by_agent  AS
SELECT 
    agent_id, AVG(turnaround_days) AS avg_turnaround_days
FROM
    retirement_claims
GROUP BY agent_id
ORDER BY AVG(turnaround_days) ASC;

--- Average turnaround by claim type

CREATE VIEW v_avg_turnaround_by_claim_type AS
SELECT 
    claim_type,
    ROUND(AVG(turnaround_days), 2) AS avg_turnaround_days
FROM
    retirement_claims
GROUP BY claim_type
ORDER BY AVG(turnaround_days) ASC;

--- Average turnaround by region

CREATE VIEW v_avg_turnaround_by_region AS
SELECT 
    region,
    ROUND(AVG(turnaround_days), 2) AS avg_turnaround_days
FROM
    retirement_claims
GROUP BY region
ORDER BY AVG(turnaround_days) ASC;

--- Settlement ratio by claim type?

CREATE VIEW v_settlement_ratio_by_claim_type AS
WITH settled_stats AS
(
SELECT claim_type,
SUM(claim_amount) OVER(PARTITION BY claim_type) AS total_claimed,
SUM(settled_amount) OVER(PARTITION BY claim_type) AS total_settled
FROM retirement_claims
WHERE claim_status = 'Settled'
)
SELECT distinct
claim_type,
total_claimed,
total_settled,
ROUND(total_settled/total_claimed * 100, 2)  AS settlement_ratio
FROM settled_stats;


--- Total settlement loss by rejection reason?

CREATE VIEW v_settlement_loss_y_rejection_reason AS

  WITH rejection_loss AS (
    SELECT
        rejection_reason,
        COUNT(*) OVER(PARTITION BY rejection_reason) AS rejected_claims,
        SUM(claim_amount) OVER(PARTITION BY rejection_reason) AS total_loss,
        AVG(claim_amount) OVER(PARTITION BY rejection_reason) AS avg_loss
    FROM retirement_claims
    WHERE claim_status = 'Rejected'
)
SELECT DISTINCT
    rejection_reason,
    rejected_claims,
    ROUND(total_loss, 2) AS total_loss,
    ROUND(avg_loss, 2) AS avg_loss_per_claim
FROM rejection_loss
ORDER BY total_loss DESC;

--- Top 5 Agents by Overall Performance
CREATE VIEW v_top_5_agents AS
SELECT 
    agent_id,
    COUNT(*) AS total_claims,
    SUM(claim_status = 'Settled') AS settled_claims,
    ROUND(SUM(claim_status = 'Settled') * 100.0 / COUNT(*), 2) AS settlement_rate,
    ROUND(AVG(turnaround_days), 2) AS avg_turnaround
FROM retirement_claims
GROUP BY agent_id
ORDER BY settlement_rate DESC, avg_turnaround ASC
LIMIT 5;




