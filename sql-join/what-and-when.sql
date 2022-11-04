select "f"."releaseYear",
        "g"."name" as "genre"
  from "films" as "f"
  join "filmGenre" using ("filmId")
  join "genres" as "g" using ("genreId")
  where "title" = 'Boogie Amelie';
