-- ============================================================
--  ASSIGNMENT 11 — Window Functions
--  Database : BikeStores
--  Topics   : OVER(), PARTITION BY, ROW_NUMBER, RANK,
--             DENSE_RANK, LAG, LEAD, running totals,
--             window functions with CTEs
-- ============================================================


-- ============================================================
--  Question 1 — Aggregate as a Window Function
--  a) Return product_name, list_price and the overall average
--     list_price of all products as a column named overall_avg
--     (use AVG with an empty OVER()).
--  b) Extend the query to add price_difference, i.e. each
--     product's list_price minus overall_avg.
--  c) Explain in a comment how this differs from using
--     GROUP BY with AVG.
-- ============================================================
-- Part a:
SELECT 
    product_name, 
    list_price, 
    AVG(list_price) OVER() AS overall_avg
FROM production.products;

-- Part b:
SELECT 
    product_name, 
    list_price, 
    AVG(list_price) OVER() AS overall_avg,
    list_price - AVG(list_price) OVER() AS price_difference
FROM production.products;

-- Part c:
/*
Using AVG() OVER() calculates the overall average across all rows without collapsing them, so every individual product remains visible alongside the aggregate value[span_0](start_span)[span_0](end_span).

In contrast, using GROUP BY with AVG() collapses rows into summary groups (or a single row), which prevents displaying individual ungrouped columns like product_name and list_price alongside the average[span_1](start_span)[span_1](end_span).
*/




-- ============================================================
--  Question 2 — PARTITION BY
--  a) Return product_name, category_id, list_price and the
--     average list_price of that product's category as
--     category_avg_price (rounded to 2 decimals).
--  b) Return product_name, brand_id, list_price and the
--     MAX list_price within the brand as brand_max_price.
--  c) Return order_id, item_id, product_id, quantity and the
--     total quantity of the whole order as order_total_qty
--     (from sales.order_items).
-- ============================================================

-- part a:
SELECT
    product_name,
    category_id,
    list_price,
    ROUND(AVG(list_price) OVER (PARTITION BY category_id), 2) AS category_avg_price
FROM production.products;

--- part b:
SELECT
    product_name,
    brand_id,
    list_price,
    MAX(list_price) OVER (PARTITION BY brand_id) AS brand_max_price
FROM production.products;

--- part c:
SELECT
    order_id,
    item_id,
    product_id,
    quantity,
    SUM(quantity) OVER (PARTITION BY order_id) AS order_total_qty
FROM sales.order_items;

-- ============================================================
--  Question 3 — ROW_NUMBER
--  a) Assign a sequential number to every customer ordered by
--     last_name, then first_name. Show row_num, first_name,
--     last_name and city.
--  b) Restart the numbering for each city (PARTITION BY city),
--     ordered by first_name.
--  c) For each category_id, number the products from the most
--     expensive to the cheapest. Show category_id,
--     product_name, list_price and row_num.
-- ============================================================

--part a:
SELECT
    ROW_NUMBER() OVER (ORDER BY last_name, first_name) AS row_num,
    first_name,
    last_name,
    city
FROM sales.customers;

--part b:
SELECT
    ROW_NUMBER() OVER (PARTITION BY city ORDER BY first_name) AS row_num,
    first_name,
    last_name,
    city
FROM sales.customers;

--part c:
SELECT
    category_id,
    product_name,
    list_price,
    ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY list_price DESC) AS row_num
FROM production.products;

-- ============================================================
--  Question 4 — Top N per Group
--  a) Return the 3 most expensive products of EACH category.
--     Show category_id, product_name, list_price.
--     Hint: use ROW_NUMBER inside a CTE or derived table, then
--     filter on it in the outer query (window functions cannot
--     be used directly in WHERE).
--  b) Return the most recent order of EACH customer.
--     Show customer_id, order_id and order_date.
-- ============================================================

--part a:
WITH RankedProducts AS (
    SELECT
        category_id,
        product_name,
        list_price,
        ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY list_price DESC) AS rn
    FROM production.products
)
SELECT
    category_id,
    product_name,
    list_price
FROM RankedProducts
WHERE rn <= 3;

--part b:
WITH RecentOrders AS (
    SELECT
        customer_id,
        order_id,
        order_date,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC, order_id DESC) AS rn
    FROM sales.orders
)
SELECT
    customer_id,
    order_id,
    order_date
FROM RecentOrders
WHERE rn = 1;
-- ============================================================
--  Question 5 — RANK vs DENSE_RANK
--  a) Rank all products by list_price (highest first) using
--     both RANK() and DENSE_RANK() in the same query. Show
--     product_name, list_price, price_rank and dense_price_rank.
--  b) Do the same ranking, but restart it inside each brand_id
--     (PARTITION BY brand_id).
--  c) Explain in a comment what happens to the numbers after
--     a tie with RANK and with DENSE_RANK. Point to a row from
--     your own result as an example.
-- ============================================================

--part a:
SELECT
    product_name,
    list_price,
    RANK() OVER (ORDER BY list_price DESC) AS price_rank,
    DENSE_RANK() OVER (ORDER BY list_price DESC) AS dense_price_rank
FROM production.products;

--part b:
SELECT
    brand_id,
    product_name,
    list_price,
    RANK() OVER (PARTITION BY brand_id ORDER BY list_price DESC) AS price_rank,
    DENSE_RANK() OVER (PARTITION BY brand_id ORDER BY list_price DESC) AS dense_price_rank
FROM production.products;

-- Part c (answer as a comment):
/*
When two or more products share the same list_price (a tie), both RANK() and DENSE_RANK() assign them the same rank number. 
However, after the tie, RANK() skips the subsequent rank numbers equal to the number of tied rows, whereas DENSE_RANK() continues sequentially without leaving any gaps.

Example from the BikeStores result (Part a):
Multiple products (such as 'Trek Domane SLR 9 Disc - 2018' and 'Trek Emonda SLR 8 - 2018') tie at the highest price of 7499.99 and both receive rank 1 in both columns. 
For the very next lower-priced product at 6499.99 ('Trek Domane SLR 8 Disc - 2018'), RANK() skips 2 and assigns price_rank = 3, while DENSE_RANK() assigns dense_price
*/
-- ============================================================
--  Question 6 — Ranking with Aggregates
--  Calculate the total revenue of each customer
--  (SUM(quantity * list_price * (1 - discount))) and rank the
--  customers from the highest spender to the lowest using
--  DENSE_RANK. Show customer_id, total_spent and spend_rank.
--  Hint: aggregate in a CTE first, then apply the window
--  function in the next step.
-- ============================================================

-- Write your query below:

WITH CustomerSpend AS (
    SELECT
        o.customer_id,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spent
    FROM sales.orders o
    JOIN sales.order_items oi
        ON o.order_id = oi.order_id
    GROUP BY o.customer_id
)
SELECT
    customer_id,
    total_spent,
    DENSE_RANK() OVER (ORDER BY total_spent DESC) AS spend_rank
FROM CustomerSpend;



-- ============================================================
--  Question 7 — LAG
--  For the brand 'Electra' in the year 2018, calculate the net
--  sales per month (SUM(quantity * list_price * (1 - discount))).
--  Then use LAG to show:
--    month, net_sales, previous_month_sales and the percentage
--    change versus the previous month.
--  Hint: a CTE for the monthly sales, a second step for LAG.
-- ============================================================

-- Write your query below:

WITH MonthlySales AS (
    SELECT
        MONTH(o.order_date) AS month,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS net_sales
    FROM sales.orders o
    JOIN sales.order_items oi
        ON o.order_id = oi.order_id
    JOIN production.products p
        ON oi.product_id = p.product_id
    JOIN production.brands b
        ON p.brand_id = b.brand_id
    WHERE b.brand_name = 'Electra'
      AND YEAR(o.order_date) = 2018
    GROUP BY MONTH(o.order_date)
),
SalesWithLag AS (
    SELECT
        month,
        net_sales,
        LAG(net_sales) OVER (ORDER BY month) AS previous_month_sales
    FROM MonthlySales
)
SELECT
    month,
    net_sales,
    previous_month_sales,
    ROUND(
        ((net_sales - previous_month_sales) / previous_month_sales) * 100, 
        2
    ) AS pct_change
FROM SalesWithLag
ORDER BY month;

-- ============================================================
--  Question 8 — LEAD
--  a) For each customer, show order_id, order_date and the
--     order_date of their NEXT order as next_order_date.
--  b) Add a column days_to_next_order using DATEDIFF.
--     Orders with no next order should show NULL.
--  c) Repeat part (a) but use the third argument of LEAD to
--     replace NULL with '2099-12-31'.
-- ============================================================

--part a:
SELECT
    customer_id,
    order_id,
    order_date,
    LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS next_order_date
FROM sales.orders;

--part b:
SELECT
    customer_id,
    order_id,
    order_date,
    LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS next_order_date,
    DATEDIFF(
        DAY, 
        order_date, 
        LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date, order_id)
    ) AS days_to_next_order
FROM sales.orders;

--part c:
SELECT
    customer_id,
    order_id,
    order_date,
    LEAD(order_date, 1, '2099-12-31') OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS next_order_date
FROM sales.orders;

-- ============================================================
--  Question 9 — Running Total
--  a) Show each order's order_id, order_date and its total
--     order value, together with a running total of the order
--     value ordered by order_date, order_id.
--     Hint: SUM(...) OVER (ORDER BY order_date, order_id).
--  b) Restart the running total for every store_id
--     (PARTITION BY store_id).
-- ============================================================

--part a:
WITH OrderTotals AS (
    SELECT
        o.order_id,
        o.order_date,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS order_value
    FROM sales.orders o
    JOIN sales.order_items oi
        ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.order_date
)
SELECT
    order_id,
    order_date,
    order_value,
    SUM(order_value) OVER (ORDER BY order_date, order_id) AS running_total
FROM OrderTotals
ORDER BY order_date, order_id;

--part b:
WITH StoreOrderTotals AS (
    SELECT
        o.store_id,
        o.order_id,
        o.order_date,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS order_value
    FROM sales.orders o
    JOIN sales.order_items oi
        ON o.order_id = oi.order_id
    GROUP BY o.store_id, o.order_id, o.order_date
)
SELECT
    store_id,
    order_id,
    order_date,
    order_value,
    SUM(order_value) OVER (PARTITION BY store_id ORDER BY order_date, order_id) AS running_total
FROM StoreOrderTotals
ORDER BY store_id, order_date, order_id;

-- ============================================================
--  Question 10 — Challenge
--  Build a report for the year 2017 with one row per month:
--    month, total_sales, previous_month_sales,
--    sales_change (in %), and sales_rank
--    (rank of the month by total_sales, highest first).
--  Use a CTE for the monthly totals and combine LAG with
--  RANK in the final SELECT.
-- ============================================================

-- Write your query below:

WITH MonthlyTotals AS (
    SELECT
        MONTH(o.order_date) AS month,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_sales
    FROM sales.orders o
    JOIN sales.order_items oi
        ON o.order_id = oi.order_id
    WHERE YEAR(o.order_date) = 2017
    GROUP BY MONTH(o.order_date)
)
SELECT
    month,
    total_sales,
    LAG(total_sales) OVER (ORDER BY month) AS previous_month_sales,
    ROUND(
        ((total_sales - LAG(total_sales) OVER (ORDER BY month)) / LAG(total_sales) OVER (ORDER BY month)) * 100,
        2
    ) AS sales_change,
    RANK() OVER (ORDER BY total_sales DESC) AS sales_rank
FROM MonthlyTotals
ORDER BY month;