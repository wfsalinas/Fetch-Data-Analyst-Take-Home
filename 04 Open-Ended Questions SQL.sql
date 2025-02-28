################################################################################################
## OPEN-ENDED QUESTION 2: Which is the leading brand in the Dips & Salsa category?
## ANSWER: TOSTITOS
################################################################################################
WITH Sales   AS (
                  SELECT
                    T.user_id,
                    T.receipt_id,
                    T.final_quantity,
                    T.final_sale,
                    P.brand
                  FROM `FETCH2024.Transaction`T
                  LEFT JOIN `FETCH2024.Products` P
                    ON T.barcode = P.barcode
                  LEFT JOIN `FETCH2024.User` U
                    ON T.user_id = U.id
                  WHERE P.category_2 = 'Dips & Salsa'
                )
     
SELECT brand, 
        CAST(SUM(final_quantity) AS INT) AS total_quantity,
        ROUND(SUM(final_sale), 2)        AS total_sales,
        COUNT(DISTINCT receipt_id)       AS receipt_count
FROM Sales
GROUP BY brand
ORDER BY total_sales DESC
                    