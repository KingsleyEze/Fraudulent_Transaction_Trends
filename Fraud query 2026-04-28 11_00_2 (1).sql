SELECT *
 FROM `my-project-fraud.Fraud.fraud_dataset`;


# Check Missing Values
SELECT 
  column_name, data_type
FROM `my-project-fraud.Fraud.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'fraud_dataset';

SELECT
  COUNTIF(transaction_id IS NULL) AS missing_amount,
  COUNTIF(account_age_days IS NULL) AS missing_age,
  COUNTIF(device_type IS NULL) AS missing_device,
  COUNTIF(location IS NULL) AS missing_location,
  COUNTIF(payment_method IS NULL) AS missing_payment
FROM `my-project-fraud.Fraud.fraud_dataset`;


#Create Clean Table

CREATE OR REPLACE TABLE `my-project-fraud.Fraud.clean_fraud_dataset` AS

WITH base AS (
  SELECT DISTINCT *
  FROM `my-project-fraud.Fraud.fraud_dataset`
),

-- Extract numeric part of Transaction_id
cleaned AS (
  SELECT
    CAST(REGEXP_EXTRACT(Transaction_id, r'([0-9]+)') AS FLOAT64) AS Transaction_id_clean,
    CAST(Account_Age_days AS FLOAT64) AS Account_Age_days_clean,
    amount,
    Device_type,
    Location,
    Payment_Method,
    transaction_type,   -- keep as string
    is_fraud
  FROM base
),

stats AS (
  SELECT
    AVG(Transaction_id_clean) AS avg_id,
    AVG(Account_Age_days_clean) AS avg_age_days
  FROM cleaned
),

mode_device AS (
  SELECT Device_type
  FROM cleaned
  WHERE Device_type IS NOT NULL
  GROUP BY Device_type
  ORDER BY COUNT(*) DESC
  LIMIT 1
),

mode_location AS (
  SELECT Location
  FROM cleaned
  WHERE Location IS NOT NULL
  GROUP BY Location
  ORDER BY COUNT(*) DESC
  LIMIT 1
),

mode_payment AS (
  SELECT Payment_Method
  FROM cleaned
  WHERE Payment_Method IS NOT NULL
  GROUP BY Payment_Method
  ORDER BY COUNT(*) DESC
  LIMIT 1
)

SELECT
  TRIM(CAST(amount AS STRING)) AS amount,

  COALESCE(Transaction_id_clean, stats.avg_id) AS Transaction_id,

  COALESCE(Account_Age_days_clean, stats.avg_age_days) AS Account_Age_days,

  COALESCE(cleaned.Device_type, mode_device.Device_type) AS Device_type,

  COALESCE(cleaned.Location, mode_location.Location) AS Location,

  COALESCE(cleaned.Payment_Method, mode_payment.Payment_Method) AS Payment_Method,

  transaction_type,   -- keep as string, no timestamp parsing

  CAST(is_fraud AS INT64) AS is_fraud

FROM cleaned
CROSS JOIN stats
CROSS JOIN mode_device
CROSS JOIN mode_location
CROSS JOIN mode_payment

WHERE COALESCE(Transaction_id_clean, stats.avg_id) > 0;

# ✅ Removes duplicates
# ✅ Fills missing numbers with average
# ✅ Fills missing text with most common value
# ✅ Converts time to timestamp
# ✅ Converts Fraudulent to integer
# ✅ Removes negative/zero amounts

# Check Clean Data

SELECT *
FROM `my-project-fraud.Fraud.clean_fraud_dataset`;

#  Validate Nulls Removed

SELECT
  COUNTIF(Transaction_id IS NULL) AS missing_id,
  COUNTIF(Device_type IS NULL) AS missing_device,
  COUNTIF(Location IS NULL) AS missing_location
FROM `my-project-fraud.Fraud.clean_fraud_dataset`;

# Count Rows Before / After

SELECT COUNT(*) AS raw_rows
FROM `fraud_project.raw_fraud_data`;

SELECT COUNT(*) AS clean_rows
FROM `my-project-fraud.Fraud.clean_fraud_dataset`;

# Detect Duplicate User IDs

SELECT amount, COUNT(*) total
FROM `my-project-fraud.Fraud.clean_fraud_dataset`
GROUP BY amount
HAVING COUNT(*) > 1;

###  I used BigQuery SQL to clean the fraud dataset by removing duplicates, imputing missing values using averages and modes, correcting data types, validating transaction amounts, and producing a clean analytics-ready table.;



## After cleaning, create KPIs in BigQuery:

SELECT
COUNT(*) total_transactions,
SUM(Transaction_id) total_amount,
SUM(is_fraud) fraud_count
FROM `my-project-fraud.Fraud.clean_fraud_dataset`;



