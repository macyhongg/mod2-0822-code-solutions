select "filmId",
        "title"
  from "films"
  where "rentalRate" < 1
  limit 50;
