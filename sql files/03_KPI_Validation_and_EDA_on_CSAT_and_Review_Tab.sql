/*  =============================================================================================
	4.0: KPI VALIDATION & EXPLORATORY DATA ANALYSIS ON CUSTOMER SATISFACTION AND REVIEW PERFORMANCE TAB
	Database: Olist Brazilian E-Commerce Dataset
	Purpose: Conduct exploratory analysis and KPI calculations on the CSAT and Reveiw Performance
	=============================================================================================
      OUTLINE OF QUERIES:
		- 4.1: CUSTOMER SENTIMENT HEADLINE KPIs AND TRAJECTORY (WITH YoY COMPARISONS)	(Line 32)
			- 4.1A: Year-over-Year (YoY) Average Review Score
			- 4.1B: Year-over-Year (YoY) Review Response Rate
			- 4.1C: Year-over-Year (YoY) Average Order Value
			- 4.1D: Year-over-Year (YoY) Freight Burden Share
			- 4.1E: Trajectory of CSAT / 1-Star Friction %
			
		- 4.2: CUSTOMER RETENTION & RFM COHORT BREAKDOWN								(Line 182)
			- 4.2A: Year-over-Year (YoY) Active Customer Volume
			- 4.2B: Year-over-Year (YoY) Repeat Purchase Rate
			- 4.2C: RFM Segment Distribution in 2018
			
		- 4.3: CSAT DISTRIBUTION & DELIVERY DELAY IMPACT								(Line 301)
			- 4.3A: 1-Star to 5-Star Review Distribution in 2018
			- 4.3B: CSAT by Delivery Delay Bucket in 2018

		- 4.4: PRODUCT & REGIONAL CSAT OUTLIERS										(Line 364)
			- 4.4A: Top 5 / Bottom 5 Product Categories by Avg. CSAT in 2018
			- 4.4B: Top / Bottom States by CSAT in 2018

		- 4.5: CSAT PAYMENT PERFORMANCE SUMMARY										(Line 428)
			- 4.5A: Payment Type Performance by Avg. CSAT in 2018
			- 4.5B: Installment Tiers Breakdown Performance by CSAT in 2018
		*/
	---------------------------------------------------------------------------------------------
/*	4.1: CUSTOMER SENTIMENT HEADLINE KPIs AND TRAJECTORY (WITH YoY COMPARISONS) */
	---------------------------------------------------------------------------------------------
---	4.1A: Year-over-Year (YoY) Average Review Score
--- Avg. Review Score in 2018: 4.09 rating (+0.08% YoY from 2017)
--- Scoped to orders where review_score and purchase_timestamp NOT NULL at order level
	---------------------------------------------------------------------------------------------
	
	WITH order_reviews_deduplicated AS (
		SELECT
			o.order_id, 
			EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
			AVG(r.review_score) AS order_review_score
		FROM fact_orders o
		JOIN fact_orderreviews r ON o.order_id = r.order_id
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) IN (2017, 2018)
			AND o.order_purchase_timestamp IS NOT NULL
			AND r.review_score IS NOT NULL
		GROUP BY o.order_id, EXTRACT(YEAR FROM o.order_purchase_timestamp)
	)
	SELECT
		ROUND(AVG(CASE WHEN order_year = 2018 THEN order_review_score END)::NUMERIC, 2) AS avg_score_2018,
		ROUND(AVG(CASE WHEN order_year = 2017 THEN order_review_score END)::NUMERIC, 2) AS avg_score_2017,
		ROUND(
			(AVG(CASE WHEN order_year = 2018 THEN order_review_score END)
			 - AVG(CASE WHEN order_year = 2017 THEN order_review_score END))::NUMERIC,
			 2
		) AS yoy_score_diff,
		ROUND(
			100.0 * (
				AVG(CASE WHEN order_year = 2018 THEN order_review_score END)
				- AVG(CASE WHEN order_year = 2017 THEN order_review_score END)
			) / NULLIF(AVG(CASE WHEN order_year = 2017 THEN order_review_score END), 0),
			2
		) AS yoy_pct_change
	FROM order_reviews_deduplicated;

	---------------------------------------------------------------------------------------------
---	4.1B: Year-over-Year (YoY) Review Response Rate
--- Review Response Rate in 2018: 98.84% (+0.43% YoY from 2017)
--- Scoped to review_id NOT NULL at order_level
	---------------------------------------------------------------------------------------------
	
	WITH order_review_flags AS (
		SELECT
			o.order_id,
			EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
			MAX(CASE WHEN r.review_id IS NOT NULL THEN 1 ELSE 0 END) AS has_review
		FROM fact_orders o
		LEFT JOIN fact_orderreviews r ON o.order_id = r.order_id
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) IN (2017, 2018)
			AND o.order_purchase_timestamp IS NOT NULL
		GROUP BY o.order_id, EXTRACT(YEAR FROM o.order_purchase_timestamp)
	),
	annual_rates AS (
		SELECT
			100.0 * SUM(CASE WHEN order_year = 2018 THEN has_review ELSE 0 END)
				/ NULLIF(COUNT(CASE WHEN order_year = 2018 THEN order_id END), 0) AS rate_2018,
			100.0 * SUM(CASE WHEN order_year = 2017 THEN has_review ELSE 0 END)
				/ NULLIF(COUNT(CASE WHEN order_year = 2017 THEN order_id END), 0) AS rate_2017
		FROM order_review_flags
	)
	SELECT
		ROUND(rate_2018::NUMERIC, 2) AS review_response_rate_2018_pct,
		ROUND(rate_2017::NUMERIC, 2) AS review_response_rate_2017_pct,
		ROUND((rate_2018 - rate_2017)::NUMERIC, 2) AS yoy_pp_diff,
		ROUND((100.0 * (rate_2018 - rate_2017) /NULLIF(rate_2017, 0))::NUMERIC, 2) AS yoy_relative_pct_change
	FROM annual_rates

	---------------------------------------------------------------------------------------------
---	4.1C: Year-over-Year (YoY) Average Order Value
--- Average Order Value (AOV) in 2018: R$160.74 (+0.32% YoY from 2017)
--- Scoped to purchase timestamp NOT NULL at order level
	---------------------------------------------------------------------------------------------
	
	WITH order_values AS (
		SELECT
			o.order_id,
			EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
			SUM(oi.price + oi.freight_value) AS total_order_value
		FROM fact_orders o
		JOIN fact_orderitems oi ON o.order_id = oi.order_id
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) IN (2017, 2018)
			AND o.order_purchase_timestamp IS NOT NULL
		GROUP BY o.order_id, EXTRACT(YEAR FROM o.order_purchase_timestamp)
	),
	annual_aov AS (
		SELECT
			AVG(CASE WHEN order_year = 2018 THEN total_order_value END) AS aov_2018,
			AVG(CASE WHEN order_year = 2017 THEN total_order_value END) AS aov_2017
		FROM order_values
	)
	SELECT
		ROUND(aov_2018::NUMERIC, 2) AS aov_2018,
		ROUND(aov_2017::NUMERIC, 2) AS aov_2017,
		ROUND((100.0 * (aov_2018 - aov_2017) / NULLIF(aov_2017, 0))::NUMERIC, 2) AS yoy_aov_pct
	FROM annual_aov;

	---------------------------------------------------------------------------------------------
---	4.1D: Year-over-Year (YoY) Freight Burden Share
--- Freight Burden Share in 2018: 14.55% (+5.31% YoY from 2017)
--- Scoped to purchase timestamp NOT NULL at order level)
	---------------------------------------------------------------------------------------------
	
	WITH annual_freight AS (
		SELECT
			SUM(CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018 THEN oi.freight_value END)
				/ NULLIF(SUM(CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018 THEN oi.price + oi.freight_value END), 0) AS share_2018_pct,
			SUM(CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017 THEN oi.freight_value END)
				/ NULLIF(SUM(CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017 THEN oi.price + oi.freight_value END), 0) AS share_2017_pct
		FROM fact_orders o
		JOIN fact_orderitems oi ON o.order_id = oi.order_id
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) IN (2017, 2018)
			AND o.order_purchase_timestamp IS NOT NULL
	)
	SELECT
		ROUND((100.0 * share_2018_pct)::NUMERIC, 2) AS freight_buden_share_2018,
		ROUND((100.0 * share_2017_pct)::NUMERIC, 2) AS freight_burden_share_2017,
		ROUND((100.0 * (share_2018_pct - share_2017_pct))::NUMERIC, 2) AS yoy_pp_diff,
		ROUND((100.0 * (share_2018_pct - share_2017_pct) / NULLIF(share_2017_pct, 0))::NUMERIC, 2) AS yoy_relative_pct_change
	FROM annual_freight;

	---------------------------------------------------------------------------------------------
---	4.1E: Trajectory of CSAT / 1-Star Friction %
--- Highest Recorded 1-Star Friction % in 2018: Feb to March (15.51% to 17.47% Friction)
--- Scoped to order_status = delivered AND review_score NOT NULL at order level
	---------------------------------------------------------------------------------------------
	
	SELECT
		EXTRACT(MONTH FROM o.order_purchase_timestamp)::INT AS order_month,
		TO_CHAR(o.order_purchase_timestamp, 'Mon') AS month_label,
		COUNT(DISTINCT r.review_id) AS total_reviews,
		COUNT(DISTINCT CASE WHEN r.review_score = 1 THEN r.review_id END) AS one_star_reviews,
		ROUND(
			100.0 * COUNT(DISTINCT CASE WHEN r.review_score = 1 THEN r.review_id END)
			/ COUNT(DISTINCT r.review_id),
			2
		) AS friction_rate_pct,
		ROUND(AVG(r.review_score::NUMERIC), 2) AS avg_csat
	FROM fact_orders o
	JOIN fact_orderreviews r ON o.order_id = r.order_id
	WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
		AND o.order_purchase_timestamp IS NOT NULL
		AND r.review_score IS NOT NULL
		AND o.order_status = 'delivered'
	GROUP BY
		EXTRACT(MONTH FROM o.order_purchase_timestamp)::INT,
		TO_CHAR(o.order_purchase_timestamp, 'Mon')
	ORDER BY order_month;

	---------------------------------------------------------------------------------------------
/*	4.2: CUSTOMER RETENTION & RFM COHORT BREAKDOWN */
	---------------------------------------------------------------------------------------------
---	4.2A: Year-over-Year (YoY) Active Customer Volume
--- Active Customer Volume in 2018: 52,749 active customers (+20.67% YoY from 2017)
--- Scoped to purchase timestamp NOT NULL within year at Customer Unique ID level
	---------------------------------------------------------------------------------------------
	WITH annual_customers AS (
		SELECT
			COUNT(DISTINCT CASE
				WHEN EXTRACT(YEAR FROM order_purchase_timestamp) = 2018
				THEN customer_unique_id
			END) AS active_customers_2018,
			COUNT(DISTINCT CASE
				WHEN EXTRACT(YEAR FROM order_purchase_timestamp) = 2017
				THEN customer_unique_id
			END) AS active_customers_2017
		FROM fact_orders 
		WHERE EXTRACT(YEAR FROM order_purchase_timestamp) IN (2017, 2018)
			AND order_purchase_timestamp IS NOT NULL
	)
	SELECT
		active_customers_2018,
		active_customers_2017,
		(active_customers_2018 - active_customers_2017) AS yoy_customer_diff,
		ROUND(
			100.0 * (active_customers_2018 - active_customers_2017) / NULLIF(active_customers_2017, 0),
			2
		) AS yoy_relative_pct_change
	FROM annual_customers;
	
	---------------------------------------------------------------------------------------------
---	4.2B: Year-over-Year (YoY) Repeat Purchase Rate
--- Repeat Purchase Rate in 2018: 2.21% (-23.00% YoY from 2017)
--- Scoped order_count > 1 within year period AND purchase timestamp and customer unique id NOT NULL at customer unique id level
	---------------------------------------------------------------------------------------------
	
	WITH customer_annual_orders AS (
		SELECT
			customer_unique_id,
			EXTRACT(YEAR FROM order_purchase_timestamp) AS order_year,
			COUNT(DISTINCT order_id) AS order_count
		FROM fact_orders
		WHERE EXTRACT(YEAR FROM order_purchase_timestamp) IN (2017,2018)
			AND order_purchase_timestamp IS NOT NULL
			AND customer_unique_id IS NOT NULL
		GROUP BY customer_unique_id, EXTRACT(YEAR FROM  order_purchase_timestamp)
	),
	annual_repeat_rates AS (
		SELECT 
			100.0 * COUNT(DISTINCT CASE WHEN order_year = 2018 AND order_count > 1 THEN customer_unique_id END)
				/ NULLIF(COUNT(DISTINCT CASE WHEN order_year= 2018 THEN customer_unique_id END), 0) AS repeat_rate_2018,
			100.0 * COUNT(DISTINCT CASE WHEN order_year = 2017 AND order_count > 1 THEN customer_unique_id END)
				/ NULLIF(COUNT(DISTINCT CASE WHEN order_year= 2017 THEN customer_unique_id END), 0) AS repeat_rate_2017
		FROM customer_annual_orders
	)
	SELECT
		ROUND(repeat_rate_2018::NUMERIC, 2) AS repeat_purchase_rate_2018_pct,
		ROUND(repeat_rate_2017::NUMERIC, 2) AS repeat_purchase_rate_2017_pct,
		ROUND((repeat_rate_2018 - repeat_rate_2017)::NUMERIC, 2) AS yoy_pp_diff,
		ROUND((100.0 * (repeat_rate_2018 - repeat_rate_2017) / NULLIF(repeat_rate_2017, 0))::NUMERIC, 2) AS yoy_relative_pct_change
	FROM annual_repeat_rates;

	---------------------------------------------------------------------------------------------
---	4.2C: RFM Segment Distribution in 2018
--- RFM Segments in 2018: Champions & VIPS (0.75%), Loyal Repeat Customers (1.39%), High-Value Single Buyers (5.40%)
--- 	Lapsed/At-Risk Buyers (46.19%), Recent Standard Buyers (46.27%)
--- Scoped to order frequency within year, timestamp and customer unique id NOT NULL at order level
	---------------------------------------------------------------------------------------------
	
	WITH dataset_anchor AS (
		SELECT MAX(order_purchase_timestamp) AS max_date
		FROM fact_orders
		WHERE EXTRACT(YEAR FROM order_purchase_timestamp) = 2018
			AND order_purchase_timestamp IS NOT NULL
	),
	order_totals AS (
		SELECT
			o.order_id,
			o.customer_unique_id,
			o.order_purchase_timestamp,
			SUM(oi.price + oi.freight_value) AS order_spend
		FROM fact_orders o
		JOIN fact_orderitems oi ON o.order_id = oi.order_id
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
			AND o.order_purchase_timestamp IS NOT NULL
			AND o.customer_unique_id IS NOT NULL
		GROUP BY o.order_id, o.customer_unique_id, o.order_purchase_timestamp
	),
	customer_rfm AS (
		SELECT
			ot.customer_unique_id,
			(da.max_date::DATE - MAX(ot.order_purchase_timestamp)::DATE) AS recency_days,
			COUNT(DISTINCT ot.order_id) AS order_frequency,
			SUM(ot.order_spend) AS monetary_spend
		FROM order_totals ot
		CROSS JOIN dataset_anchor da
		GROUP BY ot.customer_unique_id, da.max_date
	),
	segmented_customers AS (
		SELECT
			customer_unique_id,
			CASE
				WHEN order_frequency >= 2 AND ROUND(monetary_spend::NUMERIC, 2) >= 300.00 THEN 'Champions & VIPs'
				WHEN order_frequency >= 2 THEN 'Loyal Repeat Customers'
				WHEN recency_days <= 180 AND ROUND(monetary_spend::NUMERIC, 2) >= 300.00 THEN 'High-Value Single Buyers'
				WHEN recency_days <= 180 THEN 'Recent Standard Buyers'
				ELSE 'Lapsed / At-Risk Buyers'
			END AS rfm_segment
		FROM customer_rfm
	)
	SELECT
		rfm_segment,
		COUNT(customer_unique_id) AS customer_count,
		ROUND(100.0 * COUNT(customer_unique_id) / SUM(COUNT(customer_unique_id)) OVER (), 2) AS pct_of_customers
	FROM segmented_customers
	GROUP BY rfm_segment
	ORDER BY customer_count DESC;

	---------------------------------------------------------------------------------------------
/*	4.3: CSAT DISTRIBUTION & DELIVERY DELAY IMPACT */
	---------------------------------------------------------------------------------------------
---	4.3A: 1-Star to 5-Star Review Distribution in 2018
--- Review Score Distribution in 2018: 5-star (58.27%), 4-star (18.96%), 3-star (8.07%), 2-star (3.09%), 1-star (11.61%)
--- Scoped to timestamp = 2018 and Not Null, Review score not null at review level
	---------------------------------------------------------------------------------------------
	
	WITH annual_reviews AS (
		SELECT
			r.review_score,
			Count(r.review_id) AS score_count,
			SUM(COUNT(r.review_id)) OVER() AS total_reviews_2018
		FROM fact_orders o
		JOIN fact_orderreviews r ON o.order_id = r.order_id
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
			AND o.order_purchase_timestamp IS NOT NULL
			AND r.review_score IS NOT NULL
		GROUP BY r.review_score
	)
	SELECT
		review_score,
		score_count,
		total_reviews_2018,
		ROUND(100.0 * score_count / total_reviews_2018, 2) AS csat_share_pct
	FROM annual_reviews
	ORDER BY review_score DESC;

	---------------------------------------------------------------------------------------------
---	4.3B: CSAT by Delivery Delay Bucket in 2018
--- CSAT distributed by delivery delay bucket in 2018: 29,930 on-time/early orders rated 5-stars
--- 	compared to 1,211 orders rated 1-star after 8+ days late
--- Scoped to order_status = delivered and review score IS NOT NULL
	---------------------------------------------------------------------------------------------
	
	WITH order_delays AS (
		SELECT
			r.review_score,
			o.order_estimated_delivery_date,
			o.order_delivered_customer_date,
			CASE
				WHEN o.order_delivered_customer_date IS NULL THEN 'Not Delivered'
				WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 'On Time / Early'
				WHEN (o.order_delivered_customer_date::DATE - o.order_estimated_delivery_date::DATE) <= 3 THEN '1-3 Days Late'
				WHEN (o.order_delivered_customer_date::DATE - o.order_estimated_delivery_date::DATE) <= 7 THEN '4-7 Days Late'
				ELSE '8+ Days Late'
			END AS delivery_delay_bucket,
			o.order_id
		FROM fact_orders o
		JOIN fact_orderreviews r ON o.order_id = r.order_id
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
			AND o.order_status = 'delivered'
			AND o.order_purchase_timestamp IS NOT NULL
			AND r.review_score IS NOT NULL
	)
	SELECT
		review_score,
		delivery_delay_bucket,
		COUNT(DISTINCT order_id) AS order_count
	FROM order_delays
	GROUP BY review_score, delivery_delay_bucket
	ORDER BY review_score DESC, delivery_delay_bucket;

	---------------------------------------------------------------------------------------------
/*	4.4: PRODUCT & REGIONAL CSAT OUTLIERS */
	---------------------------------------------------------------------------------------------
---	4.4A: Top 5 / Bottom 5 Product Categories by Avg. CSAT in 2018
--- Scoped to order_status = delivered and Review Score NOT NULL
	---------------------------------------------------------------------------------------------
	
	WITH order_categories AS (
		SELECT DISTINCT
			oi.order_id,
			COALESCE(p.product_category_name, 'Unknown') AS product_category_name
		FROM fact_orderitems oi
		JOIN dim_products p ON oi.product_id = p.product_id
	),
	product_csat AS(
		SELECT
			oc.product_category_name,
			AVG(r.review_score::NUMERIC) AS avg_csat,
			COUNT(r.review_id) AS total_reviews,
			SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) AS one_star_reviews
		FROM fact_orders o
		JOIN order_categories oc ON o.order_id = oc.order_id
		JOIN fact_orderreviews r ON o.order_id = r.order_id
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
			AND o.order_status = 'delivered'
			AND o.order_purchase_timestamp IS NOT NULL
			AND r.review_score IS NOT NULL
		GROUP BY oc.product_category_name
	)
	SELECT
		product_category_name,
		ROUND(avg_csat, 2) AS avg_csat,
		ROUND(100.0 * one_star_reviews / total_reviews, 2) AS friction_rate_pct,
		total_reviews
	FROM product_csat
	ORDER BY avg_csat DESC;
	
	---------------------------------------------------------------------------------------------
---	4.4B: Top / Bottom States by CSAT in 2018
--- Top States by CSAT in 2018: SP (4.25), PR (4.23), MT (4.22), RN (4.19), AC (4.19)
--- Bottom States by CSAT in 2018: PA (3.79), MA (3.82), CE (3.82), AL (3.85), RR (3.86)
--- Scoped to order_status = delivered, and review score IS NOT NULL
	---------------------------------------------------------------------------------------------
	
	WITH customer_states AS (
		SELECT DISTINCT
			customer_unique_id,
			customer_state
		FROM dim_customers
	)
	SELECT
		c.customer_state,
		ROUND(AVG(r.review_score::NUMERIC), 2) AS avg_csat,
		COUNT(DISTINCT o.order_id) AS total_orders
	FROM fact_orders o
	JOIN customer_states c ON o.customer_unique_id = c.customer_unique_id
	JOIN fact_orderreviews r ON o.order_id = r.order_id
	WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
		AND o.order_status = 'delivered'
		AND o.order_purchase_timestamp IS NOT NULL
		AND r.review_score IS NOT NULL
	GROUP BY c.customer_state
	ORDER BY avg_csat DESC;

	---------------------------------------------------------------------------------------------
/*	4.5: CSAT PAYMENT PERFORMANCE SUMMARY */
	---------------------------------------------------------------------------------------------
---	4.5A: Payment Type Performance by Avg. CSAT in 2018
--- Payment Type Performance in 2018: Debit (4.27 with R$154.34 AOV)
--- Boleto (4.15 with R$143.26 AOV)
--- Credit (4.14 with R$163.10 AOV)
--- Voucher (4.11 with R$ 97.60 AOV)
--- Scoped to order_status = delivered, payment_type excluding not_defined and review score NOT NULL
	---------------------------------------------------------------------------------------------
	
	WITH order_payment_summary AS (
		SELECT
			o.order_id,
			op.payment_type,
			SUM(op.payment_value) AS total_payment_value
		FROM fact_orders o
		JOIN fact_orderpayments op ON o.order_id = op.order_id
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
			AND o.order_purchase_timestamp IS NOT NULL
			AND op.payment_type <> 'not_defined'
			AND o.order_status = 'delivered'
		GROUP BY o.order_id, op.payment_type
	),
	order_reviews AS (
		SELECT
			order_id,
			AVG(review_score::NUMERIC) AS avg_review_score,
			COUNT(review_id) AS review_count,
			SUM(review_score) AS sum_review_score
		FROM fact_orderreviews
		WHERE review_score IS NOT NULL
		GROUP BY order_id
	)
	SELECT
		ops.payment_type,
		COUNT(DISTINCT ops.order_id) AS total_orders,
		ROUND(SUM(ops.total_payment_value)::NUMERIC / COUNT(DISTINCT ops.order_id), 2) AS avg_order_value,
		ROUND(SUM(r.sum_review_score)::NUMERIC / SUM(r.review_count), 2) AS avg_csat
	FROM order_payment_summary ops
	LEFT JOIN order_reviews r ON ops.order_id = r.order_id
	GROUP BY ops.payment_type
	ORDER BY avg_csat DESC;
	---------------------------------------------------------------------------------------------
---	4.5B: Installment Tiers Breakdown Performance by CSAT in 2018
--- Scoped to order_status = delivered, order installments >= 1 and review score IS NOT NULL
	---------------------------------------------------------------------------------------------
	
	WITH order_installment_tiers AS (
		SELECT DISTINCT
			o.order_id,
			CASE
				WHEN op.payment_installments = 1 THEN '1x (Immediate)'
				WHEN op.payment_installments BETWEEN 2 AND 3 THEN '2-3x (Short Term)'
				WHEN op.payment_installments BETWEEN 4 AND 6 THEN '4-6x (Medium Term)'
				WHEN op.payment_installments >= 7 THEN '7-10+x (Long Term)'
			END AS installment_bracket
		FROM fact_orders o
		JOIN fact_orderpayments op ON o.order_id = op.order_id
		WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
			AND o.order_status = 'delivered'
			AND o.order_purchase_timestamp IS NOT NULL
			AND op.payment_installments >= 1
	),
	tier_review_counts AS (
		SELECT
			oit.installment_bracket,
			r.review_score,
			COUNT(DISTINCT oit.order_id) AS order_count
		FROM order_installment_tiers oit
		JOIN fact_orderreviews r ON oit.order_id = r.order_id
		WHERE r.review_score IS NOT NULL
		GROUP BY oit.installment_bracket, r.review_score
	)
	SELECT
		installment_bracket,
		review_score,
		order_count,
		ROUND(
			100.0 * order_count / SUM(order_count) OVER (PARTITION BY installment_bracket),
			2
		) AS pct_of_tier
	FROM tier_review_counts
	ORDER BY
		CASE installment_bracket
			WHEN '1x (Immediate)' THEN 1
			WHEN '2-3x (Short Term)' THEN 2
			WHEN '4-6x (Medium Term)' THEN 3
			WHEN '7-10+x (Long Term)' THEN 4
		END,
		review_score DESC;
