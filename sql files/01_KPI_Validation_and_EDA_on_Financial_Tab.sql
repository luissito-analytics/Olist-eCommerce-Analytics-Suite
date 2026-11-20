/*  =============================================================================================
	2.0: KPI VALIDATION & EXPLORATORY DATA ANALYSIS ON FINANCIAL SUMMARY AND PERFORMANCE TAB
	Database: Olist Brazilian E-Commerce Dataset
	Purpose: Conduct exploratory analysis and KPI calculations for the Financial Summary and 
			Performance of Olist E-Commerce.
	============================================================================================= 
    OUTLINE OF QUERIES:
		- 2.1: HEADLINE TRAJECTORIES ON YEAR-OVER-YEAR COMPARISONS 					(Line 31)
			- 2.1A: Year-over-Year (YoY) Delivered Revenue Growth Trajectory				
			- 2.1B: Year-over-Year (YoY) Delivered GMV Growth Trajectory					
			- 2.1C: Year-over-Year (YoY) Avg. Freight Value Growth Trajectory				
			- 2.1D: Year-over-Year (YoY) Freight-Price-Ratio Growth Trajectory				
			
		- 2.2: PAYMENT METHOD MIX AND SETTLEMENT FRICTION								(Line 151)
			- 2.2A: Payment Mix Volume Breakdown
			- 2.2B: Instant Cash Volume and Ratio
			- 2.2C: Boleto Bancário Payment Lag & Slip Expiration (Cancellation) Rate
			
		- 2.3: INSTALLMENT TIER AND EXPOSURE BREAKDOWN									(Line 225)
			- 2.3A: 4-Tier Installment Distribution
			- 2.3B: Average Installments
			
		- 2.4: CANCELLATION, LEAKAGE & PROMOTIONAL RECONCILIATION						(Line 324)
			- 2.4A: Year-over-Year (YoY) Cancelled GMV (Exclusively 'Canceled')
			- 2.4B: Year-over-Year (YoY) Financial Leakage Rate
			- 2.4C: Year-over-Year (YoY) Boleto Non-Payment Share
			- 2.4D: Year-over-Year (YoY) Voucher Spend and Discount Rate
			- 2.4E: Year-over-Year (YoY) Net Cash Realization Rate
		*/
	---------------------------------------------------------------------------------------------
/* 	2.1: HEADLINE TRAJECTORIES ON YEAR-OVER-YEAR COMPARISONS */
	---------------------------------------------------------------------------------------------
---	2.1A: Year-over-Year (YoY) Delivered Revenue Growth Trajectory
--- Gross Revenue (2018): R$8.45 Million (+22.11% YoY from 2017)
--- Scoped to order_status = 'delivered' at order level
	---------------------------------------------------------------------------------------------
	
	WITH annual_revenue AS (
		SELECT
			TO_CHAR(o.order_purchase_timestamp, 'YYYY') AS annual_period,
			COUNT(DISTINCT o.order_id) AS total_orders,
			ROUND(SUM(oi.price + oi.freight_value), 2) AS gross_revenue
		FROM fact_orders o
		JOIN fact_orderitems oi ON o.order_id = oi.order_id
		WHERE o.order_status = 'delivered'
			AND o.order_purchase_timestamp IS NOT NULL
		GROUP BY annual_period
	)
	SELECT
		annual_period,
		total_orders,
		gross_revenue,
		LAG(gross_revenue) OVER (ORDER BY annual_period) AS prior_year_revenue, 
		ROUND(
			100.0 * (gross_revenue - LAG(gross_revenue) OVER (ORDER BY annual_period)) /
			NULLIF(LAG(gross_revenue) OVER (ORDER BY annual_period), 0),
			2
		) AS YoY_growth_pct
	FROM annual_revenue
	ORDER BY annual_period;
	
	---------------------------------------------------------------------------------------------
---	2.1B: Year-over-Year (YoY) Delivered GMV Growth Trajectory
--- Gross Merchandise Value (2018): R$7.22 Million (+21.05% YoY from 2017)
--- Scoped to order_status = 'delivered' at order level
	---------------------------------------------------------------------------------------------

	WITH annual_gmv AS (
		SELECT
			TO_CHAR(o.order_purchase_timestamp, 'YYYY') AS annual_period,
			COUNT(DISTINCT o.order_id) AS total_orders,
			ROUND(SUM(oi.price), 2) AS gmv
		FROM fact_orders o
		JOIN fact_orderitems oi ON o.order_id = oi.order_id
		WHERE o.order_status = 'delivered'
			AND o.order_purchase_timestamp IS NOT NULL
		GROUP BY annual_period
	)
	SELECT
		annual_period,
		total_orders,
		gmv,
		LAG(gmv) OVER (ORDER BY annual_period) AS prior_year_gmv, 
		ROUND(
			100.0 * (gmv - LAG(gmv) OVER (ORDER BY annual_period)) /
			NULLIF(LAG(gmv) OVER (ORDER BY annual_period), 0),
			2
		) AS YoY_growth_pct
	FROM annual_gmv
	ORDER BY annual_period;
	
	---------------------------------------------------------------------------------------------	
---	2.1C: Year-over-Year (YoY) Avg. Freight Value Growth Trajectory
--- Avg. Freight Value (2018): R$20.48 per order (+5.57% YoY from 2017)
--- Scoped to all orders given purchase timestamp is not null at order level.
	---------------------------------------------------------------------------------------------
	
	WITH annual_freight AS (
		SELECT
			TO_CHAR(o.order_purchase_timestamp, 'YYYY') AS annual_period,
			COUNT(DISTINCT o.order_id) AS total_orders,
			ROUND(AVG(oi.freight_value), 2) AS avg_freight_value
			FROM fact_orders o
			JOIN fact_orderitems oi ON o.order_id = oi.order_id
			WHERE o.order_purchase_timestamp IS NOT NULL
			GROUP BY annual_period
	)
	SELECT
		annual_period,
		total_orders,
		avg_freight_value,
		LAG(avg_freight_value) OVER (ORDER BY annual_period) AS prior_year_freight,
		ROUND(
			100.0 * (avg_freight_value - LAG(avg_freight_value) OVER (ORDER BY annual_period)) /
			NULLIF(LAG(avg_freight_value) OVER (ORDER BY annual_period), 0),
			2
		) AS YoY_growth_pct
	FROM annual_freight
	ORDER BY annual_period;
	
	---------------------------------------------------------------------------------------------
---	2.1D: Year-over-Year (YoY) Freight-Price-Ratio Growth Trajectory
--- Freight-Price-Ratio (FPR in 2018): 17.03% (+6.24% Relative YoY from 2017)
--- Scoped to all orders given purchase timestamp is not null at order level.
	---------------------------------------------------------------------------------------------
	
	WITH annual_fpr AS (
		SELECT
			TO_CHAR(o.order_purchase_timestamp, 'YYYY') AS annual_period,
			COUNT(DISTINCT o.order_id) AS total_orders,
			ROUND(100.0 * SUM(oi.freight_value) / NULLIF(SUM(oi.price), 0), 2) AS freight_price_ratio_pct
			FROM fact_orders o
			JOIN fact_orderitems oi ON o.order_id = oi.order_id
			WHERE o.order_purchase_timestamp IS NOT NULL
			GROUP BY annual_period
	)
	SELECT
		annual_period,
		total_orders,
		freight_price_ratio_pct,
		LAG(freight_price_ratio_pct) OVER (ORDER BY annual_period) AS prior_year_fpr,
		ROUND(
			100.0 * (freight_price_ratio_pct - LAG(freight_price_ratio_pct) OVER (ORDER BY annual_period)) /
			NULLIF(LAG(freight_price_ratio_pct) OVER (ORDER BY annual_period), 0),
			2
		) AS YoY_growth_pct
	FROM annual_fpr
	ORDER BY annual_period;
	
	---------------------------------------------------------------------------------------------
/* 	2.2: PAYMENT METHOD MIX AND SETTLEMENT FRICTION */
	---------------------------------------------------------------------------------------------
---	2.2A: Payment Mix Volume Breakdown
--- In 2018: Credit (78.81%), Boleto (16.82%), Voucher (2.36%), Debit (2.00%)
--- Scoped to payments excluding not_defined in 2018 at order level and payment value level.
	---------------------------------------------------------------------------------------------
	
	SELECT
		EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
		p.payment_type,
		COUNT(DISTINCT o.order_id) AS total_orders,
		ROUND(SUM(p.payment_value), 2) AS total_payment_value,
		ROUND(
			100.0 * COUNT(DISTINCT o.order_id) /
			NULLIF(SUM(COUNT(DISTINCT o.order_id)) OVER (PARTITION BY EXTRACT(YEAR FROM o.order_purchase_timestamp)), 0),
			2
		) AS order_volume_share_pct,
		ROUND(
			100.0 * SUM(p.payment_value) /
			NULLIF(SUM(SUM(p.payment_value)) OVER (PARTITION BY EXTRACT(YEAR FROM o.order_purchase_timestamp)),0),
			2
		) AS payment_value_share_pct
	FROM fact_orders o
	JOIN fact_orderpayments p ON o.order_id = p.order_id
	WHERE o.order_purchase_timestamp IS NOT NULL
		AND p.payment_type <> 'not_defined'
	GROUP BY order_year, p.payment_type
	ORDER BY order_year, total_payment_value DESC;

	---------------------------------------------------------------------------------------------
---	2.2B: Instant Cash Volume and Ratio
--- 2018 Instant Cash Volume: R$380.0K (4.37% Ratio)
--- Scoped to payment_type = voucher OR debit_card at order level
	---------------------------------------------------------------------------------------------
	
	SELECT
		EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
		ROUND(SUM(p.payment_value), 2) AS total_payment_value,
		ROUND(SUM(CASE WHEN p.payment_type = 'debit_card' OR p.payment_type = 'voucher' THEN p.payment_value ELSE 0 END), 2) AS instant_cash_volume,
		ROUND(
			100.0 * SUM(CASE WHEN p.payment_type = 'debit_card' OR p.payment_type = 'voucher' THEN p.payment_value ELSE 0 END) /
			NULLIF(SUM(p.payment_value), 0),
			2
		) AS instant_cash_ratio_pct
	FROM fact_orders o
	JOIN fact_orderpayments p ON o.order_id = p.order_id
	GROUP BY order_year
	ORDER BY order_year;

	---------------------------------------------------------------------------------------------
---	2.2C: Boleto Bancário Payment Lag & Slip Expiration (Cancellation) Rate
--- Boleto Settlement Lag (2018): 33.27 Hours (0.40% expiration rate)
--- Scoped to payment_type = boleto and order_status = canceled (excl. unavailable)
	---------------------------------------------------------------------------------------------

	SELECT
		EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
		COUNT(DISTINCT o.order_id) AS total_boleto_orders,
		ROUND(AVG(EXTRACT(EPOCH FROM (o.order_approved_at - o.order_purchase_timestamp)) / 3600.0) FILTER(
			WHERE o.order_approved_at IS NOT NULL
		)::NUMERIC,2) AS avg_approval_lag_hours,
		SUM(CASE WHEN o.order_status = 'canceled' THEN 1 ELSE 0 END) AS expired_canceled_orders,
		ROUND(
			100.0 * SUM(CASE WHEN o.order_status = 'canceled' THEN 1 ELSE 0 END) / 
			NULLIF(COUNT(DISTINCT o.order_id), 0),
			2
		) AS boleto_expiration_rate_pct
	FROM fact_orders o
	JOIN fact_orderpayments p ON o.order_id = p.order_id
	WHERE p.payment_type = 'boleto'
	GROUP BY order_year
	ORDER BY order_year;

	---------------------------------------------------------------------------------------------
/* 	2.3: INSTALLMENT TIER AND EXPOSURE BREAKDOWN */
	---------------------------------------------------------------------------------------------
---	2.3A: 4-Tier Installment Distribution
--- Installment Tier Breakdown in 2018: 1x (20.83%), 2-3x (25.54%), 4-6x (23.51%), 7-10+x (30.13%)
--- Scoped to all credit orders where purchase timestamp is not null, at order level
	---------------------------------------------------------------------------------------------
	
	WITH installment_tiers AS (
		SELECT
			EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
			o.order_id,
			p.payment_value,
			CASE
				WHEN p.payment_installments = 1 THEN '1x'
				WHEN p.payment_installments BETWEEN 2 AND 3 THEN '2-3x'
				WHEN p.payment_installments BETWEEN 4 AND 6 THEN '4-6x'
				ELSE '7-10+x'
			END AS installment_tier
		FROM fact_orders o
		JOIN fact_orderpayments p ON o.order_id = p.order_id
		WHERE p.payment_type = 'credit_card'
			AND o.order_purchase_timestamp IS NOT NULL
	)
	SELECT
		order_year,
		installment_tier,
		COUNT(DISTINCT order_id) AS total_orders,
		ROUND(SUM(payment_value), 2) AS total_payment_value,
		ROUND(AVG(payment_value), 2) AS avg_installment_ticket,
		ROUND(
			100.0 * SUM(payment_value) /
			NULLIF(SUM(SUM(payment_value)) OVER (PARTITION BY order_year), 0),
			2
		) AS annual_value_share_pct
	FROM installment_tiers
	GROUP BY order_year, installment_tier
	ORDER BY
		order_year,
		CASE installment_tier
			WHEN '1x' THEN 1
			WHEN '2-3x' THEN 2
			WHEN '4-6x' THEN 3
			WHEN '7-10+x' THEN 4
		END;
	
	---------------------------------------------------------------------------------------------
---	2.3B: Average Installments
--- Avg. Installments in 2018: 3.30 installments
--- Scoped to credit orders where installments and purchase timestamp are not null
	---------------------------------------------------------------------------------------------
	
	SELECT
		EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
		ROUND(AVG(payment_installments), 2) AS Avg_Installments
	FROM fact_orders o
	JOIN fact_orderpayments p ON o.order_id = p.order_id
	WHERE p.payment_type = 'credit_card'
		AND p.payment_installments IS NOT NULL
		AND o.order_purchase_timestamp IS NOT NULL
	GROUP BY order_year
	ORDER BY order_year;

	---------------------------------------------------------------------------------------------
---	2.3C: High-Risk Exposure Share (% of GMV in 7-10+ installment tier)
--- High-Risk Exposure in 2018: R$ 1.82 Million (25.16% of GMV)
--- Scoped to order_status = delivered at order level to reflect GMV scope
	---------------------------------------------------------------------------------------------

	WITH gmv AS (
		SELECT
			order_id,
			SUM(price) AS gmv
		FROM fact_orderitems
		GROUP BY order_id
	),
	high_risk_orders AS(
		SELECT DISTINCT order_id
		FROM fact_orderpayments
		WHERE payment_type = 'credit_card'
			AND payment_installments >= 7
	)
	SELECT
		EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
		ROUND(SUM(g.gmv), 2) AS total_gmv,
		ROUND(SUM(CASE WHEN hr.order_id IS NOT NULL THEN g.gmv ELSE 0 END), 2) AS high_risk_gmv,
		ROUND(
			100.0 * SUM(CASE WHEN hr.order_id IS NOT NULL THEN g.gmv ELSE 0 END) /
			NULLIF(SUM(g.gmv), 0),
			2
		) AS high_risk_exposure_pct
	FROM fact_orders o
	JOIN gmv g ON o.order_id = g.order_id
	LEFT JOIN high_risk_orders hr ON o.order_id = hr.order_id
	WHERE o.order_purchase_timestamp IS NOT NULL
		AND o.order_status = 'delivered'
	GROUP BY order_year
	ORDER BY order_year;
	
	---------------------------------------------------------------------------------------------
/* 	2.4: CANCELLATION, LEAKAGE & PROMOTIONAL RECONCILIATION */
	---------------------------------------------------------------------------------------------
---	2.4A: Year-over-Year (YoY) Cancelled GMV (Exclusively 'Canceled')
--- Cancelled GMV in 2018: R$47.3K (-5.17% YoY from 2017)
--- Scoped to order_status = canceled ONLY and purchase timestamp NOT NULL at order level
	---------------------------------------------------------------------------------------------
	WITH order_gmv AS (
		SELECT
			order_id,
			SUM(price) AS gmv
		FROM fact_orderitems
		GROUP BY order_id
	),
	annual_cancelled AS (
		SELECT
			EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
			ROUND(SUM(og.gmv), 2) AS cancelled_gmv
		FROM fact_orders o
		JOIN order_gmv og ON o.order_id = og.order_id
		WHERE o.order_purchase_timestamp IS NOT NULL
			AND o.order_status = 'canceled'
		GROUP BY order_year
	)
	SELECT
		order_year,
		cancelled_gmv,
		LAG(cancelled_gmv) OVER (ORDER BY order_year) AS prior_year_cancelled_gmv,
		ROUND(
			100.0 * (cancelled_gmv - LAG(cancelled_gmv) OVER (ORDER BY order_year)) /
			NULLIF(LAG(cancelled_gmv) OVER (ORDER BY order_year), 0),
			2
		) AS yoy_change_pct
	FROM annual_cancelled
	ORDER By order_year;

	---------------------------------------------------------------------------------------------
---	2.4B: Year-over-Year (YoY) Financial Leakage Rate
--- Financial Leakage in 2018: 0.61% (-0.16 difference YoY from 2017)
--- Scoped to order_status = canceled AND purchase timestamp NOT NULL at order level
	---------------------------------------------------------------------------------------------
	
	WITH order_gmv AS(
		SELECT
			order_id,
			SUM(price) AS gmv
		FROM fact_orderitems
		GROUP BY order_id
	),
	annual_leakage AS (
		SELECT
			EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
			ROUND(SUM(og.gmv), 2) AS total_placed_gmv,
			ROUND(SUM(CASE WHEN o.order_status = 'canceled' THEN og.gmv ELSE 0 END), 2) AS cancelled_gmv,
			ROUND(
				100.0 * SUM(CASE WHEN o.order_status = 'canceled' THEN og.gmv ELSE 0 END) /
				NULLIF(SUM(og.gmv), 0),
				2
			) AS financial_leakage_rate_pct
		FROM fact_orders o
		JOIN order_gmv og ON o.order_id = og.order_id
		WHERE o.order_purchase_timestamp IS NOT NULL
		GROUP BY order_year
	)
	SELECT
		order_year,
		total_placed_gmv,
		cancelled_gmv,
		financial_leakage_rate_pct,
		LAG(financial_leakage_rate_pct) OVER (ORDER BY order_year) AS prior_year_financial_leakage_pct,
		ROUND(
			financial_leakage_rate_pct - LAG(financial_leakage_rate_pct) OVER (ORDER BY order_year),
			2
		) AS yoy_diff_pp
	FROM annual_leakage
	ORDER BY order_year;

	---------------------------------------------------------------------------------------------
---	2.4C: Year-over-Year (YoY) Boleto Non-Payment Share
--- Boleto Non-Payment Share of GMV in 2018: 9.55% of GMV (-53.30% YoY from 2017)
--- Scoped to payment_type = boleto and order_status = canceled ONLY
	---------------------------------------------------------------------------------------------
	
	WITH order_gmv AS(
		SELECT
			order_id,
			SUM(price) AS gmv
		FROM fact_orderitems
		GROUP BY order_id
	),
	boleto_orders AS (
		SELECT DISTINCT
			order_id
		FROM fact_orderpayments
		WHERE payment_type = 'boleto'
	),
	annual_boleto_leakage AS (
		SELECT
			EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
			COUNT(DISTINCT CASE WHEN b.order_id IS NOT NULL THEN o.order_id END) AS cancelled_boleto_orders,
			COUNT(DISTINCT o.order_id) AS total_cancelled_orders,
			ROUND(
				100.0 * COUNT(DISTINCT CASE WHEN b.order_id IS NOT NULL THEN  o.order_id END) / 
				NULLIF(COUNT(DISTINCT o.order_id), 0),
				2
			) AS boleto_cancel_order_share_pct,
			ROUND(SUM(CASE WHEN b.order_id IS NOT NULL THEN COALESCE(og.gmv, 0) ELSE 0 END), 2) AS cancelled_boleto_gmv,
			ROUND(SUM(COALESCE(og.gmv, 0)), 2) AS total_cancelled_gmv,
			ROUND(
				100.0 * SUM(CASE WHEN b.order_id IS NOT NULL THEN COALESCE(og.gmv, 0) ELSE 0 END) /
				NULLIF(SUM(COALESCE(og.gmv, 0)), 0),
				2
			) AS boleto_cancel_gmv_share_pct
		FROM fact_orders o
		LEFT JOIN order_gmv og ON o.order_id = og.order_id
		LEFT JOIN boleto_orders b ON o.order_id = b.order_id
		WHERE o.order_purchase_timestamp IS NOT NULL
			AND o.order_status = 'canceled'
		GROUP BY order_year
	)
	SELECT
		order_year,
		cancelled_boleto_orders,
		total_cancelled_orders,
		boleto_cancel_order_share_pct,
		ROUND(
			100.0 * (boleto_cancel_order_share_pct - LAG(boleto_cancel_order_share_pct) OVER (ORDER BY order_year)) /
			NULLIF(LAG(boleto_cancel_order_share_pct) OVER (ORDER BY order_year), 0),
			2
		) AS order_share_yoy_rel_pct,
		boleto_cancel_gmv_share_pct,
		ROUND(
			100.0 * (boleto_cancel_gmv_share_pct - LAG(boleto_cancel_gmv_share_pct) OVER (ORDER BY order_year)) /
			NULLIF(LAG(boleto_cancel_gmv_share_pct) OVER (ORDER BY order_year), 0),
			2
		) AS gmv_share_yoy_rel_pct
	FROM annual_boleto_leakage
	ORDER BY order_year;

	---------------------------------------------------------------------------------------------
--- 2.4D: Year-over-Year (YoY) Voucher Spend and Discount Rate
--- Voucher Spend and Discount Rate in 2018: R$177.6K at 2.46% (-10.87% relative YoY from 2017)
--- Scoped to order_status = delivered and purchase timestamp NOT NULL
	---------------------------------------------------------------------------------------------
	
	WITH order_gmv AS (
		SELECT
			order_id,
			SUM(price) AS gmv
		FROM fact_orderitems
		GROUP BY order_id
	),
	order_vouchers AS (
		SELECT
			order_id,
			SUM(payment_value) AS voucher_value
		FROM fact_orderpayments
		WHERE payment_type = 'voucher'
		GROUP BY order_id
	),
	annual_vouchers AS (
		SELECT
			EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
			ROUND(SUM(og.gmv), 2) AS total_gmv,
			ROUND(SUM(COALESCE(ov.voucher_value, 0)), 2) AS total_voucher_spend,
			ROUND(
				100.0 * SUM(COALESCE(ov.voucher_value, 0)) /
				NULLIF(SUM(og.gmv), 0),
				2
			) AS voucher_share_pct
		FROM fact_orders o
		JOIN order_gmv og ON o.order_id = og.order_id
		LEFT JOIN order_vouchers ov ON o.order_id = ov.order_id
		WHERE o.order_purchase_timestamp IS NOT NULL
			AND o.order_status = 'delivered'
		GROUP BY order_year
	)
	SELECT
		order_year,
		total_gmv,
		total_voucher_spend,
		voucher_share_pct,
		ROUND(
			100.0 * (voucher_share_pct - LAG(voucher_share_pct) OVER (ORDER BY order_year)) /
			NULLIF(LAG(voucher_share_pct) OVER (ORDER BY order_year), 0),
			2
		) AS yoy_relative_change_pct,
		ROUND(
			100.0 * (total_voucher_spend - LAG(total_voucher_spend) OVER (ORDER BY order_year)) /
			NULLIF(LAG(total_voucher_spend) OVER (ORDER BY order_year), 0),
			2
		) AS yoy_voucher_spend_change_pct
	FROM annual_vouchers
	ORDER BY order_year;

	---------------------------------------------------------------------------------------------
---	2.4E: Year-over-Year (YoY) Net Cash Realization Rate
--- Net Cash Realization in 2018: R$8.28M out of 8.45M collected ~ 97.91% realization rate (+0.28 YoY)
--- Scoped to order_status = delivered and purchase timestamp NOT NULL
	---------------------------------------------------------------------------------------------

	WITH order_items_agg AS (
		SELECT
			order_id,
			SUM(price + freight_value) AS order_gross_revenue
		FROM fact_orderitems
		GROUP BY order_id
	),
	order_payments_agg AS (
		SELECT
			order_id,
			SUM(CASE WHEN payment_type <> 'voucher' THEN payment_value ELSE 0 END) AS non_voucher_payment
		FROM fact_orderpayments
		GROUP BY order_id
	),
	annual_realization AS (
		SELECT
			EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
			ROUND(SUM(oi.order_gross_revenue), 2) AS total_delivered_revenue,
			ROUND(SUM(COALESCE(op.non_voucher_payment, 0)), 2) AS total_net_cash_collected,
			ROUND(
				100.0 * SUM(COALESCE(op.non_voucher_payment, 0)) /
				NULLIF(SUM(oi.order_gross_revenue), 0),
				2
			) AS net_cash_realization_rate_pct
		FROM fact_orders o
		JOIN order_items_agg oi ON o.order_id = oi.order_id
		LEFT JOIN order_payments_agg op ON o.order_id = op.order_id
		WHERE o.order_status = 'delivered'
			AND o.order_purchase_timestamp IS NOT NULL
		GROUP BY order_year
	)
	SELECT
		order_year,
		total_delivered_revenue,
		total_net_cash_collected,
		net_cash_realization_rate_pct,
		LAG(net_cash_realization_rate_pct) OVER (ORDER BY order_year) AS prior_year_rate_pct,
		ROUND(
			net_cash_realization_rate_pct - LAG(net_cash_realization_rate_pct) OVER (ORDER BY order_year),
			2
		) AS yoy_diff_pp,
		ROUND(
			100.0 * (net_cash_realization_rate_pct - LAG(net_cash_realization_rate_pct) OVER (ORDER BY order_year)) /
			NULLIF(LAG(net_cash_realization_rate_pct) OVER (ORDER BY order_year), 0),
			2
		) AS yoy_relative_change_pct
	FROM annual_realization
	ORDER BY order_year;
	