select "c"."firstName",
        "c"."lastName",
        "p"."amount"
  from "payments" as "p"
  join "customers" as "c" using ("customerId")
order by "amount" desc
limit 10;
