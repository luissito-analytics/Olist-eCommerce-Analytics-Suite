/*  =============================================================================================
	1.0: SCHEMA CREATION AND STAGING 
	Database: Olist Brazilian E-Commerce Dataset
	Purpose: Extracting raw staging tables (stg_*) and transforming them into deduplicated
			dimension (dim_*) and grain_aligned fact (fact_*) tables with primary keys.
	=============================================================================================
	OUTLINE OF QUERIES:
		- 1.1: Customer Dimension Table (Deduplicated to person-level unique ID)
		- 1.2: Geolocation Dimension Table (Aggregated to unique 5-digit zip prefix)
		- 1.3: Order Items Fact Table (Grain: 1 row per order line item)
		- 1.4: Order Payments Fact Table (Grain: 1 row per payment sequence)
		- 1.5: Order Reviews Fact Table (Deduplicated to Unique review_id)
		- 1.6: Orders Fact Table (Mapped to customer_unique_id for cohort tracking)
		- 1.7: Product Dimension Table
		- 1.8: Sellers Dimension Table
		- 1.9: Product Category English Translation Lookup Table
		- 1.10: Brazilian Customer State Full Name Lookup Table

	DATA INGESTION NOTE:
	Raw CSV files from the Olist Kaggle dataset were imported into the staging 
	tables above via the pgAdmin 4 Import/Export Data GUI (UTF-8 encoding, 
	comma-delimited, header row enabled).
	
	*/
	---------------------------------------------------------------------------------------------
-- 	1.1: Customer Dimension Table (Deduplicated to person-level unique ID)
	---------------------------------------------------------------------------------------------
	
	CREATE TABLE stg_customers(
		customer_id VARCHAR(50) PRIMARY KEY,
		customer_unique_id VARCHAR(50),
		customer_zip_code_prefix VARCHAR(5),
		customer_city VARCHAR(50),
		customer_state VARCHAR(2)
	);
	
	CREATE TABLE dim_customers(
		customer_unique_id VARCHAR(50) PRIMARY KEY,
		customer_zip_code_prefix VARCHAR(5),
		customer_city VARCHAR(50),
		customer_state VARCHAR(2)
	);
	
	INSERT INTO dim_customers (
		customer_unique_id, 
		customer_zip_code_prefix, 
		customer_city, 
		customer_state
	)
	SELECT
		customer_unique_id,
		MAX(customer_zip_code_prefix) AS customerzip_code_prefix,
		MAX(customer_city) AS customer_city,
		MAX(customer_state) AS customer_state
	FROM stg_customers
	GROUP BY customer_unique_id;

	---------------------------------------------------------------------------------------------
-- 	1.2: Geolocation Dimension Table (Aggregated to unique 5-digit zip prefix)
	---------------------------------------------------------------------------------------------

	CREATE TABLE stg_geolocation (
		geolocation_zip_code_prefix VARCHAR(5),
		geolocation_lat NUMERIC,
		geolocation_lng NUMERIC,
		geolocation_city VARCHAR(50),
		geolocation_state VARCHAR(2)
	);
	
	CREATE TABLE dim_geolocation (
		geolocation_zip_code_prefix VARCHAR(5) PRIMARY KEY,
		geolocation_lat NUMERIC,
		geolocation_lng NUMERIC,
		geolocation_city VARCHAR(50),
		geolocation_state VARCHAR(2) 
	);
	
	
	INSERT INTO dim_geolocation (
		geolocation_zip_code_prefix, 
		geolocation_lat, 
		geolocation_lng, 
		geolocation_city, 
		geolocation_state
	)
	SELECT
		geolocation_zip_code_prefix,
		AVG(geolocation_lat) AS geolocation_lat,
		AVG(geolocation_lng) AS geolocation_lng,
		MAX(geolocation_city) AS geolocation_city,
		MAX(geolocation_state) AS geolocation_state
	FROM stg_geolocation
	GROUP BY geolocation_zip_code_prefix;

	---------------------------------------------------------------------------------------------
-- 	1.3: Order Items Fact Table (Grain: 1 row per order line item)
	---------------------------------------------------------------------------------------------

	CREATE TABLE stg_orderitems (
		order_id VARCHAR(50),
		order_item_id SMALLINT,
		product_id VARCHAR(50),
		seller_id VARCHAR(50),
		shipping_limit_date TIMESTAMP,
		price DECIMAL(10,2),
		freight_value DECIMAL(10,2)
	);
	
	CREATE TABLE fact_orderitems (
		order_id VARCHAR(50),
		order_item_id SMALLINT,
		product_id VARCHAR(50),
		seller_id VARCHAR(50),
		shipping_limit_date TIMESTAMP,
		price DECIMAL(10,2),
		freight_value DECIMAL(10,2),
		PRIMARY KEY (order_id, order_item_id)
	);
	
	INSERT INTO fact_orderitems (
		order_id,
		order_item_id,
		product_id,
		seller_id,
		shipping_limit_date,
		price,
		freight_value
	)
	SELECT
		order_id,
		order_item_id,
		product_id,
		seller_id,
		shipping_limit_date,
		price,
		freight_value
	FROM stg_orderitems;

	---------------------------------------------------------------------------------------------
-- 	1.4: Order Payments Fact Table (Grain: 1 row per payment sequence)
	---------------------------------------------------------------------------------------------

	CREATE TABLE stg_orderpayments (
		order_id VARCHAR(50),
		payment_sequential SMALLINT,
		payment_type VARCHAR(15),
		payment_installments SMALLINT,
		payment_value DECIMAL(10,2)
	);
	
	
	CREATE TABLE fact_orderpayments (
		order_id VARCHAR(50),
		payment_sequential SMALLINT,
		payment_type VARCHAR(15),
		payment_installments SMALLINT,
		payment_value DECIMAL(10,2),
		PRIMARY KEY (order_id, payment_sequential)
	);
	
	INSERT INTO fact_orderpayments (
		order_id,
		payment_sequential,
		payment_type,
		payment_installments,
		payment_value
	)
	SELECT
		order_id,
		payment_sequential,
		payment_type,
		payment_installments,
		payment_value
	FROM stg_orderpayments;

	---------------------------------------------------------------------------------------------
-- 	1.5: Order Reviews Fact Table (Deduplicated to Unique review_id)
	---------------------------------------------------------------------------------------------

	CREATE TABLE stg_orderreviews (
		review_id VARCHAR(50),
		order_id VARCHAR(50),
		review_score SMALLINT,
		review_comment_title TEXT,
		review_comment_message TEXT,
		review_creation_date TIMESTAMP,
		review_answer_timestamp TIMESTAMP
	);
	
	CREATE TABLE fact_orderreviews (
		review_id VARCHAR(50) PRIMARY KEY,
		order_id VARCHAR(50),
		review_score SMALLINT,
		review_comment_title TEXT,
		review_comment_message TEXT,
		review_creation_date TIMESTAMP,
		review_answer_timestamp TIMESTAMP
	);
	
	INSERT INTO fact_orderreviews (
		review_id,
		order_id,
		review_score,
		review_comment_title,
		review_comment_message,
		review_creation_date,
		review_answer_timestamp
	)
	SELECT
		review_id,
		MAX(order_id) AS order_id,
		MAX(review_score) AS review_score,
		MAX(review_comment_title) AS review_comment_title,
		MAX(review_comment_message) AS review_comment_message,
		MAX(review_creation_date) AS review_creation_date,
		MAX(review_answer_timestamp) AS review_answer_timestamp
	FROM stg_orderreviews
	GROUP BY review_id;

	---------------------------------------------------------------------------------------------
-- 	1.6: Orders Fact Table (Mapped to customer_unique_id for cohort tracking)
	---------------------------------------------------------------------------------------------

	CREATE TABLE stg_orders (
		order_id VARCHAR(50),
		customer_id VARCHAR(50),
		order_status VARCHAR(15),
		order_purchase_timestamp TIMESTAMP,
		order_approved_at TIMESTAMP,
		order_delivered_carrier_date TIMESTAMP,
		order_delivered_customer_date TIMESTAMP,
		order_estimated_delivery_date TIMESTAMP
	);
	
	CREATE TABLE fact_orders (
		order_id VARCHAR(50) PRIMARY KEY,
		customer_unique_id VARCHAR(50),
		order_status VARCHAR(15),
		order_purchase_timestamp TIMESTAMP,
		order_approved_at TIMESTAMP,
		order_delivered_carrier_date TIMESTAMP,
		order_delivered_customer_date TIMESTAMP,
		order_estimated_delivery_date TIMESTAMP
	);
	
	INSERT INTO fact_orders (
		order_id,
		customer_unique_id,
		order_status,
		order_purchase_timestamp,
		order_approved_at,
		order_delivered_carrier_date,
		order_delivered_customer_date,
		order_estimated_delivery_date
	)
	SELECT
		o.order_id,
		c.customer_unique_id,
		MAX(o.order_status) AS order_status,
		MAX(o.order_purchase_timestamp) AS order_purchase_timestamp,
		MAX(o.order_approved_at) AS order_approved_at,
		MAX(o.order_delivered_carrier_date) AS order_delivered_carrier_date,
		MAX(o.order_delivered_customer_date) AS order_delivered_customer_date,
		MAX(o.order_estimated_delivery_date) AS order_estimated_delivery_date
	FROM stg_orders o
	JOIN stg_customers c ON o.customer_id = c.customer_id
	GROUP BY o.order_id, c.customer_unique_id;

	---------------------------------------------------------------------------------------------
-- 	1.7: Product Dimension Table
	---------------------------------------------------------------------------------------------

	CREATE TABLE stg_products (
		product_id VARCHAR(50),
		product_category_name VARCHAR(100),
		product_name_lenght INT,
		product_description_lenght INT,
		product_photos_qty INT,
		product_weight_g INT,
		product_length_cm INT,
		product_height_cm INT,
		product_width_cm INT
	);
	
	CREATE TABLE dim_products (
		product_id VARCHAR(50) PRIMARY KEY,
		product_category_name VARCHAR(100),
		product_name_lenght INT,
		product_description_lenght INT,
		product_photos_qty INT,
		product_weight_g INT,
		product_length_cm INT,
		product_height_cm INT,
		product_width_cm INT
	);
	
	INSERT INTO dim_products (
		product_id,
		product_category_name,
		product_name_lenght,
		product_description_lenght,
		product_photos_qty,
		product_weight_g,
		product_length_cm,
		product_height_cm,
		product_width_cm
	)
	SELECT 
		product_id,
		MAX(product_category_name) AS product_category_name,
		MAX(product_name_lenght) AS product_name_lenght,
		MAX(product_description_lenght) AS product_description_lenght,
		MAX(product_photos_qty) AS product_photos_qty,
		MAX(product_weight_g) AS product_weight_g,
		MAX(product_length_cm) AS product_length_cm,
		MAX(product_height_cm) AS product_height_cm,
		MAX(product_width_cm) AS product_width_cm
	FROM stg_products
	GROUP BY product_id;

	---------------------------------------------------------------------------------------------
-- 	1.8: Sellers Dimension Table
	---------------------------------------------------------------------------------------------

	CREATE TABLE stg_sellers (
		seller_id VARCHAR(50),
		seller_zip_code_prefix VARCHAR(5),
		seller_city VARCHAR(50),
		seller_state VARCHAR(2)
	);
	
	CREATE TABLE dim_sellers (
		seller_id VARCHAR(50) PRIMARY KEY,
		seller_zip_code_prefix VARCHAR(5),
		seller_city VARCHAR(50),
		seller_state VARCHAR(2)
	);
	
	INSERT INTO dim_sellers (
		seller_id,
		seller_zip_code_prefix,
		seller_city,
		seller_state
	)
	SELECT
		seller_id,
		MAX(seller_zip_code_prefix) AS seller_zip_code_prefix,
		MAX(seller_city) AS seller_city,
		MAX(seller_state) AS seller_state
	FROM stg_sellers
	GROUP BY seller_id;

	---------------------------------------------------------------------------------------------
-- 	1.9: Product Category English Translation Lookup Table
	---------------------------------------------------------------------------------------------

	CREATE TABLE stg_productcategoryname (
		product_category_name VARCHAR(50),
		product_category_name_english VARCHAR(50)
	);
	
	CREATE TABLE dim_productcategoryname (
		product_category_name VARCHAR(50) PRIMARY KEY,
		product_category_name_english VARCHAR(50)
	);
	
	INSERT INTO dim_productcategoryname (
		product_category_name,
		product_category_name_english
	)
	SELECT
		product_category_name,
		MAX(product_category_name_english) AS product_category_name_english
	FROM stg_productcategoryname
	GROUP BY product_category_name;

	---------------------------------------------------------------------------------------------
-- 	1.10: Brazilian Customer State Full Name Lookup Table
	---------------------------------------------------------------------------------------------

	CREATE TABLE stg_customerstates (
		customer_state VARCHAR(2),
		customer_state_full_name VARCHAR(50)
	);
	
	CREATE TABLE dim_customerstates (
		customer_state VARCHAR(2) PRIMARY KEY,
		customer_state_full_name VARCHAR(50)
	);
	
	INSERT INTO dim_customerstates (
		customer_state,
		customer_state_full_name
	)
	SELECT 
		customer_state,
		MAX(customer_state_full_name) AS customer_state_full_name
	FROM stg_customerstates
	GROUP BY customer_state;
