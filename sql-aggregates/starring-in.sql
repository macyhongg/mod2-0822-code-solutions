-- genres of movies and how many that 'Lisa Monroe' are in
-- result set should be 3 sports films and 2 sci-fi films ++

select "g"."name" as "genre name",
    count (*) as "number of films"
    from "castMembers"
  join "actors" using ("actorId")
  join "filmGenre" using ("filmId")
  join "genres" as "g" using ("genreId")
    where "firstName" = 'Lisa'
    and "lastName" = 'Monroe'
  group by "genre name";


-- castMembers -- actorId, filmId
-- actors - firstName, lastName, actorId
-- films - filmId
-- filmGenre - filmId, genreId
-- genre - genreId, name
