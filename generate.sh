#!/usr/bin/env bash

regions=(
    "arkhangelsk:Архангельская область"
    "vladimir:Владимирская область"
    "vologda:Вологодская область"
    "ivanovo:Ивановская область"
    "kaliningrad:Калининградская область"
    "kirov:Кировская область"
    "kostroma:Костромская_область"
    "leningrad:Ленинградская область"
    "moscow:Московская область"
    "murmansk:Мурманская область"
    "nizhny-novgorod:Нижегородская область"
    "nenets:Ненецкий автономный округ"
    "novgorod:Новгородская область"
    "perm:Пермский край"
    "pskov:Псковская область"
    "karelia:Республика Карелия"
    "komi:Республика Коми"
    "tver:Тверская область"
    "smolensk:Смоленская область"
    "yaroslavl:Ярославская область"
)

echo "name,count" > index.csv

for region in "${regions[@]}"; do
    slug="${region%%:*}"
    name="${region#*:}"
    echo "[${slug}] Search ${name}..."
    osm_id=$(curl -sG "https://nominatim.openstreetmap.org/search" --data-urlencode "format=json" --data-urlencode "q=${name}" | jq '.[0].osm_id')
    echo "[${slug}] Run query on ${osm_id}..."
    (echo "id,name,name:ru,destination,wikidata,wikipedia,gvr:code,members"; \
    curl -s --compressed https://overpass-api.de/api/interpreter \
      --data-urlencode 'data=[out:json][timeout:25];area(id:'$((3600000000+osm_id))')->.searchArea;nwr["type"="waterway"]["waterway"="river"](area.searchArea);out geom;' | \
      jq -r '.elements|sort_by(.tags.name // "")|.[]|[.id,.tags.name,.tags."name:ru",.tags.destination,.tags.wikidata,.tags.wikipedia,.tags."gvr:code",(.members|length)]|@csv') > "${slug}.csv"
    echo "[${slug}] Convert to html..."
    csv2html -c -t "${name}" "${slug}.csv" | \
      sed 's|<tr><td>\([0-9]\+\)</td>|<tr><td><a href="https://www.openstreetmap.org/relation/\1">\1</a></td>|g' | \
      sed 's|<td>Q\([0-9]\+\)</td>|<td><a href="https://www.wikidata.org/wiki/Q\1">Q\1</a></td>|g' | \
      sed 's|<td>\([a-z]\{2\}\):\([^<]\+\)</td>|<td><a href="https://\1.wikipedia.org/wiki/\2">\1:\2</a></td>|g' | \
      sed 's|<td>\([0-9]\{23\}\)</td>|<td><a href="https://verum.icu/index.php?claster=gvr\&q=\1">\1</a></td>|g' > "${slug}.html"
    echo "[${name}](${slug}.html),$(wc -l < "${slug}.csv")" >> index.csv
done

csv2html -c -t "Реки по регионам" index.csv | \
  sed 's|\[\([^]]*\)\](\([^)]*\))|<a href="\2">\1</a>|g' > index.html
