################################################################################################
## STEP 0: When the tables were uploaded to BigQuery, a column int64_field_0
## was created for each. We remove this field and update some data types.
################################################################################################
ALTER TABLE `FETCH2024.Transaction` DROP COLUMN int64_field_0;

CREATE OR REPLACE TABLE `FETCH2024.User` AS
  SELECT DISTINCT
    id, 
    state, 
    language, 
    gender, 
    birth_date, 
    created_date, 
    CAST(user_age AS INT) AS user_age,
    accnt_age_months,
    generation
  FROM `FETCH2024.User`;

  CREATE OR REPLACE TABLE `FETCH2024.Products` AS
  SELECT 
    category_1,
    category_2,
    category_3,
    category_4,
    manufacturer,
    brand,
    CAST(barcode as STRING) AS barcode
  FROM `FETCH2024.Products`;

################################################################################################
## STEP 1: This query investigates whether rows containing NULLs in the final_sales are redundant 
## or not. For each user_id and receipt_id combination there appears to be redundant row containing 
## a final_quantity value corresponding to a NULL final_sale value, but also another similar row 
## with the same fina_quantity but with a non-NULL final_sale value.
################################################################################################

WITH MoreTwoRows AS ( # obtain user_id and receipt_id combinations that return at least two rows
                      SELECT user_id, receipt_id
                      FROM `FETCH2024.Transaction`
                      GROUP BY user_id, receipt_id
                      HAVING COUNT(*) > 1 
                    ),
     NullCheck   AS ( #for users in the resulting set, tag rows containing NULLS in the sale column.
                      SELECT 
                        user_id, 
                        receipt_id, 
                        store_name, 
                        barcode,
                        final_quantity, 
                        final_sale, 
                        IF(final_sale IS NULL, 1, 0) AS check
                      FROM `FETCH2024.Transaction`
                      WHERE user_id IN (SELECT DISTINCT user_id FROM MoreTwoRows)
                    )

# add the number of rows for each user_id, receipt_id, store_name, & barcode combination.
SELECT 
      user_id, 
      receipt_id, 
      store_name, 
      barcode, 
      SUM(check) AS _sum
FROM NullCheck
GROUP BY user_id, receipt_id, store_name, barcode
HAVING SUM(check) > 1
# Note: This query returns no records, meaning that each grouping (by 4 variables) has 
#       at most 1 NULL redudant row. Hence these records with a NULL for sale can be
#       removed safely.


################################################################################################
## STEP 2: In the Python step with found 110 records with a decimal in the quantity variable. This 
## reduces to 80 records if we exclude NULL sale values. The quantity value is unusual, and most
## likely is incorrect. Due to the low impact,we can remove them from our analysis.
################################################################################################
SELECT *
FROM `FETCH2024.Transaction`
WHERE decimal_quantity IS TRUE AND final_sale IS NOT NULL

################################################################################################
## STEP 3: We want to determine whether we can remove rows that contain a 0.0 for quantity. 
## First pick out transactions that involve zero, including their non-zero rows, making sure to 
## exclude NULL values from final sale and decimal quantities.
## Second, we identify the records that have duplicate final_sale values with both a zero and no-zero 
## quatity value.
## Finally, we check how many records have a minimum final_quantity greater than 0 AND 
## have multiple rows within each barcode.
################################################################################################
WITH ZeroQuantity  AS ( SELECT DISTINCT receipt_id 
                        FROM `FETCH2024.Transaction` 
                        WHERE CAST(final_quantity AS INT) = 0
                      ),
     ZeroQuantity1 AS (
                        SELECT * EXCEPT(decimal_quantity, scan_date)
                        FROM `FETCH2024.Transaction`
                        WHERE receipt_id IN (SELECT receipt_id FROM ZeroQuantity) AND final_sale IS NOT NULL
                                                                                  AND decimal_quantity IS FALSE 
                       ),
     ZeroQuantity2  AS (
                        # consider rows with zero-quantity but at least one-distinct sale value
                        SELECT user_id, receipt_id, barcode, COUNT(DISTINCT final_sale)
                        FROM ZeroQuantity1
                        GROUP BY user_id, receipt_id, barcode
                        HAVING COUNT(DISTINCT final_sale) >= 1 
                       )

SELECT 
  user_id, 
  receipt_id,
  final_sale
FROM ZeroQuantity1
WHERE receipt_id IN (SELECT receipt_id FROM ZeroQuantity2)
GROUP BY user_id, receipt_id, final_sale
HAVING MIN(final_quantity) > 0 AND COUNT(barcode) >= 2
# Note: The query results no output, meaning that each row corresponding to a user, receipt, and sale group
#       does not contain a non-zero value as a minimum. In other words, there are rows that have quantity = 0
#       and a sale value, together with an identical row except that quantity != 0 and the same sale_value.
#       Hence we can remove these records safely.

################################################################################################
## STEP 4: Save the clean Transaction table.
################################################################################################
CREATE OR REPLACE TABLE `FETCH2024.Transaction` AS
  SELECT DISTINCT
    user_id,
    receipt_id,
    purchase_date,
    store_name,
    scan_date,
    CAST(barcode AS STRING)     AS barcode,
    CAST(final_quantity AS INT) AS final_quantity,
    final_sale
  FROM `FETCH2024.Transaction`
  WHERE decimal_quantity IS FALSE                   -- remove quantities with decimal values.
                AND final_sale IS NOT NULL          -- remove NULL final sale values.
                AND CAST(final_quantity AS INT) > 0 -- remove rows with quantity = 0
  ORDER BY user_id, receipt_id, barcode, final_sale, final_quantity
;                    

                    