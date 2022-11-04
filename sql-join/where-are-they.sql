select "a"."line1" as "street",
        "c"."name" as "city",
        "a"."district",
        "countries"."name" as "country"
  from "countries"
  join "cities" as "c" using ("countryId")
  join "addresses" as "a" using ("cityId");
