/*
-----------------------------------------------------------------------------------
Script : Coffee Shop Sales Analysis – Insights

Objective:
This project performs an end-to-end exploratory and analytical assessment of 
coffee shop sales data to uncover business insights across revenue, product performance, 
temporal trends, and store-level performance.

Scope of Analysis:
1. Data Exploration – Understanding dataset structure, coverage, and dimensions
2. KPI Overview – High-level business performance metrics
3. Time-Based Analysis – Monthly, daily, hourly, and weekday/weekend trends
4. Product Performance – Identifying top and underperforming products
5. Store Performance – Evaluating store-wise contribution and growth trends

Key Metrics:
- Total Revenue
- Total Orders
- Total Quantity Sold
- Average Order Value (AOV)
- Month-over-Month (MoM) Growth

Business Value:
The insights derived from this analysis can support:
- Demand planning and staffing decisions
- Product portfolio optimization
- Store-level performance benchmarking
- Sales trend forecasting

-----------------------------------------------------------------------------------
*/

use coffee_sales_db;

-- Retrieve list of columns and constraints
describe coffee_shop_sales;

-- ===============================================
--          *** Data Exploration***
-- ===============================================

-- Table view
select * 
from coffee_shop_sales;

-- Total number of Records
select
	count(*) as total_records
from coffee_shop_sales;

-- Retrieve a list of distinct locations where stores are located
select
	distinct store_location
from coffee_shop_sales;

-- Retrieve a list of unique product category, type and detail.
select distinct
	product_category,
    product_type,
    product_detail
from coffee_shop_sales
order by product_category, product_type, product_detail;

-- Determine dataset time range and duration (in months)
-- Note: 'TIMESTAMPDIFF' returns boundary difference, not inclusive months
select 
    min(transaction_date) as first_order_date,
    max(transaction_date) as last_order_date,
    timestampdiff(month,min(transaction_date),max(transaction_date)) as order_range_months
from coffee_shop_sales;


-- ===============================================
--          *** KPI Overview ***
-- ===============================================

-- Find the total revenue
select
	sum(transaction_qty*unit_price) as total_revenue
from coffee_shop_sales;

-- Find how many items are sold
select
	sum(transaction_qty) as total_quantity
from coffee_shop_sales;

-- Find the total number of transactions (proxy for total orders)
-- Note: Assumes each transaction_id represents one order
select
	 count(transaction_id) as total_orders
from coffee_shop_sales;

-- Find the Avg Order Value (AOV)
-- (Average Order Value (AOV) = Total Revenue / Total Orders)
select
	sum(transaction_qty*unit_price)/count(transaction_id) as avg_order_value
from coffee_shop_sales;

-- Find the total number of products
select
	count(distinct product_detail) as no_of_products
from coffee_shop_sales;

-- Generate a Report that shows all key metrics of the business
select 'Total Sales' as metric, sum(transaction_qty*unit_price) as metric_value from coffee_shop_sales
union all
select 'Total Quantity',sum(transaction_qty) from coffee_shop_sales
union all
select 'Total Orders', count(transaction_id) from coffee_shop_sales
union all
select 'Avg Order Value', sum(transaction_qty*unit_price)/count(transaction_id) from coffee_shop_sales
union all
select 'Total Products', count(distinct product_detail) from coffee_shop_sales;

-- ===============================================
--          *** Time Based Analysis ***
-- ===============================================

-- ::: Monthly performance analysis with Month-over-Month(MoM) growth :::
-- (Uses window functions (LAG) to compare current vs previous month
-- Handles divide-by-zero using NULLIF)
with monthly_performance as(
		select 
			month(transaction_date) as month_num,
            monthname(transaction_date) as month_name,
			sum(transaction_qty * unit_price) as total_sales,
            count(transaction_id) as total_orders,
            sum(transaction_qty) as total_quantities_sold
		from coffee_shop_sales
		group by month(transaction_date), monthname(transaction_date)
		),
mom_change as(
		select 
			month_num,
            month_name,
            total_sales,
            lag(total_sales) over(order by month_num) as prev_month_sales,
            total_orders,
            lag(total_orders) over(order by month_num) as prev_month_orders,
            total_quantities_sold,
            lag(total_quantities_sold) over(order by month_num) as prev_month_qty
		from monthly_performance
		)
select 
	month_name,
    total_sales,
    round((total_sales-prev_month_sales)*100.0/nullif(prev_month_sales,0),2) as mom_sales_growth,
    total_orders,
	round((total_orders-prev_month_orders)*100.0 /nullif(prev_month_orders,0),2) as mom_orders_growth,
    total_quantities_sold,
	round((total_quantities_sold-prev_month_qty)*100.0/nullif(prev_month_qty,0),2) as mom_quantities_growth
from mom_change
order by month_num;

-- ::: Computes average daily sales per month :::
-- Step 1: Aggregate daily sales
-- Step 2: Take monthly average of daily totals
with month_daily_sales as(
	select
		monthname(transaction_date) as month_name,
		day(transaction_date) as day_of_month,
		sum(transaction_qty*unit_price) as total_sales
	from coffee_shop_sales
	group by monthname(transaction_date),day(transaction_date)
    )
select
	month_name,
    round(avg(total_sales),2) as daily_avg_sales
from month_daily_sales
group by month_name;

-- ::: Hourly sales distribution :::
-- (Helps identify peak business hours for staffing and promotions)
select
	extract(hour from transaction_time) as hour_of_day,
    sum(transaction_qty*unit_price) as total_sales,
	sum(transaction_qty) as quantities_sold,
    count(transaction_id) as orders_placed
from coffee_shop_sales
group by hour_of_day
order by hour_of_day;

-- ::: Trend analysis by Days of week for key metrics :::
select
	dayname(transaction_date) as day_of_week,
    sum(transaction_qty*unit_price) as total_sales,
	sum(transaction_qty) as quantities_sold,
    count(transaction_id) as orders_placed
from coffee_shop_sales
group by day_of_week;


-- ::: Weekdays vs Weekends Sales Performance :::
-- Sales Analysis by weekdays and weekends
-- (Useful for demand pattern segmentation)
with daytype_sales as (                       -- weekday(): 0 = Monday, 6 = Sunday
    select
        case when weekday(transaction_date) between 0 and 4 then 'weekdays'
             else 'weekends'
        end as day_type,
        sum(transaction_qty*unit_price) as total_sales
    from coffee_shop_sales
    group by day_type )
select
    day_type,
    total_sales,
    round(total_sales*100.0/ sum(total_sales) over(),2) as perc_of_total
from daytype_sales;

-- Sales Analysis by weekdays and weekends for each month
-- Uses window function (sum() over()) for percentage contribution within each month
with sales_by_monthly_daytype as (
	select
		month(transaction_date) as month_num,
        monthname(transaction_date) as month_name,
		case when weekday(transaction_date) between 0 and 4 then 'weekdays' 
			 else 'weekends' 
		end as day_type,
		sum(transaction_qty*unit_price) as total_sales
	from coffee_shop_sales
	group by month_num, month_name, day_type)
select
	month_name,
    day_type,
    total_sales,
	round(total_sales*100.0/ (sum(total_sales) over(partition by month_num)),2) as perc_of_monthtotal
from sales_by_monthly_daytype
order by month_num, day_type;


-- ===============================================
--     *** Product Performance Analysis ***
-- ===============================================

-- Top 10 revenue-generating products
-- Helps identify best-performing products
select
	product_detail,
	sum(transaction_qty*unit_price) as total_sales,
	sum(transaction_qty) as quantities_sold
from coffee_shop_sales
group by product_detail
order by total_sales desc
limit 10;

-- Bottom 10 products by revenue
-- Useful for identifying underperforming or dead stock candidates
select
	product_detail,
	sum(transaction_qty*unit_price) as total_sales,
	sum(transaction_qty) as quantities_sold
from coffee_shop_sales
group by product_detail
order by total_sales asc
limit 10;
	
-- Find the no. of products per category
select
	product_category,
    count(distinct product_detail) as no_of_products
from coffee_shop_sales
group by product_category;

-- ::: Category-wise contribution to total revenue :::
-- Uses window function to compute percentage share
-- Helps prioritize high-impact categories
with category_sales as(
	select
		product_category,
        sum(transaction_qty*unit_price) as total_sales
	from coffee_shop_sales
    group by product_category
)
select 
	product_category,
	total_sales,
	round(total_sales*100.0 /(sum(total_sales) over()),2) as perc_of_total
from category_sales
order by total_sales desc;

-- ===============================================
--       *** Store Performance Analysis ***
-- ===============================================

-- Sales Analysis by Store
with store_sales as (
	select
		store_id,
        store_location,
        sum(transaction_qty*unit_price) as total_sales
	from coffee_shop_sales
    group by store_id, store_location 
    )
select store_id,
	   store_location,
	   total_sales,
       round(total_sales*100.0 /(sum(total_sales) over()),2) as perc_of_total
from store_sales
order by total_sales desc;

-- ::: Month-over-Month growth analysis at store level :::
-- Partitioned by store_id to track individual store trends
-- Helps identify expanding vs declining stores
with store_monthly_sales as (
	select
		store_id,
        store_location,
        month(transaction_date) as month_num,
        monthname(transaction_date) as month_name,
        sum(transaction_qty*unit_price) as total_sales
	from coffee_shop_sales
    group by store_id, store_location, month_num, month_name
    ),
mom_change as(
		select
			store_id,
            store_location,
			month_num,
            month_name,
            total_sales,
            lag(total_sales) over(partition by store_id order by month_num) as prev_month_sales
		from store_monthly_sales
		)
select store_id,
	   store_location,
       month_name,
	   total_sales,
       prev_month_sales,
       round((total_sales-prev_month_sales)*100.0/nullif(prev_month_sales,0),2) as mom_growth_rate
from mom_change
order by store_id, month_num ;

-- ===========================================================================================================