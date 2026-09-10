CREATE DATABASE IF NOT EXISTS ecommerce_analytics;
USE ecommerce_analytics;


CREATE TABLE sales_staging (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    product_id VARCHAR(50),
    order_date VARCHAR(50),
    order_time VARCHAR(50),
    delivery_date VARCHAR(50),
    quantity VARCHAR(50),
    unit_price VARCHAR(50),
    order_value VARCHAR(50),
    shipping_cost VARCHAR(50),
    coupon_code VARCHAR(50),
    coupon_discount VARCHAR(50),
    total_amount VARCHAR(50),
    payment_mode VARCHAR(50),
    order_status VARCHAR(50),
    rating VARCHAR(50),
    review_text TEXT,
    city VARCHAR(50),
    state VARCHAR(50),
    customer_age VARCHAR(50),
    customer_age_group VARCHAR(50)
);

*//queries to clean whitespace, correct negative values, handle NULLs, and enforce standard data types*//

SET SQL_SAFE_UPDATES = 0;


-- 1. Trim Whitespace and Standardize Text Case

UPDATE sales_staging
SET 
    order_id = TRIM(order_id),
    customer_id = TRIM(customer_id),
    product_id = TRIM(product_id),
    city = TRIM(CONCAT(UCASE(LEFT(city, 1)), LCASE(SUBSTRING(city, 2)))),
    state = TRIM(state),
    payment_mode = TRIM(payment_mode),
    order_status = TRIM(order_status);
    
-- 2. Handle NULL / Blank Values for Coupon Codes
    
UPDATE sales_staging
SET coupon_code = 'NONE'
WHERE coupon_code IS NULL OR TRIM(coupon_code) = '' OR coupon_code = 'nan';

-- 3. Fix Negative Total Amounts

UPDATE sales_staging
SET total_amount = '0.00'
WHERE CAST(total_amount AS DECIMAL(12,2)) < 0;

SET SQL_SAFE_UPDATES = 1;

CREATE TABLE IF NOT EXISTS sales (
    order_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20),
    product_id VARCHAR(20),
    order_date DATE NOT NULL,
    order_time TIME,
    delivery_date DATE,
    quantity INT,
    unit_price DECIMAL(10,2),
    order_value DECIMAL(12,2),
    shipping_cost DECIMAL(10,2),
    coupon_code VARCHAR(30),
    coupon_discount DECIMAL(10,2),
    total_amount DECIMAL(12,2),
    payment_mode VARCHAR(20),
    order_status VARCHAR(20) NOT NULL,
    rating DECIMAL(2,1),
    review_text TEXT,
    city VARCHAR(50),
    state VARCHAR(50),
    customer_age INT,
    customer_age_group VARCHAR(20)
);

INSERT INTO sales (
    order_id, customer_id, product_id, order_date, order_time,
    delivery_date, quantity, unit_price, order_value, shipping_cost,
    coupon_code, coupon_discount, total_amount, payment_mode,
    order_status, rating, review_text, city, state,
    customer_age, customer_age_group
)
SELECT 
    TRIM(order_id),
    TRIM(customer_id),
    TRIM(product_id),
    STR_TO_DATE(order_date, '%Y-%m-%d'),
    CAST(order_time AS TIME),
    STR_TO_DATE(delivery_date, '%Y-%m-%d'),
    CAST(quantity AS UNSIGNED),
    CAST(unit_price AS DECIMAL(10,2)),
    CAST(order_value AS DECIMAL(12,2)),
    CAST(shipping_cost AS DECIMAL(10,2)),
    CASE WHEN coupon_code IS NULL OR TRIM(coupon_code) = '' OR coupon_code = 'nan' THEN 'NONE' ELSE TRIM(coupon_code) END,
    CAST(coupon_discount AS DECIMAL(10,2)),
    CASE WHEN CAST(total_amount AS DECIMAL(12,2)) < 0 THEN 0.00 ELSE CAST(total_amount AS DECIMAL(12,2)) END,
    TRIM(payment_mode),
    TRIM(order_status),
    CASE WHEN rating IS NULL OR rating = '' OR rating = 'nan' THEN NULL ELSE CAST(rating AS DECIMAL(2,1)) END,
    CASE WHEN review_text IS NULL OR review_text = '' OR review_text = 'nan' THEN 'No Review Provided' ELSE review_text END,
    TRIM(city),
    TRIM(state),
    CAST(customer_age AS UNSIGNED),
    TRIM(customer_age_group)
FROM sales_staging;

DATA VALIDATION

1. Check NULL values

SELECT
    SUM(Order_ID IS NULL) AS missing_order_id,
    SUM(Customer_ID IS NULL) AS missing_customer_id,
    SUM(Product_ID IS NULL) AS missing_product_id,
    SUM(Order_Date IS NULL) AS missing_order_date,
    SUM(Order_Time IS NULL) AS missing_order_time,
    SUM(Delivery_Date IS NULL) AS missing_delivery_date,
    SUM(Quantity IS NULL) AS missing_quantity,
    SUM(Unit_Price IS NULL) AS missing_unit_price,
    SUM(Order_Value IS NULL) AS missing_order_value,
    SUM(Shipping_Cost IS NULL) AS missing_shipping_cost,
    SUM(Coupon_Code IS NULL) AS missing_coupon_code,
    SUM(Coupon_Discount IS NULL) AS missing_coupon_discount,
    SUM(Total_Amount IS NULL) AS missing_total_amount,
    SUM(Payment_Mode IS NULL) AS missing_payment_mode,
    SUM(Order_Status IS NULL) AS missing_order_status,
    SUM(Rating IS NULL) AS missing_rating,
    SUM(Review_Text IS NULL) AS missing_review_text,
    SUM(City IS NULL) AS missing_city,
    SUM(State IS NULL) AS missing_state,
    SUM(Customer_Age IS NULL) AS missing_customer_age,
    SUM(Customer_Age_Group IS NULL) AS missing_customer_age_group
FROM sales;

2. Check duplicate Order IDs
SELECT 
    order_id,
    COUNT(*) AS duplicate_count
FROM sales
GROUP BY order_id
HAVING COUNT(*) > 1;

3. Check invalid quantity
SELECT QUANTITY
FROM sales
WHERE quantity <= 0;

4. Check invalid unit price
SELECT UNIT_PRICE
FROM sales
WHERE unit_price <= 0;

5. Check invalid sales amount

SELECT TOTAL_AMOUNT
FROM sales
WHERE TOTAL_amount <= 0;

6. Invalid Unit_Price
SELECT *
FROM sales
WHERE Unit_Price <= 0;

7.Invalid Order_Value

SELECT ORDER_VALUE,
       Quantity * Unit_Price AS calculated_order_value
FROM sales
WHERE Order_Value <> Quantity * Unit_Price;

8. Invalid Total_Amount

SELECT TOTAL_AMOUNT,
       Order_Value + Shipping_Cost - Coupon_Discount AS calculated_total
FROM sales
WHERE Total_Amount <> Order_Value + Shipping_Cost - Coupon_Discount;

9. Invalid Delivery_Date

SELECT DELIVERY_DATE
FROM sales
WHERE Delivery_Date < Order_Date;

 10. Rating validation
 SELECT RATING
FROM sales
WHERE Rating < 1
   OR Rating > 5;
   
   11. You can also check missing ratings:

SELECT RATING
FROM sales
WHERE Rating IS NULL;

12. Shipping Cost validation

SELECT shipping_cost
FROM sales
WHERE Shipping_Cost <= 0;

TABLE PRODUCTS
USE ecommerce_analytics;

In-Place Production Data Auditing & Cleaning Strategy:

Step 4: Create the products table

CREATE TABLE products (
    Product_ID VARCHAR(50) PRIMARY KEY,
    Product_Name VARCHAR(255) NOT NULL,
    Category VARCHAR(100) NOT NULL,
    Brand VARCHAR(100),
    Original_Price DECIMAL(10,2),
    Discount_Percent DECIMAL(5,2),
    Discount_Amount DECIMAL(10,2),
    Selling_Price DECIMAL(10,2),
    Stock_Quantity INT,
    Weight_kg DECIMAL(10,2),
    Avg_Rating DECIMAL(3,2),
    Total_Reviews INT
);

data cleaning

USE ecommerce_analytics;

-- Disable safe update mode temporarily for bulk updates
SET SQL_SAFE_UPDATES = 0;

-- 1. Trim whitespace and normalize string fields
UPDATE products
SET 
    Product_ID = TRIM(Product_ID),
    Product_Name = TRIM(Product_Name),
    Category = TRIM(Category),
    Brand = TRIM(Brand);

-- 2. Clean missing/null string placeholders ('nan', '', NULL)
UPDATE products
SET Brand = 'Generic'
WHERE Brand IN ('', 'nan', 'null', 'None');

UPDATE products
SET Category = 'Uncategorized'
WHERE Category IS NULL OR Category IN ('', 'nan', 'null');

UPDATE products
SET Product_Name = 'Unknown Product'
WHERE Product_Name IS NULL OR Product_Name IN ('', 'nan', 'null');

-- 3. Clean numeric fields (fix negative prices/stock and handle zero-division risks)
UPDATE products
SET 
    Stock_Quantity  = CASE WHEN Stock_Quantity < 0 THEN 0 ELSE Stock_Quantity END,
    Original_Price = CASE WHEN Original_Price < 0 THEN 0.00 ELSE Original_Price END,
    Selling_Price  = CASE WHEN Selling_Price < 0 THEN 0.00 ELSE Selling_Price END;

-- 4. Fix inconsistent discount calculations
UPDATE products
SET Discount_Amount = CASE 
    WHEN Original_Price > Selling_Price THEN Original_Price - Selling_Price 
    ELSE 0.00 
END;

SELECT 
    COUNT(*) AS total_products,
    SUM(CASE WHEN Brand = 'Generic' THEN 1 ELSE 0 END) AS generic_brands_count,
    SUM(CASE WHEN Stock_Quantity < 0 THEN 1 ELSE 0 END) AS invalid_stock_count,
    SUM(CASE WHEN Selling_Price > Original_Price THEN 1 ELSE 0 END) AS pricing_anomalies
FROM products;

data validation
Check for missing values

SELECT
    SUM(Product_ID IS NULL) AS missing_product_id,
    SUM(Product_Name IS NULL) AS missing_product_name,
    SUM(Category IS NULL) AS missing_category,
    SUM(Brand IS NULL) AS missing_brand,
    SUM(Original_Price IS NULL) AS missing_original_price,
    SUM(Discount_Percent IS NULL) AS missing_discount_percent,
    SUM(Discount_Amount IS NULL) AS missing_discount_amount,
    SUM(Selling_Price IS NULL) AS missing_selling_price,
    SUM(Stock_Quantity IS NULL) AS missing_stock_quantity,
    SUM(Weight_kg IS NULL) AS missing_weight,
    SUM(Avg_Rating IS NULL) AS missing_avg_rating,
    SUM(Total_Reviews IS NULL) AS missing_total_reviews
FROM products;
set sql_safe_updates=0;

checking for duplicates

SELECT Product_ID, COUNT(*)
FROM products
GROUP BY Product_ID
HAVING COUNT(*) > 1;

Invalid prices
SELECT *
FROM 
WHERE Original_Price <= 0
   OR Selling_Price <= 0
   OR Selling_Price > Original_Price;
   
   Invalid discount percentage
   
SELECT *
FROM 
WHERE Discount_Percent < 0
   OR Discount_Percent > 100;
   
   Invalid stock
   
   SELECT *
FROM products
WHERE Stock_Quantity < 0;

Invalid weight

SELECT *
FROM products
WHERE Weight_kg <= 0;

Invalid rating

SELECT *
FROM 
WHERE Avg_Rating < 0
   OR Avg_Rating > 5;
   
   Invalid reviews
   
   SELECT *
FROM products
WHERE Total_Reviews < 0;


1. Create the customers_staging table

CREATE TABLE customers_staging (
    Customer_ID VARCHAR(50) PRIMARY KEY,
    Customer_Name VARCHAR(255),
    Gender VARCHAR(20),
    Age INT,
    Age_Group VARCHAR(50),
    Date_of_Birth DATE,
    Email VARCHAR(255),
    Phone VARCHAR(20),
    City VARCHAR(100),
    State VARCHAR(100),
    Pincode VARCHAR(10),
    Registration_Date DATE,
    Customer_Tier VARCHAR(50),
    Total_Orders INT,
    Total_Spent DECIMAL(12,2)
);

2. Data Cleaning Query

SELECT 
    TRIM(customer_id) AS Customer_ID,

    CASE 
        WHEN customer_name IS NULL 
             OR TRIM(customer_name) = '' 
             OR LOWER(TRIM(customer_name)) = 'nan'
        THEN 'Unknown Customer'
        ELSE TRIM(customer_name)
    END AS Customer_Name,

    CASE 
        WHEN gender IS NULL 
             OR TRIM(gender) = '' 
             OR LOWER(TRIM(gender)) = 'nan'
        THEN 'Unknown'
        ELSE TRIM(gender)
    END AS Gender,

    CASE 
        WHEN age IS NULL 
             OR age = '' 
             OR LOWER(TRIM(age)) = 'nan'
        THEN NULL
        ELSE CAST(age AS UNSIGNED)
    END AS Age,

    CASE 
        WHEN age_group IS NULL 
             OR TRIM(age_group) = '' 
             OR LOWER(TRIM(age_group)) = 'nan'
        THEN 'Unknown'
        ELSE TRIM(age_group)
    END AS Age_Group,

    STR_TO_DATE(
        NULLIF(
            NULLIF(LOWER(TRIM(date_of_birth)), ''),
            'nan'
        ),
        '%Y-%m-%d'
    ) AS Date_of_Birth,

    CASE 
        WHEN email IS NULL 
             OR TRIM(email) = '' 
             OR LOWER(TRIM(email)) = 'nan'
        THEN 'Not Provided'
        ELSE TRIM(email)
    END AS Email,

    CASE 
        WHEN phone IS NULL 
             OR TRIM(phone) = '' 
             OR LOWER(TRIM(phone)) = 'nan'
        THEN 'Not Provided'
        ELSE TRIM(phone)
    END AS Phone,

    TRIM(city) AS City,
    TRIM(state) AS State,
    TRIM(pincode) AS Pincode,

    STR_TO_DATE(
        NULLIF(
            NULLIF(LOWER(TRIM(registration_date)), ''),
            'nan'
        ),
        '%Y-%m-%d'
    ) AS Registration_Date,

    CASE 
        WHEN customer_tier IS NULL 
             OR TRIM(customer_tier) = '' 
             OR LOWER(TRIM(customer_tier)) = 'nan'
        THEN 'Unknown'
        ELSE TRIM(customer_tier)
    END AS Customer_Tier,

    CASE 
        WHEN total_orders IS NULL 
             OR total_orders = '' 
             OR LOWER(TRIM(total_orders)) = 'nan'
        THEN 0
        ELSE CAST(total_orders AS UNSIGNED)
    END AS Total_Orders,

    CASE 
        WHEN total_spent IS NULL 
             OR total_spent = '' 
             OR LOWER(TRIM(total_spent)) = 'nan'
        THEN 0.00
        ELSE CAST(total_spent AS DECIMAL(12,2))
    END AS Total_Spent

FROM customers_staging;

Create the final customers table

CREATE TABLE customers (
    Customer_ID VARCHAR(50) PRIMARY KEY,
    Customer_Name VARCHAR(255),
    Gender VARCHAR(20),
    Age INT,
    Age_Group VARCHAR(50),
    Date_of_Birth DATE,
    Email VARCHAR(255),
    Phone VARCHAR(20),
    City VARCHAR(100),
    State VARCHAR(100),
    Pincode VARCHAR(10),
    Registration_Date DATE,
    Customer_Tier VARCHAR(50),
    Total_Orders INT,
    Total_Spent DECIMAL(12,2)
);

Transfer cleaned data into customers

INSERT INTO customers (
    Customer_ID,
    Customer_Name,
    Gender,
    Age,
    Age_Group,
    Date_of_Birth,
    Email,
    Phone,
    City,
    State,
    Pincode,
    Registration_Date,
    Customer_Tier,
    Total_Orders,
    Total_Spent
)

SELECT
    -- Customer ID
    TRIM(customer_id),

    -- Customer Name
    CASE
        WHEN customer_name IS NULL
             OR TRIM(customer_name) = ''
             OR LOWER(TRIM(customer_name)) = 'nan'
        THEN 'Unknown Customer'
        ELSE TRIM(customer_name)
    END,

    -- Gender
    CASE
        WHEN gender IS NULL
             OR TRIM(gender) = ''
             OR LOWER(TRIM(gender)) = 'nan'
        THEN 'Unknown'
        ELSE TRIM(gender)
    END,

    -- Age
    CASE
        WHEN age IS NULL
             OR TRIM(age) = ''
             OR LOWER(TRIM(age)) = 'nan'
        THEN NULL
        ELSE CAST(age AS UNSIGNED)
    END,

    -- Age Group
    CASE
        WHEN age_group IS NULL
             OR TRIM(age_group) = ''
             OR LOWER(TRIM(age_group)) = 'nan'
        THEN 'Unknown'
        ELSE TRIM(age_group)
    END,

    -- Date of Birth
    STR_TO_DATE(
        NULLIF(
            NULLIF(LOWER(TRIM(date_of_birth)), ''),
            'nan'
        ),
        '%Y-%m-%d'
    ),

    -- Email
    CASE
        WHEN email IS NULL
             OR TRIM(email) = ''
             OR LOWER(TRIM(email)) = 'nan'
        THEN 'Not Provided'
        ELSE TRIM(email)
    END,

    -- Phone
    CASE
        WHEN phone IS NULL
             OR TRIM(phone) = ''
             OR LOWER(TRIM(phone)) = 'nan'
        THEN 'Not Provided'
        ELSE TRIM(phone)
    END,

    -- City
    TRIM(city),

    -- State
    TRIM(state),

    -- Pincode
    TRIM(pincode),

    -- Registration Date
    STR_TO_DATE(
        NULLIF(
            NULLIF(LOWER(TRIM(registration_date)), ''),
            'nan'
        ),
        '%Y-%m-%d'
    ),

    -- Customer Tier
    CASE
        WHEN customer_tier IS NULL
             OR TRIM(customer_tier) = ''
             OR LOWER(TRIM(customer_tier)) = 'nan'
        THEN 'Unknown'
        ELSE TRIM(customer_tier)
    END,

    -- Total Orders
    CASE
        WHEN total_orders IS NULL
             OR TRIM(total_orders) = ''
             OR LOWER(TRIM(total_orders)) = 'nan'
        THEN 0
        ELSE CAST(total_orders AS UNSIGNED)
    END,

    -- Total Spent
    CASE
        WHEN total_spent IS NULL
             OR TRIM(total_spent) = ''
             OR LOWER(TRIM(total_spent)) = 'nan'
        THEN 0.00
        ELSE CAST(total_spent AS DECIMAL(12,2))
    END

FROM customers_staging;

DATA VALIDATION

1. Check NULL values

SELECT
    SUM(Customer_ID IS NULL) AS missing_customer_id,
    SUM(Customer_Name IS NULL) AS missing_customer_name,
    SUM(Gender IS NULL) AS missing_gender,
    SUM(Age IS NULL) AS missing_age,
    SUM(Age_Group IS NULL) AS missing_age_group,
    SUM(Date_of_Birth IS NULL) AS missing_dob,
    SUM(Email IS NULL) AS missing_email,
    SUM(Phone IS NULL) AS missing_phone,
    SUM(City IS NULL) AS missing_city,
    SUM(State IS NULL) AS missing_state,
    SUM(Pincode IS NULL) AS missing_pincode,
    SUM(Registration_Date IS NULL) AS missing_registration_date,
    SUM(Customer_Tier IS NULL) AS missing_customer_tier,
    SUM(Total_Orders IS NULL) AS missing_total_orders,
    SUM(Total_Spent IS NULL) AS missing_total_spent
FROM customers;

2. Check duplicate Customer IDs

SELECT
    Customer_ID,
    COUNT(*) AS duplicate_count
FROM customers
GROUP BY Customer_ID
HAVING COUNT(*) > 1;

3. Check invalid Age

SELECT *
FROM customers
WHERE Age < 0
   OR Age > 120;
   
   4. Check invalid Gender
   
   SELECT *
FROM customers
WHERE Gender NOT IN ('Male', 'Female', 'Other', 'Unknown');


Check invalid Date of Birth

SELECT *
FROM customers
WHERE Date_of_Birth > CURDATE();

7. Check invalid Total Orders

SELECT *
FROM customers
WHERE Total_Orders < 0;

8. Check invalid Total Spent

SELECT *
FROM customers
WHERE Total_Spent < 0;

9. Check Customer Tier
SELECT *
FROM customers
WHERE Customer_Tier NOT IN ('Bronze', 'Silver', 'Gold', 'Platinum', 'Unknown');

QUESTIONS

USE ecommerce_analytics;

1. Which product categories are receiving high discounts and how much revenue is being reduced because of those discounts?
"Which product categories have high discount exposure and weaker revenue performance?"

WITH CategoryPerformance AS (
    SELECT 
        p.Category,
        COUNT(s.order_id) AS total_orders,
        ROUND(AVG(p.Discount_Percent), 2) AS avg_discount_pct,
        
        -- 1. Gross List Revenue (Potential revenue before any discount)
        ROUND(SUM(p.Original_Price * s.quantity), 2) AS gross_list_revenue,
        
        -- 2. Total Discount Given (Monetary value lost to discounts)
        ROUND(SUM(p.Discount_Amount * s.quantity), 2) AS total_discount_given,
        
        -- 3. Actual Revenue Realized (Actual cash collected after discount)
        ROUND(SUM(s.order_value), 2) AS actual_revenue,
        
        -- 4. Discount Impact % (Percentage of list revenue given away)
        ROUND(
            (
                SUM(p.Discount_Amount * s.quantity) 
                / NULLIF(SUM(p.Original_Price * s.quantity), 0)
            ) * 100, 
            2
        ) AS discount_impact_pct

    FROM sales s
    JOIN products p 
        ON s.product_id = p.Product_ID
        
    GROUP BY p.Category
)

SELECT 
    Category,
    total_orders,
    avg_discount_pct,
    gross_list_revenue,
    total_discount_given,
    actual_revenue,
    discount_impact_pct
FROM CategoryPerformance
WHERE discount_impact_pct > 15
ORDER BY total_discount_given DESC;
Business Recommendation:Executive Business Recommendation: Optimizing High Discount Exposure Categories
1. Implement Category-Specific Discount Caps

Target Categories with >15% Exposure: Instantly cap promotional discounting to a maximum threshold (e.g., 5% to 8%) on categories 
flagged with high discount_impact_pct.

Prevent Unnecessary Margin Erosion: High discount exposure without proportional revenue lift indicates that customers are taking 
advantage of promotions on products they likely would have purchased anyway.

2. Transition from Flat Discounts to Spend-Threshold Incentives

Tiered Minimum Orders: Replace flat product-level discounts (e.g., "20% Off") with basket-building incentives such as "Spend ₹2,000, 
Get ₹300 Off".
Protect Top-Line Revenue: This forces higher average order values (AOV) to unlock savings, ensuring the discount given 
is economically balanced by larger total cart volume.


text{Price Elasticity} = \frac{\% \text{ Change in Quantity Demanded}}{\% \text{ Change in Price}}

3. Shift Promotional Budget to High-Performing Categories

Reallocate Discount Dollars: Redirect money saved from limiting discounts on weak-performing categories toward targeted, 
high-margin categories with higher customer acquisition potential.

A/B Test Promotional Sensitivity: Test lower discount percentages (e.g., 10% vs. 20%) on high-exposure categories to determine
 true price elasticity before running blanket promotions.

2. Repeat Purchase Cohort Analysis (Customer Retention)

Problem: Are new customers returning to make a second purchase within 30, 60, or 90 days?

Insight Goal: Quantify customer drop-off after their initial order.

WITH customer_first_order AS (
    SELECT 
        customer_id,
        MIN(order_date) AS first_order_date
    FROM sales
    GROUP BY customer_id
),
order_gaps AS (
    SELECT 
        s.customer_id,
        s.order_date,
        f.first_order_date,
        DATEDIFF(s.order_date, f.first_order_date) AS days_since_first_order
    FROM sales s
    JOIN customer_first_order f ON s.customer_id = f.customer_id
)
SELECT 
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT CASE WHEN days_since_first_order > 0 AND days_since_first_order <= 30 THEN customer_id END) AS retained_30_days,
    COUNT(DISTINCT CASE WHEN days_since_first_order > 30 AND days_since_first_order <= 60 THEN customer_id END) AS retained_60_days,
    COUNT(DISTINCT CASE WHEN days_since_first_order > 60 AND days_since_first_order <= 90 THEN customer_id END) AS retained_90_days
FROM order_gaps;

Business Recommendation: Implement automated post-purchase email flows offering personalized cross-sell recommendations within 
14–21 days of first purchase to increase early retention.

3. Churn Risk Identification via RFM Scores

Problem: Determining which valuable, high-spending customers show signs of stopping purchases.

Insight Goal: Filter for "At Risk" customers who previously generated significant revenue but haven't bought recently.

USE ecommerce_analytics;

WITH customer_metrics AS (
    SELECT 
        customer_id,
        DATEDIFF((SELECT MAX(order_date) FROM sales), MAX(order_date)) AS recency_days,
        COUNT(DISTINCT order_id) AS frequency_count,
        SUM(total_amount) AS monetary_value
    FROM sales
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT 
        customer_id,
        recency_days,
        frequency_count,
        monetary_value,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency_count ASC)  AS f_score,
        NTILE(4) OVER (ORDER BY monetary_value ASC)   AS m_score
    FROM customer_metrics
)
SELECT 
    c.customer_id,
    c.customer_name,
    c.email,
    r.recency_days,
    r.frequency_count,
    ROUND(r.monetary_value, 2) AS lifetime_value
FROM rfm_scores r
JOIN customers c ON r.customer_id = c.customer_id
WHERE r.r_score <= 2 AND r.f_score >= 3 AND r.m_score >= 3
ORDER BY r.monetary_value DESC;

Business Recommendation: Send targeted win-back promotions (e.g., exclusive loyalty point bonuses or free shipping coupons) 
directly to these specific high-value customer email addresses.

4. Delivery Lag & Order Cancellation Correlation

Problem: High cancellation rates hurt revenue and logistics operations.

Insight Goal: Analyze whether longer delivery timeframes directly increase order cancellations.


SELECT 
    order_status,
    COUNT(order_id) AS total_orders,
    ROUND(AVG(DATEDIFF(delivery_date, order_date)), 1) AS avg_delivery_days,
    ROUND(AVG(shipping_cost), 2) AS avg_shipping_cost,
    ROUND(SUM(total_amount), 2) AS gross_impact
FROM sales
WHERE delivery_date IS NOT NULL
GROUP BY order_status
ORDER BY total_orders DESC;

Business Recommendation: Negotiate stricter SLAs with logistics partners for regional routes exhibiting higher delivery delays, 
as slow fulfillment directly correlates with order cancellations.

USE ecommerce_analytics;

USE ecommerce_analytics;

CREATE OR REPLACE VIEW vw_executive_kpi_summary AS
WITH sales_kpis AS (
    SELECT 
        COUNT(DISTINCT s.order_id) AS total_orders,
        ROUND(SUM(s.total_amount), 2) AS total_gross_revenue,
        ROUND(SUM(p.Original_Price * s.quantity), 2) AS total_cost_of_goods,
        ROUND(SUM(s.total_amount - (p.Original_Price * s.quantity)), 2) AS total_net_profit,
        ROUND((SUM(s.total_amount - (p.Original_Price * s.quantity)) / SUM(s.total_amount)) * 100, 2) AS overall_profit_margin_pct,
        ROUND(AVG(DATEDIFF(s.delivery_date, s.order_date)), 1) AS avg_delivery_days,
        ROUND((COUNT(CASE WHEN s.order_status = 'Cancelled' THEN 1 END) / COUNT(*)) * 100, 2) AS cancellation_rate_pct
    FROM sales s
    JOIN products p ON s.product_id = p.Product_ID
),
customer_rfm AS (
    SELECT 
        customer_id,
        DATEDIFF((SELECT MAX(order_date) FROM sales), MAX(order_date)) AS recency_days,
        COUNT(DISTINCT order_id) AS frequency_count,
        SUM(total_amount) AS monetary_value
    FROM sales
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT 
        customer_id,
        monetary_value,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency_count ASC) AS f_score,
        NTILE(4) OVER (ORDER BY monetary_value ASC) AS m_score
    FROM customer_rfm
),
churn_kpis AS (
    SELECT 
        COUNT(DISTINCT customer_id) AS total_unique_customers,
        COUNT(DISTINCT CASE WHEN r_score <= 2 AND f_score >= 2 THEN customer_id END) AS at_risk_customers,
        ROUND(SUM(CASE WHEN r_score <= 2 AND f_score >= 2 THEN monetary_value ELSE 0 END), 2) AS revenue_at_risk
    FROM rfm_scores
)
SELECT 
    sk.total_orders,
    sk.total_gross_revenue,
    sk.total_net_profit,
    sk.overall_profit_margin_pct,
    ck.total_unique_customers,
    ck.at_risk_customers,
    ROUND((ck.at_risk_customers / ck.total_unique_customers) * 100, 2) AS customer_churn_risk_pct,
    ck.revenue_at_risk,
    sk.avg_delivery_days,
    sk.cancellation_rate_pct
FROM sales_kpis sk
CROSS JOIN churn_kpis ck;

SELECT * FROM vw_executive_kpi_summary;

Executive Insights & Portfolio Storyline

When presenting this project, frame your findings around three core strategic pillars:

    Profitability Health: Focus on overall_profit_margin_pct. Use your category breakdown query to 
    explain how eliminating high discounts on low-margin products protects net profit.

    Customer Retention: Present at_risk_customers and revenue_at_risk. 
    Highlight how win-back email campaigns targeted at high-LTV customers can prevent revenue loss.

    Fulfillment Operations: Connect avg_delivery_days to cancellation_rate_pct. 
    Show how optimizing regional shipping logistics directly reduces canceled orders and restores lost top-line revenue.
    
    Core Insight (What the Result Table Reveals)

Your RFM analysis output pinpoints high-value individual customers who generated massive lifetime revenue (up to $913k+) but are currently at severe risk of churning.
Why This Is Critical for the Business

    Disproportionate Revenue Impact: A small tier of top spenders (like Zara Ansari, Rohan Yadav, and Swati Mehta) accounts for a massive slice of your cumulative sales value. Losing even 5–10 of these top-tier buyers severely harms your top-line revenue.

    Cost Efficiency: Acquiring a new customer costs 5x to 7x more than retaining an existing one. Preventing churn among these specific high-LTV users protects revenue far more efficiently than running top-of-funnel acquisition ads.

Actionable Business Solutions & Strategy

Present these concrete recommendations alongside this query result:

    VIP Loyalty Retention Campaigns: Trigger targeted, high-touch re-engagement emails directly to 
    these email addresses offering exclusive VIP perks (e.g., $100 store credit, early access to new catalog drops, or personal account management).

    Automated Churn Alerts (CRM Trigger): Set up a database trigger or scheduled job that automatically flags a customer as "At Risk" 
    when their inactivity exceeds 45 days, automatically firing a win-back campaign before they hit the RFM churn threshold.

    Customer Feedback Surveys: Send a quick 2-question "We Miss You" feedback survey with an incentive to discover if their inactivity is due to bad product experience,
    delivery delays, or competitor pricing.