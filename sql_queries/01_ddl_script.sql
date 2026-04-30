/*
--------------------------------------------------------------------------------------------------------
Script: Database and Table Setup for Coffee Shop Sales Analysis

Purpose:
- Create a database 'coffee_sales_db' (if not already exists).
- Define and create a structured table with appropriate data types.
- Perform bulk data ingestion using 'LOAD DATA INFILE' for high-performance loading.
- Clean and transform raw data (date conversion) post ingestion.
- Add indexes for performance optimization

Note:
- 'LOAD DATA INFILE' requires correct file path and local infile to be enabled.
--------------------------------------------------------------------------------------------------------
*/

-- Create database
create database if not exists coffee_sales_db;
use coffee_sales_db;

-- Drop and create fresh table (for clean re-run)
drop table if exists coffee_shop_sales;
create table coffee_shop_sales(
	transaction_id int primary key,
    transaction_date date,
    transaction_time time,
    transaction_qty int,
    store_id int,
    store_location varchar(50),
    product_id int,
    unit_price decimal(6,2),
    product_category varchar(50),
    product_type varchar(100),
    product_detail varchar(100)
);
    
    
-- Bulk Load Data
load data local infile 'C:/Users/hp/Desktop/Projects/Coffee Shop Sales Analysis/dataset/Coffee Shop Sales CSV.csv'
into table coffee_shop_sales
fields terminated by ','
enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(transaction_id, @transaction_date, transaction_time, transaction_qty, store_id,
 store_location, product_id, unit_price, product_category, product_type, product_detail)
set transaction_date = str_to_date(@transaction_date,'%d-%m-%Y');

-- Create indexes for faster querying
create index idx_transaction_date on coffee_shop_sales(transaction_date);
create index idx_store_id on coffee_shop_sales(store_id);
create index idx_product_id on coffee_shop_sales(product_id);

-- -----------------------------------------------------------------------------------------
