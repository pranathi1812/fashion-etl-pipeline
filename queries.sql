-- ── QUERY 1: Overview ─────────────────────────
-- How many records do we have and what's the total revenue?

SELECT 
    COUNT(*)                        AS total_records,
    ROUND(SUM(purchase_amount), 2)  AS total_revenue,
    ROUND(AVG(purchase_amount), 2)  AS avg_purchase,
    ROUND(AVG(review_rating), 1)    AS avg_rating
FROM fashion_sales;

-- ── QUERY 2: Top Selling Items ────────────────
-- Which items are purchased the most?

SELECT 
    item_purchased,
    COUNT(*)                        AS times_purchased,
    ROUND(SUM(purchase_amount), 2)  AS total_revenue,
    ROUND(AVG(review_rating), 1)    AS avg_rating
FROM fashion_sales
GROUP BY item_purchased
ORDER BY times_purchased DESC
LIMIT 10;

-- ── QUERY 3: Payment Method Analysis ──────────
-- Which payment method do customers use the most?

SELECT
    payment_method,
    COUNT(*)                        AS total_transactions,
    ROUND(SUM(purchase_amount), 2)  AS total_revenue,
    ROUND(AVG(purchase_amount), 2)  AS avg_transaction,
    ROUND(AVG(review_rating), 1)    AS avg_rating
FROM fashion_sales
GROUP BY payment_method
ORDER BY total_transactions DESC;

-- ── QUERY 4: Monthly Sales Trend ──────────────
-- How do sales change month by month?

SELECT
    date_purchase,
    COUNT(*)                        AS total_orders,
    ROUND(SUM(purchase_amount), 2)  AS monthly_revenue,
    ROUND(AVG(purchase_amount), 2)  AS avg_order_value
FROM fashion_sales
GROUP BY date_purchase
ORDER BY date_purchase ASC;

-- ── QUERY 5: Customer Spending Segments ───────
-- Are customers low, medium or high spenders?

SELECT
    CASE
        WHEN purchase_amount < 50          THEN 'Budget (under $50)'
        WHEN purchase_amount BETWEEN 50 AND 100  THEN 'Mid Range ($50-$100)'
        WHEN purchase_amount BETWEEN 100 AND 200 THEN 'Premium ($100-$200)'
        ELSE                                    'Luxury (over $200)'
    END                             AS spending_segment,
    COUNT(*)                        AS total_customers,
    ROUND(SUM(purchase_amount), 2)  AS total_revenue,
    ROUND(AVG(purchase_amount), 2)  AS avg_spend
FROM fashion_sales
GROUP BY spending_segment
ORDER BY avg_spend DESC;

-- ── QUERY 6: Top Rated Items ──────────────────
-- Which items have the highest customer ratings?

SELECT
    item_purchased,
    ROUND(AVG(review_rating), 2)    AS avg_rating,
    COUNT(*)                        AS total_reviews,
    ROUND(SUM(purchase_amount), 2)  AS total_revenue
FROM fashion_sales
WHERE review_rating IS NOT NULL
GROUP BY item_purchased
HAVING COUNT(*) >= 10
ORDER BY avg_rating DESC
LIMIT 10;

-- ── QUERY 7: Payment Method by Segment ────────
-- Which payment method does each spending segment prefer?

SELECT
    CASE
        WHEN purchase_amount < 50               THEN 'Budget'
        WHEN purchase_amount BETWEEN 50 AND 100  THEN 'Mid Range'
        WHEN purchase_amount BETWEEN 100 AND 200 THEN 'Premium'
        ELSE                                         'Luxury'
    END                             AS spending_segment,
    payment_method,
    COUNT(*)                        AS total_transactions,
    ROUND(AVG(purchase_amount), 2)  AS avg_spend
FROM fashion_sales
GROUP BY spending_segment, payment_method
ORDER BY spending_segment, total_transactions DESC;

-- ── QUERY 8: Ranking Items by Revenue ─────────
-- Rank every item by revenue using window functions

SELECT
    item_purchased,
    ROUND(SUM(purchase_amount), 2)  AS total_revenue,
    COUNT(*)                        AS total_orders,
    RANK() OVER (ORDER BY SUM(purchase_amount) DESC) AS revenue_rank
FROM fashion_sales
GROUP BY item_purchased
ORDER BY revenue_rank;

-- ── QUERY 9: Month over Month Growth ──────────
-- Did revenue grow or shrink compared to last month?

WITH monthly_revenue AS (
    SELECT
        date_purchase,
        ROUND(SUM(purchase_amount), 2)  AS revenue
    FROM fashion_sales
    GROUP BY date_purchase
    ORDER BY date_purchase ASC
)
SELECT
    date_purchase,
    revenue,
    LAG(revenue) OVER (ORDER BY date_purchase)      AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY date_purchase))
        / LAG(revenue) OVER (ORDER BY date_purchase) * 100
    , 1)                                            AS growth_pct
FROM monthly_revenue
ORDER BY date_purchase;

-- ── QUERY 10: Full Customer Summary ───────────
-- Complete picture of every customer's behavior

WITH customer_stats AS (
    SELECT
        customer_id,
        COUNT(*)                        AS total_purchases,
        ROUND(SUM(purchase_amount), 2)  AS total_spent,
        ROUND(AVG(purchase_amount), 2)  AS avg_spend,
        ROUND(AVG(review_rating), 1)    AS avg_rating,
        MAX(purchase_amount)            AS highest_purchase,
        MIN(purchase_amount)            AS lowest_purchase
    FROM fashion_sales
    GROUP BY customer_id
),
customer_ranked AS (
    SELECT
        customer_id,
        total_purchases,
        total_spent,
        avg_spend,
        avg_rating,
        highest_purchase,
        lowest_purchase,
        RANK() OVER (ORDER BY total_spent DESC)      AS spending_rank,
        CASE
            WHEN total_spent > 500  THEN 'VIP'
            WHEN total_spent > 200  THEN 'Regular'
            ELSE                        'Occasional'
        END                                          AS customer_tier
    FROM customer_stats
)
SELECT *
FROM customer_ranked
ORDER BY spending_rank
LIMIT 20;