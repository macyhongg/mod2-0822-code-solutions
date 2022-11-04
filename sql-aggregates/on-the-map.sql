select "countries"."name",
  count("cities"."name") as "number of cities"
  from "cities"
  join "countries" using ("countryId")
  group by "countries"."name"
  order by "name";
