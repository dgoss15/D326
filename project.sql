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
SELECT * FROM detailed_report;


--Section E Create trigger function

CREATE or REPLACE FUNCTION update_summary_report()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
	--Clear the old summary report
	DELETE FROM summary_report;
	
	--Insert fresh updated summary data
	INSERT INTO summary_report (rental_month, rental_year, total_rentals, late_returns, total_late_fees, store_id)
	SELECT 
		TO_CHAR(rental_date, 'Month') AS rental_month,
		EXTRACT(YEAR FROM rental_date)::INT AS rental_year,
		COUNT(rental_id) AS total_rentals,
		SUM(CASE WHEN days_late > 0 THEN 1 ELSE 0 END) AS late_returns,
		SUM(late_fee) AS total_late_fees,
		store_id
	FROM detailed_report
	GROUP BY store_id, rental_month, rental_year
	ORDER BY rental_year, rental_month, store_id;
	
	RETURN NEW;
END;
$$;

--CREATE TRIGGER ON Detailed Report
CREATE TRIGGER trg_update_summary
AFTER INSERT OR UPDATE OR DELETE ON detailed_report
FOR EACH STATEMENT
EXECUTE FUNCTION update_summary_report();

--TEST rental
INSERT INTO detailed_report (
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
VALUES (
	99999,
	123,
	1,
	'Test Movie',
	'2024-07-01',
	'2024-07-04',
	'2024-07-05',
	1,
	2.50
);
--Summary report currently
SELECT * FROM summary_report;

--Remove test 
DELETE FROM detailed_report
WHERE rental_id = 99999;





--Section F Stored Procedure to Clear old data from detailed_report and summary_report
CREATE OR REPLACE PROCEDURE refresh_reports()
LANGUAGE plpgsql
AS $$
BEGIN
	--Clear old data
	DELETE FROM summary_report;
	DELETE FROM detailed_report;

	--Rebuild detailed_report
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
		calculate_days_late(r.return_date::DATE, (r.rental_date + interval '3 days')::DATE) AS days_late,
		COALESCE(p.amount, 0.00) AS late_fee
	FROM rental AS r
	INNER JOIN inventory AS i ON r.inventory_id = i.inventory_id
	INNER JOIN film AS f ON i.film_id = f.film_id
	LEFT JOIN payment AS p ON p.rental_id = r.rental_id;
	
	--Rebuild the summary_report
	INSERT INTO summary_report (
		rental_month,
		rental_year,
		total_rentals,
		late_returns,
		total_late_fees,
		store_id
	)
	SELECT
		TO_CHAR(rental_date, 'Month') AS rental_month,
		EXTRACT(YEAR FROM rental_date)::INT AS rental_year,
		COUNT(rental_id) AS total_rentals,
		SUM(CASE WHEN days_late > 0 THEN 1 ELSE 0 END) AS late_returns,
		SUM(late_fee) AS total_late_fees,
		store_id
	FROM detailed_report
	GROUP BY store_id, rental_month, rental_year
	ORDER BY rental_year, rental_month, store_id;
END;
$$;

--Call the stored procedure
CALL refresh_reports();






