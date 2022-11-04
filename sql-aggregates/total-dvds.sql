-- total number of physical DVDs in "inventory"
-- include all DVDs in all stores

select count("inventoryId") as "total DVDs"
  from "inventory";
