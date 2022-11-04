select "a"."firstName",
        "a"."lastName"
    from "films"
    join "castMembers" using ("filmId")
    join "actors" as "a" using ("actorId")
    where "title" = 'Jersey Sassy';
