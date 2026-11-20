/*  =============================================================================================
	3.0: KPI VALIDATION & EXPLORATORY DATA ANALYSIS ON OPERATIONAL METRICS AND DELIVERY PERFORMANCE TAB
	Database: Olist Brazilian E-Commerce Dataset
	Purpose: Conduct exploratory analysis and KPI calculations for the Operational Metrics and
			Delivery Performance Tab
	============================================================================================= 
      OUTLINE OF QUERIES:
		- 3.1: COUNTRY-WIDE HEADLINE SLAs (WITH YoY COMPARISON)	 					(Line 24)
			- 3.1A: Year-over-Year (YoY) Late Delivery Rate
			- 3.1B: Year-over-Year (YoY) Avg. Fulfillment Lead Time				
			- 3.1C: Year-over-Year (YoY) On-Time In-Full (OTIF) Rate			
			
		- 3.2: DELAY ROOT-CAUSE ATTRIBUTION SPLIT										(Line 158)
			- 3.2A: Total Delayed Orders split into Carrier Transit Delay 
					and Seller Dispatch Delay
			
		- 3.3: GEOGRAPHIC, ROUTE & CATEGORY BOTTLENECKS								(Line 218)
			- 3.3A: State-Level Late Delivery Ranking (2018 Reporting Period)
			- 3.3B: Average Installments
			- 3.3C:Top Bottlenecked Product Categories by late delivery rate
			- 3.3D: Seller Hub Performance Summary
		*/
	---------------------------------------------------------------------------------------------
/* 	3.1: COUNTRY-WIDE HEADLINE SLAs (WITH YoY COMPARISON) */
	---------------------------------------------------------------------------------------------
---	3.1A: Year-over-Year (YoY) Late Delivery Rate
--- Late Delivery Rate in 2018: 9.37% (+41.33% YoY from 2017)
--- Scoped to order_status = delivered where delivery dates (customer and etimated) are NOT NULL
	---------------------------------------------------------------------------------------------
	
	WITH annual_delivery_sla AS (
		SELECT
			EXTRACT(YEAR FROM order_purchase_timestamp) AS order_year,
			COUNT(DISTINCT order_id) AS total_delivered_orders,
			COUNT(DISTINCT CASE
				WHEN order_delivered_customer_date > order_estimated_delivery_date
				THEN order_id
			END) AS late_orders,
			ROUND(
				100.0 * COUNT(DISTINCT CASE
					WHEN order_delivered_customer_date > order_estimated_delivery_date
					THEN order_id
				END) / NULLIF(COUNT(DISTINCT order_id), 0),
			2) AS late_delivery_rate_pct
		FROM fact_orders
		WHERE order_status = 'delivered'
			AND order_purchase_timestamp IS NOT NULL
			AND order_delivered_customer_date IS NOT NULL
			AND order_estimated_delivery_date IS NOT NULL
		GROUP BY order_year
	)
	SELECT
		order_year,
		total_delivered_orders,
		late_orders,
		late_delivery_rate_pct,
		LAG(late_delivery_rate_pct) OVER (ORDER BY order_year) AS prior_year_late_delivery_rate,
		ROUND(
			100.0 * (late_delivery_rate_pct - LAG(late_delivery_rate_pct) OVER (ORDER BY order_year)) /
			NULLIF(LAG(late_delivery_rate_pct) OVER (ORDER BY order_year),0),
			2
		) AS yoy_relative_change_pct
	FROM annual_delivery_sla
	ORDER BY order_year;
	
	---------------------------------------------------------------------------------------------
---	3.1B: Year-over-Year (YoY) Avg. Fulfillment Lead Time
--- Avg. Fulfillment Lead Time in 2018: 2.57 days (-14.90% YoY from 2018)
--- Scoped to order_status = delivered AND approval/delivered dates are NOT NULL
	---------------------------------------------------------------------------------------------

	WITH annual_fulfillment AS (
		SELECT
			EXTRACT(YEAR FROM order_purchase_timestamp) AS order_year,
			COUNT(DISTINCT order_id) AS delivered_orders_with_handoff,
			ROUND(
				AVG(EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at)) / 86400.0)::NUMERIC,
				2
			) AS avg_fulfillment_days,
			ROUND(
				AVG(EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at)) / 3600.0)::NUMERIC,
				2
			) AS avg_fulfillment_hours
		FROM fact_orders
		WHERE order_status = 'delivered'
			AND order_purchase_timestamp IS NOT NULL
			AND order_approved_at IS NOT NULL
			AND order_delivered_carrier_date IS NOT NULL
		GROUP BY order_year
	)
	SELECT
		order_year,
		delivered_orders_with_handoff,
		avg_fulfillment_days,
		ROUND(
			100.0 * (avg_fulfillment_days - LAG(avg_fulfillment_days) OVER (ORDER BY order_year)) /
			NULLIF(LAG(avg_fulfillment_days) OVER (ORDER BY order_year), 0),
			2
		) AS yoy_days_change_pct,
		avg_fulfillment_hours,
		ROUND(
			100.0 * (avg_fulfillment_hours - LAG(avg_fulfillment_hours) OVER (ORDER BY order_year)) /
			NULLIF(LAG(avg_fulfillment_hours) OVER (ORDER BY order_year), 0),
			2
		) AS yoy_hours_change_pct
	FROM annual_fulfillment
	ORDER BY order_year;

	---------------------------------------------------------------------------------------------
---	3.1C: Year-over-Year (YoY) On-Time In-Full (OTIF) Rate
--- OTIF Rate in 2018: 90.63% (-2.93% relative YoY from 2017)
--- Scoped to order_status = delivered AND actual/estimated delivery dates NOT NULL
	---------------------------------------------------------------------------------------------

	WITH order_items_check AS (
		SELECT DISTINCT
			order_id
		FROM fact_orderitems
	),
	annual_otif AS (
		SELECT
			EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
			COUNT(DISTINCT o.order_id) AS total_delivered_orders,
			COUNT(DISTINCT CASE
				WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
				THEN o.order_id
			END) AS otif_orders,
			ROUND(
				100.0 * COUNT(DISTINCT CASE
					WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
					THEN o.order_id
				END) / NULLIF(COUNT(DISTINCT o.order_id), 0),
				2
			) AS otif_rate_pct
		FROM fact_orders o
		JOIN order_items_check oi ON o.order_id = oi.order_id
		WHERE o.order_status = 'delivered'
			AND o.order_purchase_timestamp IS NOT NULL
			AND o.order_delivered_customer_date IS NOT NULL
			AND o.order_estimated_delivery_date IS NOT NULL
		GROUP BY order_year
	)
	SELECT
		order_year,
		total_delivered_orders,
		otif_orders,
		otif_rate_pct,
		LAG(otif_rate_pct) OVER (ORDER BY order_year) AS prior_year_otif_pct,
		ROUND(
			100.0 * (otif_rate_pct - LAG(otif_rate_pct) OVER (ORDER BY order_year)) / 
			NULLIF(LAG(otif_rate_pct) OVER (ORDER BY order_year), 0),
			2
		) AS yoy_relative_change_pct
	FROM annual_otif
	ORDER BY order_year;
	
	---------------------------------------------------------------------------------------------
/*	3.2: DELAY ROOT-CAUSE ATTRIBUTION SPLIT */
	---------------------------------------------------------------------------------------------
---	3.2A: Total Delayed Orders split into Carrier Transit Delay and Seller Dispatch Delay
--- Delay Root Cause Breakdown in 2018: CTD (94.05% at +1.36 YoY) and SDD (5.95% at -0.08% YoY)
--- Scoped to order_status = delivered AND relevant dates NOT NULL at order level
	---------------------------------------------------------------------------------------------
	
	WITH annual_delay_attribution AS (
		SELECT
			EXTRACT(YEAR FROM order_purchase_timestamp) AS order_year,
			COUNT(DISTINCT order_id) AS total_delayed_orders,
			COUNT(DISTINCT CASE
				WHEN order_delivered_carrier_date > order_estimated_delivery_date
				THEN order_id
			END) AS seller_dispatch_delay_orders,
			COUNT(DISTINCT CASE
				WHEN order_delivered_carrier_date <= order_estimated_delivery_date
				THEN order_id
			END) AS carrier_transit_delay_orders
		FROM fact_orders
		WHERE order_status = 'delivered'
			AND order_purchase_timestamp IS NOT NULL
			AND order_delivered_customer_date IS NOT NULL
			AND order_estimated_delivery_date IS NOT NULL
			AND order_delivered_carrier_date IS NOT NULL
			AND order_delivered_customer_date > order_estimated_delivery_date
		GROUP BY order_year
	),
	delay_shares AS (
		SELECT
			order_year,
			total_delayed_orders,
			seller_dispatch_delay_orders,
			ROUND(100.0 * seller_dispatch_delay_orders / NULLIF(total_delayed_orders, 0), 2) AS seller_delay_share_pct,
			carrier_transit_delay_orders,
			ROUND(100.0 * carrier_transit_delay_orders / NULLIF(total_delayed_orders, 0), 2) AS carrier_delay_share_pct
		FROM annual_delay_attribution
	)
	SELECT
		order_year,
		total_delayed_orders,
		seller_dispatch_delay_orders,
		seller_delay_share_pct,
		ROUND(
			100.0 * (seller_delay_share_pct - LAG(seller_delay_share_pct) OVER (ORDER BY order_year)) /
			NULLIF(LAG(seller_delay_share_pct) OVER (ORDER BY order_year), 0),
			2
		) AS seller_share_yoy_rel_pct,
		carrier_transit_delay_orders,
		carrier_delay_share_pct,
		ROUND(
			100.0 * (carrier_delay_share_pct - LAG(carrier_delay_share_pct) OVER (ORDER BY order_year)) /
			NULLIF(LAG(carrier_delay_share_pct) OVER (ORDER BY order_year), 0),
			2
		) AS carrier_share_yoy_rel_pct
	FROM delay_shares
	ORDER BY order_year;
	

	---------------------------------------------------------------------------------------------
/*	3.3: GEOGRAPHIC, ROUTE & CATEGORY BOTTLENECKS */
	---------------------------------------------------------------------------------------------
---	3.3A: State-Level Late Delivery Ranking (2018 Reporting Period)
--- Top 3  States in Late Delivery Rates: AL (24.24%), MA (22.83%), CE (21.01%)
--- Scoped to order_status = delivered AND relevant dates NOT NULL
	---------------------------------------------------------------------------------------------
	
	WITH state_delivery_sla AS (
		SELECT
			c.customer_state,
			COUNT(DISTINCT o.order_id) AS total_delivered_orders,
			COUNT(DISTINCT CASE
				WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
				THEN o.order_id
			END) AS late_orders,
			ROUND(
				100.0 * COUNT(DISTINCT CASE
					WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
					THEN o.order_id
				END) / NULLIF(COUNT(DISTINCT o.order_id), 0),
				2
			) AS late_delivery_rate_pct
		FROM fact_orders o
		JOIN dim_customers c ON o.customer_unique_id = c.customer_unique_id
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
			AND o.order_status = 'delivered'
			AND o.order_purchase_timestamp IS NOT NULL
			AND o.order_delivered_customer_date IS NOT NULL
			AND o.order_estimated_delivery_date IS NOT NULL
			AND c.customer_state IS NOT NULL
		GROUP BY c.customer_state
	)
	SELECT
		RANK() OVER (ORDER BY late_delivery_rate_pct DESC, late_orders DESC) AS state_rank,
		customer_state,
		total_delivered_orders,
		late_orders,
		late_delivery_rate_pct
	FROM state_delivery_sla
	ORDER BY state_rank;

	---------------------------------------------------------------------------------------------
---	3.3B: Top Delayed Shipping Routes (2018 Reporting Period)
--- Top Critical Shipping Route Bottlenecked: SP -> SP (17,995 delivered; 7.14%)
--- Scoped to order_status = delivered with minimum order volume threshold >= 10 at order level
	---------------------------------------------------------------------------------------------
	
	WITH order_routes AS (
		SELECT DISTINCT
			o.order_id,
			s.seller_state,
			c.customer_state,
			s.seller_state || ' -> ' || c.customer_state AS shipping_route,
			o.order_delivered_customer_date,
			o.order_estimated_delivery_date,
			EXTRACT(EPOCH FROM(o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0 AS exact_days_variance,
			(o.order_delivered_customer_date::DATE - o.order_estimated_delivery_date::DATE) AS calendar_days_variance
		FROM fact_orders o
		JOIN fact_orderitems oi ON o.order_id = oi.order_id
		JOIN dim_sellers s ON oi.seller_id = s.seller_id
		JOIN dim_customers c ON o.customer_unique_id = c.customer_unique_id
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
			AND o.order_status = 'delivered'
			AND o.order_purchase_timestamp IS NOT NULL
			AND o.order_delivered_customer_date IS NOT NULL
			AND o.order_estimated_delivery_date IS NOT NULL
			AND s.seller_state IS NOT NULL
			AND c.customer_state IS NOT NULL
	)
	SELECT
		shipping_route,
		seller_state,
		customer_state,
		COUNT(DISTINCT order_id) AS total_delivered_orders,
		COUNT(DISTINCT CASE
			WHEN order_delivered_customer_date > order_estimated_delivery_date
			THEN order_id
		END) AS delayed_orders,
		ROUND(
			100.0 * COUNT(DISTINCT CASE
				WHEN order_delivered_customer_date > order_estimated_delivery_date
				THEN order_id
			END) / NULLIF(COUNT(DISTINCT order_id), 0),
			2
		) AS route_late_rate_pct,
		ROUND(
			AVG(CASE
				WHEN order_delivered_customer_date > order_estimated_delivery_date
				THEN exact_days_variance
			END)::NUMERIC,
			2
		) AS avg_delay_days_late_only,
		ROUND(
			AVG(CASE
				WHEN order_delivered_customer_date > order_estimated_delivery_date
				THEN calendar_days_variance
			END)::NUMERIC,
			2
		) AS avg_cal_days_late_only,
		ROUND(AVG(exact_days_variance)::NUMERIC,2) AS avg_days_variance_all_orders
	FROM order_routes
	GROUP BY shipping_route, seller_state, customer_state
	HAVING COUNT(DISTINCT CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN order_id END) >= 10
	ORDER BY delayed_orders DESC, avg_delay_days_late_only DESC
	LIMIT 15;
	
	---------------------------------------------------------------------------------------------
---	3.3C: Top Bottlenecked Product Categories by late delivery rate
--- Bottlenecked Product Categories in 2018: Home Comfort 2 (28.57%), Fashion Underwear Beach (21.62%), Furniture Mattress and Upholstery (21.05%)
--- Scoped to order_status = delivered and Dates NOT NULL at order level
	---------------------------------------------------------------------------------------------
	
	WITH category_orders AS (
		SELECT DISTINCT
			o.order_id,
			COALESCE(pc.product_category_name_english, p.product_category_name, 'Uncategorized') AS product_category,
			o.order_delivered_customer_date,
			o.order_estimated_delivery_date
		FROM fact_orders o
		JOIN fact_orderitems oi ON o.order_id = oi.order_id
		JOIN dim_products p ON oi.product_id = p.product_id
		LEFT JOIN dim_productcategoryname pc ON p.product_category_name = pc.product_category_name
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
			AND o.order_status = 'delivered'
			AND o.order_purchase_timestamp IS NOT NULL
			AND o.order_delivered_customer_date IS NOT NULL
			AND o.order_estimated_delivery_date IS NOT NULL
			AND COALESCE(pc.product_category_name_english, p.product_category_name) IS NOT NULL
	)
	SELECT
		product_category,
		COUNT(DISTINCT order_id) AS total_delivered_orders,
		COUNT(DISTINCT CASE
			WHEN order_delivered_customer_date > order_estimated_delivery_date
			THEN order_id
		END) AS late_orders,
		ROUND(
			100.0 * COUNT(DISTINCT CASE
				WHEN order_delivered_customer_date > order_estimated_delivery_date
				THEN order_id
			END) / NULLIF(COUNT(DISTINCT order_id), 0),
			2
		) AS late_delivery_rate_pct
	FROM category_orders
	GROUP BY product_category
	ORDER BY late_delivery_rate_pct DESC, late_orders DESC;
	
	---------------------------------------------------------------------------------------------
---	3.3D: Seller Hub Performance Summary
--- Critical Seller Hub in 2018: SP with 3,800 delayed orders (10.04%) 
--- Scoped to order_status = delivered and Dates NOT NULL at order level
	---------------------------------------------------------------------------------------------
	
	WITH hub_orders AS (
		SELECT DISTINCT
			o.order_id,
			s.seller_state AS seller_hub,
			o.order_purchase_timestamp,
			o.order_delivered_carrier_date,
			o.order_delivered_customer_date,
			o.order_estimated_delivery_date,
			EXTRACT(EPOCH FROM (o.order_delivered_carrier_date - o.order_purchase_timestamp)) / 86400.0 AS seller_dispatch_exact_days,
			(o.order_delivered_carrier_date::DATE - o.order_purchase_timestamp::DATE) AS seller_dispatch_cal_days,
			EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_delivered_carrier_date)) / 86400.0 AS carrier_transit_exact_days,
			(o.order_delivered_customer_date::DATE - o.order_delivered_carrier_date::DATE) AS carrier_transit_cal_days
		FROM fact_orders o
		JOIN fact_orderitems oi ON o.order_id = oi.order_id
		JOIN dim_sellers s ON oi.seller_id = s.seller_id
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
			AND o.order_status = 'delivered'
			AND o.order_purchase_timestamp IS NOT NULL
			AND o.order_delivered_carrier_date IS NOT NULL
			AND o.order_delivered_customer_date IS NOT NULL
			AND o.order_estimated_delivery_date IS NOT NULL
			AND s.seller_state IS NOT NULL
	)
	SELECT
		seller_hub,
		COUNT(DISTINCT order_id) AS total_delivered_orders,
		COUNT(DISTINCT CASE
			WHEN order_delivered_customer_date > order_estimated_delivery_date
			THEN order_id
			END) AS delayed_orders,
		ROUND(
			100.0 * COUNT(DISTINCT CASE
				WHEN order_delivered_customer_date > order_estimated_delivery_date
				THEN order_id
			END) / NULLIF(COUNT(DISTINCT order_id), 0),
			2
		) AS hub_late_delivery_rate_pct,
		ROUND(AVG(seller_dispatch_exact_days)::NUMERIC, 2) AS avg_seller_dispatch_exact_days,
		ROUND(AVG(seller_dispatch_cal_days)::NUMERIC, 2) AS avg_seller_dispatch_cal_days,
		ROUND(AVG(carrier_transit_exact_days)::NUMERIC, 2) AS avg_carrier_transit_exact_days,
		ROUND(AVG(carrier_transit_cal_days)::NUMERIC, 2) AS avg_carrier_transit_cal_days,
		ROUND(AVG(seller_dispatch_exact_days + carrier_transit_exact_days)::NUMERIC, 2) AS avg_total_delivery_days
	FROM hub_orders
	GROUP BY seller_hub
	HAVING COUNT(DISTINCT order_id) >= 50
	ORDER BY total_delivered_orders DESC;
	