USE Banking_transaction;
SELECT * From customers;
-- Customers Insight 
-- Number of customers by state (Maharashtra has the highest customers with 11,981 customers, accounting form 19.97% ) 
WITH customer_by_state AS (
	Select state,
		Count(customer_id) as total_customers 
	From customers
	Group By state
)
Select state, total_customers, 
	Round(total_customers * 100/(Select SUM(total_customers) FROM customer_by_state),2) AS percentage 
FROM customer_by_state
ORDER BY percentage DESC;

-- customers by gender
-- The dataset shows a relatively balanced gender distribution, with males making up the largest share of customers at 31,344 (52.24%), 
-- followed by females at 27,412 (45.69%). Customers identifying as Other account for 1,244 (2.07%) of the total.
-- Overall, the customer base is slightly male-dominated, while the female segment also represents a substantial proportion. 

WITH gender_catergory  AS (
select gender,
count(gender) AS total_number
FROM customers
group by gender
)
Select gender, total_number,
(SELECT total_number * 100/(SELECT sum(total_number) from gender_catergory)) AS percentage From gender_catergory;



-- New customers acquired each month 
-- The analysis shows that customer registrations are fairly consistent throughout the year. 
-- August had the highest number of new customers (5,171), while February had the lowest (4,617). 
-- The relatively small difference of 554 registrations between the highest and lowest months suggests there is no significant seasonal variation in customer sign-ups,
--  indicating stable customer acquisition across the year.
WITH MONTh_rentention  AS (
Select MONTH(join_date) AS months,
MONTHNAME(join_date) AS Month_Name,
format(count(*),-2) AS Joined_by_month
FROM customers
Group by MONTH(join_date),MONTHNAME(join_date)
)
SELECT *,
ROW_NUMBER() over (order by Joined_by_month DESC) AS Ranking 
from MONTh_rentention
ORDER BY Ranking;

-- customers with Top 5 annual income and credit score 
WITH customers_ranking  AS (
Select name, 
FORMAT (annual_income,-2), 
RANK() over(order by annual_income ASC) AS income_rnk
from customers
)
SELECT * FROM customers_ranking
WHERE income_rnk <= 5
LIMIT 5;

-- customers with Top 5 credit score 
WITH customers_ranking  AS (
Select name,
credit_score,
RANK() over(order by credit_score ASC) AS credit_ranking
from customers
)
SELECT * FROM customers_ranking
WHERE credit_ranking <= 5
LIMIT 5;

-- The analysis shows that Private Salaried customers have the highest average annual income (1,834,832) and 
-- the highest total annual income (15.86 billion), making them the strongest earning group. 
-- Freelancers have the lowest average income (1,809,176), despite having the largest number of people.
Select occupation, 
count(occupation) AS Number_of_People,
	FORMAT(sum(annual_income),-2) AS Annual_Income,
   FORMAT(AVG(annual_income),-2) AS Average_Income
From customers
GROUP BY occupation
ORDER BY Average_Income DESC;


SELECT * From customers;
-- Total Balance across all acounts 
SELECT account_type,
		FORMAT(sum(balance),0) AS Balance, 
        FORMAT(AVG(balance),-2) As Average_Balance 
From accounts
GROUP BY account_type ;


-- Total Balance by account status 
SELECT status,
		FORMAT(SUM(balance),2) AS Balance,
        FORMAT(AVG(balance),2) AS Balance
From accounts
GROUP BY status ;


-- Total Balance by Dormant account by year 
SELECT year(open_date) AS year,
		FORMAT(sum(balance),2) AS Balance 
From accounts
WHERE status = 'Dormant'
GROUP BY year;

-- Deposit vs withdrawal ratio. 
-- Deposits and withdrawals are almost evenly distributed, accounting for 39.84% and 40.19% of all transactions, respectively. Withdrawals slightly exceed deposits by 0.35%, 
-- indicating customers are withdrawing funds just marginally more often than they are depositing them. The remaining 19.97% of transactions consist of other transaction types,
-- suggesting additional banking activities such as transfers or card payments that warrant further analysis. 
-- Overall, the transaction pattern reflects a balanced flow of funds and stable customer banking activity. 
SELECT
    txn_type, 
    Round(sum(amount) * 100/(SELECT sum(amount) FROM transactions),2) AS Percentage 
FROM transactions
WHERE txn_type IN ('Deposit', 'Withdrawal')
GROUP BY txn_type;

-- Customer with highest account balance 
WITH customer_Balance AS (
SELECT 
		c.name, c.gender, c.credit_score, c.join_date,
		c.occupation, FORMAT(a.balance,2) AS balance,
        ROW_NUMBER() OVER(ORDER BY balance DESC) AS RNK
From
		accounts a
	JOIN customers c ON a.customer_id = c.customer_id
    
)
	Select name, 
		   gender,
           occupation,
           credit_score,
           balance,
           join_date
	FROM customer_Balance
    WHERE RNK <= 5 ;

-- Average balance by Branch 

WITH branch_summary AS(
SELECT
		b.branch_id,
        b.branch_name, 
		concat(b.city," "," ,",b.state) AS Location , 
        FORMAT(sum(a.balance),-2) AS Balance_Amount,
        FORMAT(avg(a.balance),-2) AS Average_Balance
From
		branches b
JOIN accounts a ON b.branch_id = a.branch_id
-- Where account_type = 'Savings'
GROUP BY branch_id, branch_name, location
)
SELECT * FROM branch_summary
ORDER BY Average_Balance DESC
LIMIT 5
;


UPDATE transactions
SET txn_type = 'Withdrawal'
Where txn_type = 'Transfer Out';

UPDATE transactions
SET txn_type = 'Deposit'
Where txn_type = 'Transfer In';


SELECT txn_type, 
		 SUM(amount) AS amount
From transactions
Group By txn_type;	


DESCRIBE cards;
ALTER TABLE cards
MODIFY COLUMN expiry_date DATE;
SELECT * From cards;


-- Number of active cards 
-- 40945 cards have expired 
WITH card_investigation AS (
    SELECT c.name,
           ca.card_type,
           ca.issue_date,
           ca.expiry_date,
           CASE
               WHEN ca.expiry_date > CURDATE() THEN 'ACTIVE'
               WHEN ca.expiry_date < CURDATE() THEN 'Expired'
               ELSE 'Blocked'
           END AS status
    FROM customers c
    JOIN cards ca
      ON c.customer_id = ca.customer_id
)
SELECT *
FROM card_investigation
WHERE status = 'Expired';


 -- Identified 3530 dormant accounts holding a combined balance of 4,717,860,442 Ruppees (£36.74 million). Despite inactivity, many accounts still have valid payment cards, 
 -- highlighting potential operational and compliance consideration. 
 
WITH dormant_account AS (
    SELECT
        c.customer_id,
        c.name,
        SUM(a.balance) AS total_balance,
        ca.card_type,
        ca.issue_date,
        ca.expiry_date,
        CASE
            WHEN ca.expiry_date > CURDATE() THEN 'ACTIVE'
            WHEN ca.expiry_date < CURDATE() THEN 'Expired'
            ELSE 'Blocked'
        END AS card_status,
        a.status AS account_status
    FROM customers c
    JOIN cards ca
        ON c.customer_id = ca.customer_id
    JOIN accounts a
        ON c.customer_id = a.customer_id
    GROUP BY
        c.customer_id,
        c.name,
        ca.card_type,
        ca.issue_date,
        ca.expiry_date,
        a.status
)
SELECT *
FROM dormant_account 
WHERE card_status like 'ACTIVE' and account_status like 'Dormant';


 -- Loan Analysis 
 -- Several loans marked as ‘Closed’ in the loans table do not have any corresponding records in the loan_payments table (for exampleloan_id = '183729')  
-- Since a closed loan is generally expected to have been fully repaid, the absence of payment records may indicate missing transaction data, 
-- incomplete data migration, or incorrect loan status assignments. This discrepancy should be investigated to ensure the accuracy and integrity of the loan management system.

 WITH loan_analysis AS (
 SELECT
        l.loan_id,
        l.customer_id,
        l.loan_type,
        sum(l.loan_amount) AS Loan_Amount,
        l.status,
        lp.payment_id,
        lp.payment_date
    FROM loans l
   LEFT JOIN loan_payments lp
        ON l.loan_id = lp.loan_id 
GROUP BY l.loan_id,
        l.customer_id,
        l.loan_type,
        l.status,
        lp.payment_id,
        lp.payment_date
	)
    SELECT * FROM loan_analysis;
 
 -- The bank’s loan portfolio is largely healthy, with 63.98% of total loan value remaining active and 26.27% successfully closed. 
 -- However, 6.98% of the portfolio is in default and 2.77% has been written off, meaning 9.75% of total lending is associated with elevated credit risk or realised losses.
 -- Additionally, the average loan amount remains relatively consistent across all loan statuses, suggesting that default risk is not immediately associated with larger loan values alone.
 
 WITH total_loan_amount AS (
    SELECT
        status,
        FORMAT(SUM(loan_amount), -2) AS loan_amount,
        FORMAT(AVG(loan_amount), -2) AS AVG_amount,
        ROUND(
            SUM(loan_amount) * 100.0 /
            (SELECT SUM(loan_amount) FROM loans),
            2
        ) AS percentage
    FROM loans
    GROUP BY status
)

SELECT *
FROM total_loan_amount;


DESCRIBE loans;
-- Cleaning the data 
UPDATE loans
SET loan_type = "Auto Loan"
WHERE loan_type = "Auto Loans";

-- WHich loan_type type has the highest active loans? 
SELECT loan_type, 
		FORMAT(sum(loan_amount),-2) AS 'loan_amount',
        FORMAT(AVG(loan_amount),-2) AS 'Average_amount',
        ROUND(sum(loan_amount) * 100/(Select sum(loan_amount) from loans WHERE status = 'Active'),2) AS Percentage 
FROM
		loans
WHERE status = 'Active'
GROUP BY loan_type;


-- WHich loan_typ has the highest default rate? 
SELECT loan_type, 
		FORMAT(sum(loan_amount),-2) AS 'loan_amount',
        FORMAT(AVG(loan_amount),-2) AS 'Average_amount',
        ROUND(sum(loan_amount) * 100/(Select sum(loan_amount) from loans WHERE status = 'Defaulted'),2) AS Percentage 
FROM
		loans
WHERE status IN ('Defaulted')
GROUP BY loan_type;

-- WHich loan_typ has the highest wriiten off? 
SELECT loan_type, 
		FORMAT(sum(loan_amount),-2) AS 'loan_amount',
        FORMAT(AVG(loan_amount),-2) AS 'Average_amount',
        ROUND(sum(loan_amount) * 100/(Select sum(loan_amount) from loans WHERE status = 'Written OFF'),2) AS Percentage 
FROM
		loans
WHERE status IN ('Written OFF')
GROUP BY loan_type;


-- WHich loan_typ has been closed? 
SELECT loan_type, 
		FORMAT(sum(loan_amount),-2) AS 'loan_amount',
        FORMAT(AVG(loan_amount),-2) AS 'Average_amount',
        ROUND(sum(loan_amount) * 100/(Select sum(loan_amount) from loans WHERE status = 'Closed'),2) AS Percentage 
FROM
		loans
WHERE status IN ('Closed')
GROUP BY loan_type;

-- Metrics(KPI) on loans type 
SELECT
    loan_type,

    COUNT(*) AS total_loans,

    SUM(CASE WHEN status='Active' THEN 1 ELSE 0 END) AS active,

    SUM(CASE WHEN status='Closed' THEN 1 ELSE 0 END) AS closed,

    SUM(CASE WHEN status='Defaulted' THEN 1 ELSE 0 END) AS defaulted,

    SUM(CASE WHEN status='Written Off' THEN 1 ELSE 0 END) AS written_off,

    ROUND(
        SUM(CASE WHEN status='Defaulted' THEN 1 ELSE 0 END)*100.0/
        COUNT(*),
        2
    ) AS default_rate,

    ROUND(
        SUM(CASE WHEN status='Written Off' THEN 1 ELSE 0 END)*100.0/
        COUNT(*),
        2
    ) AS write_off_rate,

    ROUND(
        SUM(CASE WHEN status='Closed' THEN 1 ELSE 0 END)*100.0/
        COUNT(*),
        2
    ) AS closure_rate

FROM loans
GROUP BY loan_type
ORDER BY default_rate DESC;


-- Metrics(KPI) of loans by Branch 
SELECT
    b.branch_name,
    COUNT(l.loan_id) AS total_loans,
    FORMAT(SUM(l.loan_amount), -2) AS total_loan_amount,

    SUM(CASE WHEN l.status = 'Active' THEN 1 ELSE 0 END) AS active_loans,
    SUM(CASE WHEN l.status = 'Closed' THEN 1 ELSE 0 END) AS closed_loans,
    SUM(CASE WHEN l.status = 'Defaulted' THEN 1 ELSE 0 END) AS defaulted_loans,
    SUM(CASE WHEN l.status = 'Written Off' THEN 1 ELSE 0 END) AS written_off_loans,

    ROUND(
        SUM(CASE WHEN l.status = 'Defaulted' THEN 1 ELSE 0 END) * 100.0 /
        COUNT(l.loan_id), 2
    ) AS default_rate,

    ROUND(
        SUM(CASE WHEN l.status = 'Written Off' THEN 1 ELSE 0 END) * 100.0 /
        COUNT(l.loan_id), 2
    ) AS write_off_rate

FROM branches b
JOIN accounts a
    ON b.branch_id = a.branch_id
JOIN customers c
    ON a.customer_id = c.customer_id
JOIN loans l
    ON c.customer_id = l.customer_id

GROUP BY b.branch_name
ORDER BY default_rate DESC;





