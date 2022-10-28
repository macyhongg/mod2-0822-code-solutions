--
-- PostgreSQL database dump
--

-- Dumped from database version 10.10 (Ubuntu 10.10-0ubuntu0.18.04.1)
-- Dumped by pg_dump version 10.10 (Ubuntu 10.10-0ubuntu0.18.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: mpaa_rating; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.mpaa_rating AS ENUM (
    'G',
    'PG',
    'PG-13',
    'R',
    'NC-17'
);


--
-- Name: year; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.year AS integer
	CONSTRAINT year_check CHECK (((VALUE >= 1901) AND (VALUE <= 2155)));


--
-- Name: _group_concat(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._group_concat(text, text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
SELECT CASE
  WHEN $2 IS NULL THEN $1
  WHEN $1 IS NULL THEN $2
  ELSE $1 || ', ' || $2
END
$_$;


--
-- Name: film_in_stock(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.film_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) RETURNS SETOF integer
    LANGUAGE sql
    AS $_$
     SELECT "inventoryId"
     FROM inventory
     WHERE "filmId" = $1
     AND "storeId" = $2
     AND inventory_in_stock("inventoryId");
$_$;


--
-- Name: film_not_in_stock(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.film_not_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) RETURNS SETOF integer
    LANGUAGE sql
    AS $_$
    SELECT "inventoryId"
    FROM inventory
    WHERE "filmId" = $1
    AND "storeId" = $2
    AND NOT inventory_in_stock("inventoryId");
$_$;


--
-- Name: get_customer_balance(integer, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_customer_balance(p_customer_id integer, p_effective_date timestamp with time zone) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
       --#OK, WE NEED TO CALCULATE THE CURRENT BALANCE GIVEN A CUSTOMER_ID AND A DATE
       --#THAT WE WANT THE BALANCE TO BE EFFECTIVE FOR. THE BALANCE IS:
       --#   1) RENTAL FEES FOR ALL PREVIOUS RENTALS
       --#   2) ONE DOLLAR FOR EVERY DAY THE PREVIOUS RENTALS ARE OVERDUE
       --#   3) IF A FILM IS MORE THAN RENTAL_DURATION * 2 OVERDUE, CHARGE THE REPLACEMENT_COST
       --#   4) SUBTRACT ALL PAYMENTS MADE BEFORE THE DATE SPECIFIED
DECLARE
    v_rentfees DECIMAL(5,2); --#FEES PAID TO RENT THE VIDEOS INITIALLY
    v_overfees INTEGER;      --#LATE FEES FOR PRIOR RENTALS
    v_payments DECIMAL(5,2); --#SUM OF PAYMENTS MADE PREVIOUSLY
BEGIN
    SELECT COALESCE(SUM("films"."rentalRate"),0) INTO v_rentfees
    FROM film, inventory, rental
    WHERE "films"."filmId" = inventory."filmId"
      AND inventory."inventoryId" = "rentals"."inventoryId"
      AND "rentals"."startDate" <= p_effective_date
      AND "rentals"."customerId" = p_customer_id;

    SELECT COALESCE(SUM(IF(("rentals"."endDate" - "rentals"."startDate") > ("films"."rentalDuration" * '1 day'::interval),
        (("rentals"."endDate" - "rentals"."startDate") - ("films"."rentalDuration" * '1 day'::interval)),0)),0) INTO v_overfees
    FROM rental, inventory, film
    WHERE "films"."filmId" = inventory."filmId"
      AND inventory."inventoryId" = "rentals"."inventoryId"
      AND "rentals"."startDate" <= p_effective_date
      AND "rentals"."customerId" = p_customer_id;

    SELECT COALESCE(SUM("payments".amount),0) INTO v_payments
    FROM payment
    WHERE "payments"."paidAt" <= p_effective_date
    AND "payments"."customerId" = p_customer_id;

    RETURN v_rentfees + v_overfees - v_payments;
END
$$;


--
-- Name: inventory_held_by_customer(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inventory_held_by_customer(p_inventory_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_customer_id INTEGER;
BEGIN

  SELECT "customerId" INTO v_customer_id
  FROM rental
  WHERE "endDate" IS NULL
  AND "inventoryId" = p_inventory_id;

  RETURN v_customer_id;
END $$;


--
-- Name: inventory_in_stock(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inventory_in_stock(p_inventory_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rentals INTEGER;
    v_out     INTEGER;
BEGIN
    -- AN ITEM IS IN-STOCK IF THERE ARE EITHER NO ROWS IN THE rental TABLE
    -- FOR THE ITEM OR ALL ROWS HAVE "endDate" POPULATED

    SELECT count(*) INTO v_rentals
    FROM rental
    WHERE "inventoryId" = p_inventory_id;

    IF v_rentals = 0 THEN
      RETURN TRUE;
    END IF;

    SELECT COUNT("rentalId") INTO v_out
    FROM inventory LEFT JOIN rental USING("inventoryId")
    WHERE inventory."inventoryId" = p_inventory_id
    AND "rentals"."endDate" IS NULL;

    IF v_out > 0 THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
END $$;


--
-- Name: last_day(timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.last_day(timestamp with time zone) RETURNS date
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
  SELECT CASE
    WHEN EXTRACT(MONTH FROM $1) = 12 THEN
      (((EXTRACT(YEAR FROM $1) + 1) operator(pg_catalog.||) '-01-01')::date - INTERVAL '1 day')::date
    ELSE
      ((EXTRACT(YEAR FROM $1) operator(pg_catalog.||) '-' operator(pg_catalog.||) (EXTRACT(MONTH FROM $1) + 1) operator(pg_catalog.||) '-01')::date - INTERVAL '1 day')::date
    END
$_$;


--
-- Name: last_updated(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.last_updated() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW."updatedAt" = CURRENT_TIMESTAMP;
    RETURN NEW;
END $$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    "customerId" integer NOT NULL,
    "storeId" smallint NOT NULL,
    "firstName" text NOT NULL,
    "lastName" text NOT NULL,
    email text,
    "addressId" smallint NOT NULL,
    "isActive" boolean DEFAULT true NOT NULL,
    "createdAt" date DEFAULT ('now'::text)::date NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now()
);


--
-- Name: rewards_report(integer, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rewards_report(min_monthly_purchases integer, min_dollar_amount_purchased numeric) RETURNS SETOF public.customers
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE
    last_month_start DATE;
    last_month_end DATE;
rr RECORD;
tmpSQL TEXT;
BEGIN

    /* Some sanity checks... */
    IF min_monthly_purchases = 0 THEN
        RAISE EXCEPTION 'Minimum monthly purchases parameter must be > 0';
    END IF;
    IF min_dollar_amount_purchased = 0.00 THEN
        RAISE EXCEPTION 'Minimum monthly dollar amount purchased parameter must be > $0.00';
    END IF;

    last_month_start := CURRENT_DATE - '3 month'::interval;
    last_month_start := to_date((extract(YEAR FROM last_month_start) || '-' || extract(MONTH FROM last_month_start) || '-01'),'YYYY-MM-DD');
    last_month_end := LAST_DAY(last_month_start);

    /*
    Create a temporary storage area for Customer IDs.
    */
    CREATE TEMPORARY TABLE tmpCustomer ("customerId" INTEGER NOT NULL PRIMARY KEY);

    /*
    Find all customers meeting the monthly purchase requirements
    */

    tmpSQL := 'INSERT INTO tmpCustomer ("customerId")
        SELECT p."customerId"
        FROM payment AS p
        WHERE DATE(p."paidAt") BETWEEN '||quote_literal(last_month_start) ||' AND '|| quote_literal(last_month_end) || '
        GROUP BY "customerId"
        HAVING SUM(p.amount) > '|| min_dollar_amount_purchased || '
        AND COUNT("customerId") > ' ||min_monthly_purchases ;

    EXECUTE tmpSQL;

    /*
    Output ALL customer information of matching rewardees.
    Customize output as needed.
    */
    FOR rr IN EXECUTE 'SELECT c.* FROM tmpCustomer AS t INNER JOIN customers AS c ON t."customerId" = c."customerId"' LOOP
        RETURN NEXT rr;
    END LOOP;

    /* Clean up */
    tmpSQL := 'DROP TABLE tmpCustomer';
    EXECUTE tmpSQL;

RETURN;
END
$_$;


--
-- Name: group_concat(text); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE public.group_concat(text) (
    SFUNC = public._group_concat,
    STYPE = text
);


--
-- Name: actor_actor_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.actor_actor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: actors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.actors (
    "actorId" integer DEFAULT nextval('public.actor_actor_id_seq'::regclass) NOT NULL,
    "firstName" text NOT NULL,
    "lastName" text NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: castMembers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."castMembers" (
    "actorId" smallint NOT NULL,
    "filmId" smallint NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: genre_genre_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.genre_genre_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: genres; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.genres (
    "genreId" integer DEFAULT nextval('public.genre_genre_id_seq'::regclass) NOT NULL,
    name text NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: filmGenre; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."filmGenre" (
    "filmId" smallint NOT NULL,
    "genreId" smallint NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: film_film_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.film_film_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: films; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.films (
    "filmId" integer DEFAULT nextval('public.film_film_id_seq'::regclass) NOT NULL,
    title text NOT NULL,
    description text,
    "releaseYear" public.year,
    "languageId" smallint NOT NULL,
    "originalLanguageId" smallint,
    "rentalDuration" smallint DEFAULT 3 NOT NULL,
    "rentalRate" numeric(4,2) DEFAULT 4.99 NOT NULL,
    length smallint,
    "replacementCost" numeric(5,2) DEFAULT 19.99 NOT NULL,
    rating public.mpaa_rating DEFAULT 'G'::public.mpaa_rating,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "specialFeatures" text[],
    fulltext tsvector NOT NULL
);


--
-- Name: actor_info; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.actor_info AS
 SELECT a."actorId",
    a."firstName",
    a."lastName",
    public.group_concat(DISTINCT ((c.name || ': '::text) || ( SELECT public.group_concat(f.title) AS group_concat
           FROM ((public.films f
             JOIN public."filmGenre" fc_1 ON ((f."filmId" = fc_1."filmId")))
             JOIN public."castMembers" fa_1 ON ((f."filmId" = fa_1."filmId")))
          WHERE ((fc_1."genreId" = c."genreId") AND (fa_1."actorId" = a."actorId"))
          GROUP BY fa_1."actorId"))) AS film_info
   FROM (((public.actors a
     LEFT JOIN public."castMembers" fa ON ((a."actorId" = fa."actorId")))
     LEFT JOIN public."filmGenre" fc ON ((fa."filmId" = fc."filmId")))
     LEFT JOIN public.genres c ON ((fc."genreId" = c."genreId")))
  GROUP BY a."actorId", a."firstName", a."lastName";


--
-- Name: address_address_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.address_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.addresses (
    "addressId" integer DEFAULT nextval('public.address_address_id_seq'::regclass) NOT NULL,
    line1 text NOT NULL,
    line2 text,
    district text NOT NULL,
    "cityId" smallint NOT NULL,
    "postalCode" text,
    phone text NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: city_city_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.city_city_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cities (
    "cityId" integer DEFAULT nextval('public.city_city_id_seq'::regclass) NOT NULL,
    name text NOT NULL,
    "countryId" smallint NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: country_country_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.country_country_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.countries (
    "countryId" integer DEFAULT nextval('public.country_country_id_seq'::regclass) NOT NULL,
    name text NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: customer_customer_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.customer_customer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: customer_customer_id_seq1; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.customer_customer_id_seq1
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: customer_customer_id_seq1; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.customer_customer_id_seq1 OWNED BY public.customers."customerId";


--
-- Name: film_list; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.film_list AS
 SELECT films."filmId" AS fid,
    films.title,
    films.description,
    genres.name AS genres,
    films."rentalRate" AS price,
    films.length,
    films.rating,
    public.group_concat(((actors."firstName" || ' '::text) || actors."lastName")) AS actors
   FROM ((((public.genres
     LEFT JOIN public."filmGenre" ON ((genres."genreId" = "filmGenre"."genreId")))
     LEFT JOIN public.films ON (("filmGenre"."filmId" = films."filmId")))
     JOIN public."castMembers" ON ((films."filmId" = "castMembers"."filmId")))
     JOIN public.actors ON (("castMembers"."actorId" = actors."actorId")))
  GROUP BY films."filmId", films.title, films.description, genres.name, films."rentalRate", films.length, films.rating;


--
-- Name: inventory_inventory_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inventory_inventory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inventory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory (
    "inventoryId" integer DEFAULT nextval('public.inventory_inventory_id_seq'::regclass) NOT NULL,
    "filmId" smallint NOT NULL,
    "storeId" smallint NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: language_language_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.language_language_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: languages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.languages (
    "languageId" integer DEFAULT nextval('public.language_language_id_seq'::regclass) NOT NULL,
    name character(20) NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: nicer_but_slower_film_list; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.nicer_but_slower_film_list AS
 SELECT films."filmId" AS fid,
    films.title,
    films.description,
    genres.name AS genres,
    films."rentalRate" AS price,
    films.length,
    films.rating,
    public.group_concat((((upper("substring"(actors."firstName", 1, 1)) || lower("substring"(actors."firstName", 2))) || upper("substring"(actors."lastName", 1, 1))) || lower("substring"(actors."lastName", 2)))) AS actors
   FROM ((((public.genres
     LEFT JOIN public."filmGenre" ON ((genres."genreId" = "filmGenre"."genreId")))
     LEFT JOIN public.films ON (("filmGenre"."filmId" = films."filmId")))
     JOIN public."castMembers" ON ((films."filmId" = "castMembers"."filmId")))
     JOIN public.actors ON (("castMembers"."actorId" = actors."actorId")))
  GROUP BY films."filmId", films.title, films.description, genres.name, films."rentalRate", films.length, films.rating;


--
-- Name: payment_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    "paymentId" integer DEFAULT nextval('public.payment_payment_id_seq'::regclass) NOT NULL,
    "customerId" smallint NOT NULL,
    "staffId" smallint NOT NULL,
    "rentalId" integer NOT NULL,
    amount numeric(5,2) NOT NULL,
    "paidAt" timestamp with time zone NOT NULL
);


--
-- Name: rental_rental_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rental_rental_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rentals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rentals (
    "rentalId" integer DEFAULT nextval('public.rental_rental_id_seq'::regclass) NOT NULL,
    "startDate" timestamp with time zone NOT NULL,
    "inventoryId" integer NOT NULL,
    "customerId" smallint NOT NULL,
    "endDate" timestamp with time zone,
    "staffId" smallint NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sales_by_film_genre; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.sales_by_film_genre AS
 SELECT c.name AS genres,
    sum(p.amount) AS total_sales
   FROM (((((public.payments p
     JOIN public.rentals r ON ((p."rentalId" = r."rentalId")))
     JOIN public.inventory i ON ((r."inventoryId" = i."inventoryId")))
     JOIN public.films f ON ((i."filmId" = f."filmId")))
     JOIN public."filmGenre" fc ON ((f."filmId" = fc."filmId")))
     JOIN public.genres c ON ((fc."genreId" = c."genreId")))
  GROUP BY c.name
  ORDER BY (sum(p.amount)) DESC;


--
-- Name: staff_staff_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_staff_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff (
    "staffId" integer DEFAULT nextval('public.staff_staff_id_seq'::regclass) NOT NULL,
    "firstName" text NOT NULL,
    "lastName" text NOT NULL,
    "addressId" smallint NOT NULL,
    email text,
    "storeId" smallint NOT NULL,
    "isActive" boolean DEFAULT true NOT NULL,
    username text NOT NULL,
    password text,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    picture bytea
);


--
-- Name: store_store_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.store_store_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stores (
    "storeId" integer DEFAULT nextval('public.store_store_id_seq'::regclass) NOT NULL,
    "managerStaffId" smallint NOT NULL,
    "addressId" smallint NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sales_by_store; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.sales_by_store AS
 SELECT ((c.name || ','::text) || cy.name) AS store,
    ((m."firstName" || ' '::text) || m."lastName") AS manager,
    sum(p.amount) AS total_sales
   FROM (((((((public.payments p
     JOIN public.rentals r ON ((p."rentalId" = r."rentalId")))
     JOIN public.inventory i ON ((r."inventoryId" = i."inventoryId")))
     JOIN public.stores s ON ((i."storeId" = s."storeId")))
     JOIN public.addresses a ON ((s."addressId" = a."addressId")))
     JOIN public.cities c ON ((a."cityId" = c."cityId")))
     JOIN public.countries cy ON ((c."countryId" = cy."countryId")))
     JOIN public.staff m ON ((s."managerStaffId" = m."staffId")))
  GROUP BY cy.name, c.name, s."storeId", m."firstName", m."lastName"
  ORDER BY cy.name, c.name;


--
-- Name: customers customerId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers ALTER COLUMN "customerId" SET DEFAULT nextval('public.customer_customer_id_seq1'::regclass);


--
-- Name: actors actor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT actor_pkey PRIMARY KEY ("actorId");


--
-- Name: addresses address_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT address_pkey PRIMARY KEY ("addressId");


--
-- Name: genres genre_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.genres
    ADD CONSTRAINT genre_pkey PRIMARY KEY ("genreId");


--
-- Name: cities city_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT city_pkey PRIMARY KEY ("cityId");


--
-- Name: countries country_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT country_pkey PRIMARY KEY ("countryId");


--
-- Name: customers customer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customer_pkey PRIMARY KEY ("customerId");


--
-- Name: castMembers film_actor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."castMembers"
    ADD CONSTRAINT film_actor_pkey PRIMARY KEY ("actorId", "filmId");


--
-- Name: filmGenre film_genre_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."filmGenre"
    ADD CONSTRAINT film_genre_pkey PRIMARY KEY ("filmId", "genreId");


--
-- Name: films film_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.films
    ADD CONSTRAINT film_pkey PRIMARY KEY ("filmId");


--
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY ("inventoryId");


--
-- Name: languages language_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.languages
    ADD CONSTRAINT language_pkey PRIMARY KEY ("languageId");


--
-- Name: rentals rental_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rentals
    ADD CONSTRAINT rental_pkey PRIMARY KEY ("rentalId");


--
-- Name: staff staff_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY ("staffId");


--
-- Name: stores store_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT store_pkey PRIMARY KEY ("storeId");


--
-- Name: film_fulltext_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX film_fulltext_idx ON public.films USING gist (fulltext);


--
-- Name: idx_actor_last_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_actor_last_name ON public.actors USING btree ("lastName");


--
-- Name: idx_fk_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_address_id ON public.customers USING btree ("addressId");


--
-- Name: idx_fk_city_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_city_id ON public.addresses USING btree ("cityId");


--
-- Name: idx_fk_country_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_country_id ON public.cities USING btree ("countryId");


--
-- Name: idx_fk_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_customer_id ON public.payments USING btree ("customerId");


--
-- Name: idx_fk_film_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_film_id ON public."castMembers" USING btree ("filmId");


--
-- Name: idx_fk_inventory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_inventory_id ON public.rentals USING btree ("inventoryId");


--
-- Name: idx_fk_language_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_language_id ON public.films USING btree ("languageId");


--
-- Name: idx_fk_original_language_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_original_language_id ON public.films USING btree ("originalLanguageId");


--
-- Name: idx_fk_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_staff_id ON public.payments USING btree ("staffId");


--
-- Name: idx_fk_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_store_id ON public.customers USING btree ("storeId");


--
-- Name: idx_last_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_last_name ON public.customers USING btree ("lastName");


--
-- Name: idx_store_id_film_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_store_id_film_id ON public.inventory USING btree ("storeId", "filmId");


--
-- Name: idx_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_title ON public.films USING btree (title);


--
-- Name: idx_unq_manager_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unq_manager_staff_id ON public.stores USING btree ("managerStaffId");


--
-- Name: idx_unq_rental_rental_date_inventory_id_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unq_rental_rental_date_inventory_id_customer_id ON public.rentals USING btree ("startDate", "inventoryId", "customerId");


--
-- Name: films film_fulltext_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER film_fulltext_trigger BEFORE INSERT OR UPDATE ON public.films FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('fulltext', 'pg_catalog.english', 'title', 'description');


--
-- Name: actors last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.actors FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: addresses last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.addresses FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: genres last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.genres FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: cities last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.cities FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: countries last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.countries FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: customers last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: films last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.films FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: castMembers last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public."castMembers" FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: filmGenre last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public."filmGenre" FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: inventory last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.inventory FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: languages last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.languages FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: rentals last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.rentals FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: staff last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.staff FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: stores last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.stores FOR EACH ROW EXECUTE PROCEDURE public.last_updated();


--
-- Name: addresses address_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT address_city_id_fkey FOREIGN KEY ("cityId") REFERENCES public.cities("cityId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: cities city_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT city_country_id_fkey FOREIGN KEY ("countryId") REFERENCES public.countries("countryId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: customers customer_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customer_address_id_fkey FOREIGN KEY ("addressId") REFERENCES public.addresses("addressId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: customers customer_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customer_store_id_fkey FOREIGN KEY ("storeId") REFERENCES public.stores("storeId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: castMembers film_actor_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."castMembers"
    ADD CONSTRAINT film_actor_actor_id_fkey FOREIGN KEY ("actorId") REFERENCES public.actors("actorId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: castMembers film_actor_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."castMembers"
    ADD CONSTRAINT film_actor_film_id_fkey FOREIGN KEY ("filmId") REFERENCES public.films("filmId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: filmGenre film_genre_genre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."filmGenre"
    ADD CONSTRAINT film_genre_genre_id_fkey FOREIGN KEY ("genreId") REFERENCES public.genres("genreId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: filmGenre film_genre_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."filmGenre"
    ADD CONSTRAINT film_genre_film_id_fkey FOREIGN KEY ("filmId") REFERENCES public.films("filmId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: films film_language_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.films
    ADD CONSTRAINT film_language_id_fkey FOREIGN KEY ("languageId") REFERENCES public.languages("languageId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: films film_original_language_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.films
    ADD CONSTRAINT film_original_language_id_fkey FOREIGN KEY ("originalLanguageId") REFERENCES public.languages("languageId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory inventory_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_film_id_fkey FOREIGN KEY ("filmId") REFERENCES public.films("filmId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory inventory_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_store_id_fkey FOREIGN KEY ("storeId") REFERENCES public.stores("storeId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rentals rental_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rentals
    ADD CONSTRAINT rental_customer_id_fkey FOREIGN KEY ("customerId") REFERENCES public.customers("customerId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rentals rental_inventory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rentals
    ADD CONSTRAINT rental_inventory_id_fkey FOREIGN KEY ("inventoryId") REFERENCES public.inventory("inventoryId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rentals rental_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rentals
    ADD CONSTRAINT rental_staff_id_fkey FOREIGN KEY ("staffId") REFERENCES public.staff("staffId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: staff staff_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_address_id_fkey FOREIGN KEY ("addressId") REFERENCES public.addresses("addressId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: staff staff_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_store_id_fkey FOREIGN KEY ("storeId") REFERENCES public.stores("storeId");


--
-- Name: stores store_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT store_address_id_fkey FOREIGN KEY ("addressId") REFERENCES public.addresses("addressId") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--
