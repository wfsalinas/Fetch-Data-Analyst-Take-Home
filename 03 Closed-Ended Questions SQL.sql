################################################################################################
## CLOSED-ENDED QUESTION 1: What are the top 5 brands by receipts scanned among users 21 and over?
## ANSWER: DOVE, NERDS CANDY, GREAT VALUE, COCA-COLA, SOUR PATCH KIDS
################################################################################################
WITH BrandAge AS (
                  SELECT DISTINCT
                    T.receipt_id,
                    P.brand,
                    T.user_id,
                    U.user_age
                  FROM `FETCH2024.Transaction` T
                  LEFT JOIN `FETCH2024.Products` P
                    ON T.barcode = P.barcode
                  LEFT JOIN `FETCH2024.User` U 
                    ON T.user_id = U.id
                  WHERE U.user_age >= 21 AND P.barcode IS NOT NULL 
                                         AND P.brand IS NOT NULL 
                    )
SELECT
  BA.brand,
  COUNT(*) AS num_scanned_receipts
FROM BrandAge BA
GROUP BY BA.brand
ORDER BY num_scanned_receipts DESC

################################################################################################
## CLOSED-ENDED QUESTION 2: What are the top 5 brands by sales among users that have had their 
##                          account for at least six months?
## ANSWER: CVS, DOVE, TRIDENT, COORS LIGHT, AND TRESEMME
################################################################################################
WITH Sales AS (
                SELECT
                  T.user_id,
                  T.receipt_id,
                  T.barcode,
                  T.final_sale,
                  P.brand,
                  U.accnt_age_months
                FROM `FETCH2024.Transaction`T
                LEFT JOIN `FETCH2024.Products` P
                  ON T.barcode = P.barcode
                LEFT JOIN `FETCH2024.User` U
                  ON T.user_id = U.id
                WHERE U.accnt_age_months >= 6 AND P.brand IS NOT NULL
              )

SELECT 
  brand, 
  ROUND(SUM(final_sale), 2) AS total_sale
FROM Sales
GROUP BY brand
ORDER BY total_sale DESC
LIMIT 5

################################################################################################
## CLOSED-ENDED QUESTION 3: What is the percentage of sales in the Health & Wellness category 
##                          by generation?
## ANSWER: Baby Boomers (54.26%), Gen X (23.7%), & Milennials (22.04%)
################################################################################################
WITH Sales   AS (
                  SELECT
                    T.user_id,
                    T.receipt_id,
                    T.barcode,
                    T.final_sale,
                    P.category_1,
                    U.generation
                  FROM `FETCH2024.Transaction`T
                  LEFT JOIN `FETCH2024.Products` P
                    ON T.barcode = P.barcode
                  LEFT JOIN `FETCH2024.User` U
                    ON T.user_id = U.id
                  WHERE U.generation IS NOT NULL AND P.category_1 = 'Health & Wellness'
                ),
     HWSales AS (
                  SELECT 
                    generation, 
                    SUM(final_sale) AS total_sales
                  FROM Sales
                  GROUP BY generation
                    )
SELECT 
  generation, 
  ROUND(total_sales*100 / (SELECT SUM(total_sales) FROM HWSales), 2) AS percent_sales
FROM HWSales
ORDER BY 2 DESC