-- ============================================================
-- CÉLIO HERBLAY - CUSTOMER BEHAVIOR & REVENUE LOSS ANALYSIS
-- Author  : Chaimaa MOURID
-- Study case : 2025 | Realisation : 2026
-- Goal    : Identify and quantify lost revenue from
--           expired coupons and missed birthday discounts
-- ============================================================


-- ============================================================
-- DATABASE OVERVIEW
-- How many customers, transactions, coupons?
-- Results: 100 customers | 593 transactions | 267 coupons
-- ============================================================

SELECT COUNT(*) AS total_customers FROM customers;
SELECT COUNT(*) AS total_transactions FROM transactions;
SELECT COUNT(*) AS total_coupons FROM coupons;


-- ============================================================
-- QUERY 1 - REVENUE OVERVIEW
-- Total revenue generated in 2025 before and after discounts
-- Results:
--   total_visits                  : 593
--   total_revenue_before_discounts: 47041.81
--   total_coupons_deducted        : 555.00
--   total_birthday_deducted       : 274.72
--   total_revenue_after_discounts : 46212.09
--   avg_basket                    : 77.93
-- ============================================================

SELECT
    COUNT(*) AS total_visits,
    ROUND(SUM(subtotal), 2) AS total_revenue_before_discounts,
    ROUND(SUM(coupon_deducted), 2) AS total_coupons_deducted,
    ROUND(SUM(birthday_discount_deducted), 2) AS total_birthday_deducted,
    ROUND(SUM(total_amount), 2) AS total_revenue_after_discounts,
    ROUND(AVG(total_amount), 2) AS avg_basket
FROM transactions;


-- ============================================================
-- QUERY 2 - EXPIRED COUPONS
-- How many coupons expired and what is the direct value lost?
-- Results:
--   total_expired_coupons: 82
--   direct_value_lost    : 410.00
-- ============================================================

SELECT
    COUNT(*) AS total_expired_coupons,
    ROUND(SUM(coupon_value), 2) AS direct_value_lost
FROM coupons
WHERE status = 'expired';


-- ============================================================
-- QUERY 3 - AVERAGE BASKET WHEN COUPON USED
-- What does a customer spend on average when using a coupon?
-- Result: avg_basket_when_coupon_used: 70.31
-- ============================================================

SELECT
    ROUND(AVG(total_amount), 2) AS avg_basket_when_coupon_used
FROM transactions
WHERE coupon_used = 1;


-- ============================================================
-- QUERY 4 - ESTIMATED REAL LOST REVENUE FROM EXPIRED COUPONS
-- Logic: each expired coupon = one lost visit = lost full basket
-- Results:
--   expired_coupons    : 82
--   estimated_real_loss: 5765.41
-- ============================================================

SELECT
    COUNT(*) AS expired_coupons,
    ROUND(COUNT(*) * (SELECT AVG(total_amount) FROM transactions WHERE coupon_used = 1), 2) AS estimated_real_loss
FROM coupons
WHERE status = 'expired';


-- ============================================================
-- QUERY 5 - BIRTHDAY DISCOUNTS MISSED
-- How many birthday discounts were not applied by sellers?
-- The discount is hidden on the cashier screen - sellers miss it
-- Results:
--   total_birthday_visits  : 131
--   discounts_applied      : 27
--   discounts_missed       : 104
--   estimated_birthday_loss: 960.86
-- ============================================================

SELECT
    SUM(birthday_eligible) AS total_birthday_visits,
    SUM(birthday_discount_used) AS discounts_applied,
    SUM(CASE WHEN birthday_eligible = 1 AND birthday_discount_used = 0 THEN 1 ELSE 0 END) AS discounts_missed,
    ROUND(SUM(CASE WHEN birthday_eligible = 1 AND birthday_discount_used = 0 THEN most_expensive_item * 0.20 ELSE 0 END), 2) AS estimated_birthday_loss
FROM transactions;


-- ============================================================
-- QUERY 6 - COUPON STATUS BREAKDOWN
-- ============================================================

SELECT
    status,
    COUNT(*) AS total,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM coupons), 1) AS percentage
FROM coupons
GROUP BY status
ORDER BY total DESC;


-- ============================================================
-- QUERY 7 - CUSTOMERS WITH ACTIVE COUPONS (Priority contact list)
-- ============================================================

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.phone,
    c.city,
    cp.coupon_value,
    cp.generated_date,
    cp.expiry_date,
    DATEDIFF(cp.expiry_date, '2025-12-31') AS days_until_expiry
FROM customers c
JOIN coupons cp ON c.customer_id = cp.customer_id
WHERE cp.status = 'active'
ORDER BY days_until_expiry ASC;


-- ============================================================
-- QUERY 8 - CUSTOMER SEGMENTATION
-- Active / At Risk / Sleeping based on last visit date
-- ============================================================

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.city,
    COUNT(t.transaction_id) AS total_visits,
    ROUND(SUM(t.total_amount), 2) AS total_spent,
    ROUND(AVG(t.total_amount), 2) AS avg_basket,
    MAX(t.transaction_date) AS last_visit,
    DATEDIFF('2025-12-31', MAX(t.transaction_date)) AS days_since_last_visit,
    CASE
        WHEN DATEDIFF('2025-12-31', MAX(t.transaction_date)) <= 90  THEN 'Active'
        WHEN DATEDIFF('2025-12-31', MAX(t.transaction_date)) <= 180 THEN 'At Risk'
        ELSE 'Sleeping'
    END AS customer_status
FROM customers c
JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.city
ORDER BY days_since_last_visit DESC;


-- ============================================================
-- SUMMARY - ALL KEY NUMBERS IN ONE QUERY
-- ============================================================

SELECT
    (SELECT COUNT(*) FROM customers)                                                AS total_customers,
    (SELECT COUNT(*) FROM transactions)                                             AS total_transactions,
    (SELECT ROUND(SUM(total_amount), 2) FROM transactions)                          AS total_revenue,
    (SELECT ROUND(AVG(total_amount), 2) FROM transactions)                          AS avg_basket,
    (SELECT COUNT(*) FROM coupons WHERE status = 'expired')                         AS expired_coupons,
    (SELECT ROUND(SUM(coupon_value), 2) FROM coupons WHERE status = 'expired')      AS direct_coupon_loss,
    (SELECT COUNT(*) FROM coupons WHERE status = 'active')                          AS active_coupons,
    (SELECT SUM(birthday_discount_used) FROM transactions)                          AS birthday_discounts_applied,
    ROUND(
        (SELECT COUNT(*) FROM coupons WHERE status = 'expired') *
        (SELECT AVG(total_amount) FROM transactions WHERE coupon_used = 1)
    , 2)                                                                            AS estimated_coupon_loss,
    (SELECT ROUND(SUM(CASE WHEN birthday_eligible = 1 AND birthday_discount_used = 0
        THEN most_expensive_item * 0.20 ELSE 0 END), 2) FROM transactions)         AS estimated_birthday_loss;
