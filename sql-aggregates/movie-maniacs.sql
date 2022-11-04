-- first and last name of all customers, plus total amount they've spent on rentals
-- order by total paid, desc
-- Karl Seal should be first with $221.55 paid

select "c"."firstName",
        "c"."lastName",
        sum("amount") as "total amount paid"
    from "customers" as "c"
    join "payments" using ("customerId")
    group by "customerId"
    order by "total amount paid" desc;


-- rentals: rentalId, customerId
-- customers: customerId
-- payments: customerId, amount, rentalId
