--Part B
--Function to calculate days late
CREATE OR REPLACE FUNCTION calculate_days_late(return_date DATE, due_date DATE)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
	days_late INT;
BEGIN
	--If rental has not been returned consider it not late
	IF return_date IS NULL THEN
		RETURN 0;
	END IF;
	
	--Calculate how many days late, negative default to 0
	SELECT GREATEST((return_date - due_date), 0) INTO days_late;
	
	RETURN days_late;
END;
$$;

--CHeck Function
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public';

--PART C
--Detailed Report Table
CREATE TABLE detailed_report (
	rental_id INT,
	Customer_id INT,
	store_id SMALLINT,
	film_title VARCHAR(255),
	rental_date DATE,
	due_date DATE,
	return_date DATE,
	days_late INT,
	late_fee DECIMAL(5,2)
);

--Summary report table
CREATE TABLE summary_report(
	rental_month VARCHAR(25),
	rental_year INT,
	total_rentals BIGINT,
	late_returns BIGINT,
	total_late_fees DECIMAL(10,2),
	store_id SMALLINT
	
);
--Show the detailed report and summary report exist
SELECT * FROM detailed_report LIMIT 10;
SELECT * FROM summary_report LIMIT 10;

--PART D
--Pull rental data from database and populate the etailed report. 
INSERT INTO detailed_report(
	rental_id,
	customer_id,
	store_id,
	film_title,
	rental_date,
	due_date,
	return_date,
	days_late,
	late_fee
)
SELECT
	r.rental_id,
	r.customer_id,
	i.store_id,
	f.title AS film_title,
	r.rental_date,
	(r.rental_date + INTERVAL '3 days')::DATE AS due_date,
	r.return_date,
	calculate_days_late(r.return_date::DATE, (r.rental_date + INTERVAL '3 days')::DATE) AS days_late,
	COALESCE(p.amount, 0.00) AS late_fee
FROM rental as r
INNER JOIN inventory AS i ON r.inventory_id = i.inventory_id
INNER JOIN film AS f on i.film_id = f.film_id
LEFT JOIN payment AS p ON p.rental_id = r.rental_id;

--Verify Detailed table
SELECT * FROM detailed_report LIMIT 10;
