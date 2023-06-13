-- select @@global.sql_mode;
-- set @@global.sql_mode := replace(@@global.sql_mode,'ONLY_FULL_GROUP_BY','');

/*
SQL & TABLEAU PORTFOLIO PROJECT
SQL skills: JOINs, Aggregate Functions, Temporary Tables, Subqueries

SUMMARY:
This project is based on a database of toy e-commerce retailer company. It will consist of two basic blocks. 
The first is the SQL code used to aggregate and extract results from the database in the form of csv files. 
These files will then be used to create a dashboard in Tableau. To fully understand this project, it is recommended to know both blocks.

MAIN GOALS:
1. performing queries which we are then later to use for data visualizations in Tableau 
2. to measure and test website performance - A/B Testing of bounce rate
3. creating a conversion funnel to identify weak points in the purchasing process
*/


/*SECTION I*/

/*
1. Traffic Source Analysis
There are several main channels through which customers reach the site. 
In general we can split them into two main categories: paid and non - paid traffic.
All sources and campaigns with UTM tracking parameters are paid marketing. These are for example gsearch and bsearch (in this database)
There is also a possibility that as the popularity of the brand increases, customers search directly for website - direct type in search.
The last type of website traffic is organic search, which is not directly related to paid marketing.
*/

-- Checking the sources of traffic on the website
SELECT DISTINCT
    utm_source,
    utm_campaign,
    http_referer,
    CASE 
		WHEN http_referer IS NULL AND utm_source IS NULL THEN 'direct type in search'
        WHEN http_referer = 'https://www.gsearch.com' AND utm_source IS NULL THEN 'organic gsearch'
        WHEN http_referer = 'https://www.bsearch.com' AND utm_source IS NULL THEN 'organic bsearch'
        ELSE 'paid marketing'
	END AS types_of_traffic_sources,
    COUNT(DISTINCT website_session_id) AS sessions
FROM
    website_sessions
GROUP BY 1,2,3,4    
ORDER BY 1,2,3,4;

/*
Analysis of paid traffic sources
Questions:
What is the main utm source that generates the most sessions and orders on the site?
What is the session-to-order conversion rate by device type and utm source?

The results table contains annual and monthly data for both gsearch and bsearch, broken down by device type (mobile, desktop).
Collected data is: volume of website sessions, number of orders, conversion rates (orders/sessions), bsearch to gsearch session volume percentage.
*/

SELECT 
	YEAR(ws.created_at) AS yr,
    MONTH(ws.created_at) AS mo,
    device_type,
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN ws.website_session_id ELSE NULL END) gserach_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN ord.order_id ELSE NULL END) gsearch_orders,
    ROUND(COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN ord.order_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN ws.website_session_id ELSE NULL END) *100,1) AS cvr_gsearch,
    
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN ws.website_session_id ELSE NULL END) bserach_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN ord.order_id ELSE NULL END) bsearch_orders,
    ROUND(COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN ord.order_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN ws.website_session_id ELSE NULL END) *100,1) AS cvr_bsearch,
    
    ROUND(COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN ws.website_session_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN ws.website_session_id ELSE NULL END) *100,1) AS utm_source_pct
FROM
    website_sessions ws
        LEFT JOIN
    orders ord ON ws.website_session_id = ord.website_session_id
WHERE utm_source IN ('gsearch','bsearch')
GROUP BY 1,2,3
ORDER BY 3,1,2
;

/*
Non - Paid traffic sources analysis
Questions: 
What is the trend of unpaid traffic sources?
What percentage of traffic comes from sources not related to direct costs?

The results table contains annual and monthly data of volume of website sessions for non paid traffic sources
as percentage of all traffic.
*/

SELECT 
	YEAR(created_at) AS yr,
    MONTH(created_at) AS mo,
	COUNT(DISTINCT CASE WHEN types_of_traffic_sources = 'paid marketing' THEN website_session_id ELSE NULL END) AS paid_sources,
    
    COUNT(DISTINCT CASE WHEN types_of_traffic_sources = 'direct type in search - no direct cost-related marketing' THEN website_session_id ELSE NULL END) AS direct_type_in,
    ROUND(COUNT(DISTINCT CASE WHEN types_of_traffic_sources = 'direct type in search - no direct cost-related marketing' THEN website_session_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN types_of_traffic_sources = 'paid marketing' THEN website_session_id ELSE NULL END)*100,1) AS direct_pct_paid,
    
    COUNT(DISTINCT CASE WHEN types_of_traffic_sources = 'organic search - no direct cost-related marketing' THEN website_session_id ELSE NULL END) AS organic_search,
	ROUND(COUNT(DISTINCT CASE WHEN types_of_traffic_sources = 'organic search - no direct cost-related marketing' THEN website_session_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN types_of_traffic_sources = 'paid marketing' THEN website_session_id ELSE NULL END)*100,1) AS organic_pct_paid,
    
    COUNT(DISTINCT CASE WHEN types_of_traffic_sources = 'social media marketing' THEN website_session_id ELSE NULL END) AS socialmedia,
	ROUND(COUNT(DISTINCT CASE WHEN types_of_traffic_sources = 'social media marketing' THEN website_session_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN types_of_traffic_sources = 'paid marketing' THEN website_session_id ELSE NULL END)*100,1) AS socialmedia_pct_paid

FROM(
SELECT 
    website_session_id,
    created_at,
    CASE 
		WHEN http_referer IS NULL AND utm_source IS NULL THEN 'direct type in search - no direct cost-related marketing'
        WHEN http_referer IN ('https://www.gsearch.com','https://www.bsearch.com') AND utm_source IS NULL THEN 'organic search - no direct cost-related marketing'
		WHEN utm_source = 'socialbook' THEN 'social media marketing'
        ELSE 'paid marketing'
	END AS types_of_traffic_sources
FROM
    website_sessions) AS sessions_w_types
GROUP BY
    yr,mo;

/*
2. Average website sessions volume by hour and weekday
Questions:
Is there any seasonality and dependence between the days of the week, the hours of the day and the average session volume?

The results table shows the average values of the number of sessions for each hour of the day and for each day of the week. 
There is also an overall average number of sessions for each hour.
*/

SELECT
	hr,
    ROUND(AVG(website_sessions),1) AS avg_overall,
    ROUND(AVG(CASE WHEN wkdy = 0 THEN website_sessions ELSE NULL END),1) AS Mon,
    ROUND(AVG(CASE WHEN wkdy = 1 THEN website_sessions ELSE NULL END),1) AS Tue,
    ROUND(AVG(CASE WHEN wkdy = 2 THEN website_sessions ELSE NULL END),1) AS Wed,
    ROUND(AVG(CASE WHEN wkdy = 3 THEN website_sessions ELSE NULL END),1) AS Thu,
    ROUND(AVG(CASE WHEN wkdy = 4 THEN website_sessions ELSE NULL END),1) AS Fri,
    ROUND(AVG(CASE WHEN wkdy = 5 THEN website_sessions ELSE NULL END),1) AS Sat,
    ROUND(AVG(CASE WHEN wkdy = 6 THEN website_sessions ELSE NULL END),1) AS Sun
FROM(
SELECT 
	DATE(created_at) AS date_created,
    weekday(created_at) AS wkdy,
    HOUR(created_at) AS hr,
    COUNT(DISTINCT website_session_id) AS website_sessions
FROM website_sessions
GROUP BY 1,2,3) weekly_daily_sessions
GROUP BY 1
ORDER BY 1
;

/*
3. Product based analysis - total revenue, total margin, revenue per session
The results table contains some of the important KPIs to illustrate how well economically company is performing. 
Annual and monthly trends for overall conversion rates and revenue per website sessions are included.
Second query results with monthly total revenue and total margin for each of 4 main company's products.
*/

SELECT 
    year(w.created_at) AS yr,
    month(w.created_at) mo,
    COUNT(DISTINCT o.order_id) AS orders,
    -- COUNT(DISTINCT w.website_session_id) AS sessions,
    ROUND(COUNT(DISTINCT o.order_id) / COUNT(DISTINCT w.website_session_id) *100,1) AS conv_rt,
    ROUND(SUM(o.price_usd)/COUNT(DISTINCT w.website_session_id),2) AS revenue_per_session,
    COUNT(DISTINCT CASE WHEN o.primary_product_id = 1 THEN o.order_id ELSE NULL END) AS product1_orders,
    COUNT(DISTINCT CASE WHEN o.primary_product_id = 2 THEN o.order_id ELSE NULL END) AS product2_orders,
    COUNT(DISTINCT CASE WHEN o.primary_product_id = 3 THEN o.order_id ELSE NULL END) AS product3_orders,
    COUNT(DISTINCT CASE WHEN o.primary_product_id = 4 THEN o.order_id ELSE NULL END) AS product4_orders
FROM
    website_sessions w
        LEFT JOIN
    orders o ON w.website_session_id = o.website_session_id
GROUP BY 1,2
ORDER BY 1,2
;

SELECT 
    year(w.created_at) AS yr,
    month(w.created_at) mo,
    SUM(CASE WHEN o.primary_product_id = 1 THEN o.price_usd ELSE NULL END) AS product1_revenue,
    SUM(CASE WHEN o.primary_product_id = 1 THEN o.price_usd - o.cogs_usd ELSE NULL END) AS product1_margin,
    
    SUM(CASE WHEN o.primary_product_id = 2 THEN o.price_usd ELSE NULL END) AS product2_revenue,
    SUM(CASE WHEN o.primary_product_id = 2 THEN o.price_usd - o.cogs_usd ELSE NULL END) AS product2_margin,
    
    SUM(CASE WHEN o.primary_product_id = 3 THEN o.price_usd ELSE NULL END) AS product3_revenue,
    SUM(CASE WHEN o.primary_product_id = 3 THEN o.price_usd - o.cogs_usd ELSE NULL END) AS product3_margin,
    
    SUM(CASE WHEN o.primary_product_id = 4 THEN o.price_usd ELSE NULL END) AS product4_revenue,
    SUM(CASE WHEN o.primary_product_id = 4 THEN o.price_usd - o.cogs_usd ELSE NULL END) AS product4_margin
FROM
    website_sessions w
        LEFT JOIN
    orders o ON w.website_session_id = o.website_session_id
    WHERE o.primary_product_id IS NOT NULL
GROUP BY 1,2
ORDER BY 1,2
;

/*SECTION II*/
/*
1. A/B testing - website performance
This part of the project is more code based and deals with the analytics process. 
It will not be used for data visualization.

Description:
At some point in time, the company decided to check if the change of the home page will decrease the 'bounce' rate - 
which means that more customers will proceed to actually buy products from them.
It introduced a new version of the homepage, called lander-1.
*/
-- STEP 1 Calculating base bounce rate for home page
-- Date to which there was only original home page - 2012-06-09 | Based on query below
SELECT DISTINCT
    pageview_url, 
    MIN(created_at) AS first_pageview
FROM
    website_pageviews
WHERE
    pageview_url = '/lander-1'
        AND created_at IS NOT NULL
GROUP BY pageview_url;

-- STEP 2 Finding first pageview id for website session
CREATE TEMPORARY TABLE first_pv_home
SELECT 
    wp.website_session_id,
    MIN(wp.website_pageview_id) AS first_pageviewed_id
FROM
    website_pageviews wp
        JOIN
    website_sessions ws ON ws.website_session_id = wp.website_session_id
WHERE
    ws.created_at < '2012-06-09'
GROUP BY 1
;

-- STEP 3 Checking landing page url for website session
CREATE TEMPORARY TABLE landing_page_session_home
SELECT 
    fp.website_session_id,
    wp.pageview_url AS landing_page
FROM
    first_pv_home fp
        JOIN
    website_pageviews wp ON fp.first_pageviewed_id = wp.website_pageview_id
;

-- STEP 4 Identifying bounce sessions
CREATE TEMPORARY TABLE bounce_sessions_home
SELECT 
    lps.website_session_id,
    lps.landing_page,
    COUNT(DISTINCT wp.website_pageview_id) AS number_of_pages
FROM
    landing_page_session_home lps
        LEFT JOIN
    website_pageviews wp ON lps.website_session_id = wp.website_session_id
GROUP BY 1,2
HAVING COUNT(DISTINCT wp.website_pageview_id) = 1
;

-- STEP 5 Calculating bounce rate for home page - bounce_rate = 59% with 10403 total sessions and 6164 bounced sessions
SELECT 
	lps.landing_page,
    COUNT(DISTINCT lps.website_session_id) AS sessions,
    COUNT(DISTINCT bs.website_session_id) AS bounce_sessions,
    COUNT(DISTINCT bs.website_session_id)/COUNT(DISTINCT lps.website_session_id) AS bounce_rate
FROM
    bounce_sessions_home bs
        RIGHT JOIN
    landing_page_session_home lps ON lps.website_session_id = bs.website_session_id
GROUP BY
	lps.landing_page
;

-- STEP 6 Repeating steps 2-5 for home page and new lander-1 page
-- We run test up till 31-08-2012 (arbitrary choice)
DROP TEMPORARY TABLE IF EXISTS first_pv;
CREATE TEMPORARY TABLE first_pv
SELECT 
   wp.website_session_id,
   min(wp.website_pageview_id) AS first_pageviewed_id 
FROM
    website_pageviews wp
        JOIN
    website_sessions ws ON ws.website_session_id = wp.website_session_id
WHERE
    ws.created_at BETWEEN '2012-06-19' AND '2012-09-01'
GROUP BY 1
;
DROP TEMPORARY TABLE IF EXISTS landing_page_session;
CREATE TEMPORARY TABLE landing_page_session
SELECT 
    fp.website_session_id,
    wp.pageview_url AS landing_page
FROM
    first_pv fp
        JOIN
    website_pageviews wp ON fp.first_pageviewed_id = wp.website_pageview_id
;
DROP TEMPORARY TABLE IF EXISTS bounce_sessions;
CREATE TEMPORARY TABLE bounce_sessions
SELECT 
    lps.website_session_id,
    lps.landing_page,
    COUNT(DISTINCT wp.website_pageview_id) AS number_of_pages
FROM
    landing_page_session lps
        LEFT JOIN
    website_pageviews wp ON lps.website_session_id = wp.website_session_id
GROUP BY 1,2
HAVING COUNT(DISTINCT wp.website_pageview_id) = 1
;

SELECT 
	lps.landing_page,
    COUNT(DISTINCT lps.website_session_id) AS sessions,
    COUNT(DISTINCT bs.website_session_id) AS bounce_sessions,
    COUNT(DISTINCT bs.website_session_id)/COUNT(DISTINCT lps.website_session_id) AS bounce_rate
FROM
    bounce_sessions bs
        RIGHT JOIN
    landing_page_session lps ON lps.website_session_id = bs.website_session_id
GROUP BY
	lps.landing_page
;
/* CONCLUSION: In given time frame bounce rate for home dropped from 59% to 50.5%, while bounce rate for lander-1 equals 52.5% */ 


/*SECTION III*/
/*
1. Conversion funnels
Description:
The purpose of this analysis is to identify at what stage of purchase process customers are quitting.
We will perform this analysis with the following assumptions:
- utm source is gsearch (paid source) and utm campaign is nonbranded (customers are searching not after brand) - the biggest traffic source
- conversion funnel 1: /lander-1,/products,/the-original-mr-fuzzy,/cart,/shipping,/billing,/thank-you-for-your-order
- conversion funnel 2: /home,/products,/the-original-mr-fuzzy,/cart,/shipping,/billing,/thank-you-for-your-order
- time frame identical to bounce rate analysis  between '2012-06-19' and '2012-09-01'

There are two results tables:
- First one shows number of sessions on each step of purchase process, both for original and second homepage.
- Second one shows click through rates for each step of purchase process, both for original and second homepage.
*/

DROP TEMPORARY TABLE IF EXISTS conversion_funnel;
CREATE TEMPORARY TABLE conversion_funnel
SELECT 
	website_session_id,
    MAX(home) AS home_made_it,
    MAX(lander_1) AS lander1_made_it,
    MAX(products) AS products_made_it,
    MAX(mr_fuzzy) AS mr_fuzzy_made_it,
    MAX(cart) AS cart_made_it,
    MAX(shipping) AS shipping_made_it,
    MAX(billing) AS billing_made_it,
    MAX(thank_you) AS thank_you_made_it
FROM(
	SELECT 
		ws.website_session_id,
		wp.pageview_url,
		wp.created_at,
        CASE WHEN pageview_url = '/home' THEN 1 ELSE 0 END AS home,
        CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END AS lander_1,
		CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products,
		CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mr_fuzzy,
		CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart,
		CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping,
		CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing,
		CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thank_you
	FROM
		website_pageviews wp
			INNER JOIN
		website_sessions ws ON wp.website_session_id = ws.website_session_id
	WHERE
		ws.created_at BETWEEN '2012-06-19' AND '2012-09-01'
		AND utm_source = 'gsearch' AND utm_campaign = 'nonbrand'
		AND wp.pageview_url IN ('/home','/lander-1','/products','/the-original-mr-fuzzy','/cart','/shipping','/billing','/thank-you-for-your-order')
) conv_funnel_lander1
GROUP BY
website_session_id
;

SELECT 
	CASE 
		WHEN home_made_it = 1 THEN 'original home'
		WHEN lander1_made_it = 1 THEN 'custom lender'
		ELSE 'mistake'
	END AS segment,
	COUNT(website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN products_made_it = 1 THEN website_session_id ELSE NULL END) AS to_products,
    COUNT(DISTINCT CASE WHEN mr_fuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS to_cart,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS to_shipping,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS to_billing,
    COUNT(DISTINCT CASE WHEN thank_you_made_it = 1 THEN website_session_id ELSE NULL END) AS to_thanks
FROM conversion_funnel
GROUP BY 1
;

SELECT 
	CASE 
		WHEN home_made_it = 1 THEN 'original home'
		WHEN lander1_made_it = 1 THEN 'custom lender'
		ELSE 'mistake'
	END AS segment,
	COUNT(website_session_id) AS total_sessions,
	COUNT(DISTINCT CASE WHEN products_made_it = 1 THEN website_session_id ELSE NULL END)/
    COUNT(website_session_id) AS lander_click_rate,
    COUNT(DISTINCT CASE WHEN mr_fuzzy_made_it = 1 THEN website_session_id ELSE NULL END)/
    COUNT(DISTINCT CASE WHEN products_made_it = 1 THEN website_session_id ELSE NULL END) AS products_click_rate,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END)/
    COUNT(DISTINCT CASE WHEN mr_fuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS mrfuzzy_click_rate,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END)/
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS cart_click_rate,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END)/
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS shipping_click_rate,
    COUNT(DISTINCT CASE WHEN thank_you_made_it = 1 THEN website_session_id ELSE NULL END)/
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS billing_click_rate
FROM conversion_funnel
GROUP BY 1
;


