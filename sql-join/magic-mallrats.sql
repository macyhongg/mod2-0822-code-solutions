select "c"."firstName",
        "c"."lastName"
    from "customers" as "c"
  join "rentals" using ("customerId")
  join "inventory" using ("inventoryId")
  join "films" using ("filmId")
  where "title" = 'Magic Mallrats';
