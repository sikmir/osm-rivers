#!/usr/bin/env bash
set -euo pipefail

# Usage: ./generate.sh [russia-latest.osm.pbf]
PBF="${1:-russia-latest.osm.pbf}"

WORKDIR=$(mktemp -d)
trap 'rm -rf "${WORKDIR}"' EXIT

# code:osm_relation_id:name
# Codes are three-letter Latin codes according to GOST 7.67-2024 (table 14).
# Autonomous okrugs missing in GOST 7.67-2024 use ISO 3166-2:RU codes (NEN, KHM, YAN).
regions=(
    "alt:144764:Алтайский край"
    "amu:147166:Амурская область"
    "ark:140337:Архангельская область"
    "ast:112819:Астраханская область"
    "bel:83184:Белгородская область"
    "bry:81997:Брянская область"
    "vla:72197:Владимирская область"
    "vog:77665:Волгоградская область"
    "vlg:115106:Вологодская область"
    "vor:72181:Воронежская область"
    "jew:147167:Еврейская автономная область"
    "zab:145730:Забайкальский край"
    "iva:85617:Ивановская область"
    "irk:145454:Иркутская область"
    "kab:109879:Кабардино-Балкарская Республика"
    "kag:103906:Калининградская область"
    "kal:81995:Калужская область"
    "kam:151233:Камчатский край"
    "kao:109878:Карачаево-Черкесская Республика"
    "kem:144763:Кемеровская область"
    "kir:115100:Кировская область"
    "kos:85963:Костромская область"
    "kra:108082:Краснодарский край"
    "kya:190090:Красноярский край"
    "kug:140290:Курганская область"
    "kur:72223:Курская область"
    "len:176095:Ленинградская область"
    "lip:72169:Липецкая область"
    "mag:151228:Магаданская область"
    "mow:102269:Москва"
    "mos:51490:Московская область"
    "mur:2099216:Мурманская область"
    "nen:274048:Ненецкий автономный округ"
    "niz:72195:Нижегородская область"
    "ngr:89331:Новгородская область"
    "nvs:140294:Новосибирская область"
    "oms:140292:Омская область"
    "ore:77669:Оренбургская область"
    "orl:72224:Орловская область"
    "pnz:72182:Пензенская область"
    "per:115135:Пермский край"
    "pri:151225:Приморский край"
    "psk:155262:Псковская область"
    "ady:253256:Республика Адыгея"
    "ali:145194:Республика Алтай"
    "bas:77677:Республика Башкортостан"
    "bur:145729:Республика Бурятия"
    "dag:109876:Республика Дагестан"
    "ing:253252:Республика Ингушетия"
    "kai:108083:Республика Калмыкия"
    "kar:393980:Республика Карелия"
    "kom:115136:Республика Коми"
    "kry:3795586:Республика Крым"
    "mar:115114:Республика Марий Эл"
    "mor:72196:Республика Мордовия"
    "sah:151234:Республика Саха (Якутия)"
    "nor:110032:Республика Северная Осетия — Алания"
    "tat:79374:Республика Татарстан"
    "tuv:145195:Республика Тыва"
    "khk:190911:Республика Хакасия"
    "ros:85606:Ростовская область"
    "rya:71950:Рязанская область"
    "sam:72194:Самарская область"
    "spb:337422:Санкт-Петербург"
    "sar:72193:Саратовская область"
    "sak:394235:Сахалинская область"
    "sve:79379:Свердловская область"
    "svs:3788485:Севастополь"
    "smo:81996:Смоленская область"
    "sta:108081:Ставропольский край"
    "tam:72180:Тамбовская область"
    "tve:2095259:Тверская область"
    "tom:140295:Томская область"
    "tul:81993:Тульская область"
    "tyu:140291:Тюменская область"
    "udm:115134:Удмуртская Республика"
    "uly:72192:Ульяновская область"
    "kha:151223:Хабаровский край"
    "khm:140296:Ханты-Мансийский автономный округ — Югра"
    "che:77687:Челябинская область"
    "cha:109877:Чеченская Республика"
    "chv:80513:Чувашская Республика"
    "chu:151231:Чукотский автономный округ"
    "yan:191706:Ямало-Ненецкий автономный округ"
    "yar:81994:Ярославская область"
)

# Parse OPL relations into CSV rows sorted by name
read -r -d '' OPL2CSV <<'EOF' || true
def unescape:
  gsub("%(?<h>[0-9a-fA-F]+)%";
    .h | ascii_downcase | explode
    | reduce .[] as $c (0; . * 16 + (if $c >= 97 then $c - 87 else $c - 48 end))
    | [.] | implode);
def field($p): map(select(startswith($p)))[0][1:] // "";
[inputs | split(" ") | {
  id: (.[0][1:] | tonumber),
  tags: (field("T") | if . == "" then {} else split(",") | map(split("=") | {key: (.[0] | unescape), value: (.[1] | unescape)}) | from_entries end),
  members: (field("M") | if . == "" then 0 else split(",") | length end)
}]
| map(select(.tags.type == "waterway"))
| sort_by(.tags.name // "")
| .[]
| [.id, .tags.name, .tags."name:ru", .tags.destination, .tags.wikidata, .tags.wikipedia, .tags."gvr:code", .members]
| @csv
EOF

echo "Filter ${PBF}..."
osmium tags-filter -O -o "${WORKDIR}/filtered.osm.pbf" "${PBF}" r/admin_level=4 r/waterway=river
osmium tags-filter -O -o "${WORKDIR}/boundaries.osm.pbf" "${WORKDIR}/filtered.osm.pbf" r/admin_level=4
osmium tags-filter -O -o "${WORKDIR}/rivers.osm.pbf" "${WORKDIR}/filtered.osm.pbf" r/waterway=river

echo "Build region polygons..."
mkdir -p "${WORKDIR}/polygons"
osmium export -f geojsonseq -x print_record_separator=false --geometry-types=polygon -a type,id \
  "${WORKDIR}/boundaries.osm.pbf" | \
  jq -r 'select(.properties."@type" == "relation") | "\(.properties."@id")\t\(tojson)"' | \
  awk -F'\t' -v dir="${WORKDIR}/polygons" '{ print $2 > (dir "/" $1 ".geojson") }'

echo "name,count" > index.csv

for region in "${regions[@]}"; do
    IFS=: read -r code osm_id name <<< "${region}"
    polygon="${WORKDIR}/polygons/${osm_id}.geojson"
    if [[ ! -s "${polygon}" ]]; then
        echo "[${code}] No complete boundary for relation ${osm_id} (${name}), skipped" >&2
        continue
    fi
    echo "[${code}] Extract ${name}..."
    osmium extract -O -s complete_ways -p "${polygon}" -o "${WORKDIR}/${code}.osm.pbf" "${WORKDIR}/rivers.osm.pbf"
    (echo "id,name,name:ru,destination,wikidata,wikipedia,gvr:code,members"; \
    osmium tags-filter -R -f opl,add_metadata=false -o - "${WORKDIR}/${code}.osm.pbf" r/waterway=river | \
      jq -nrR "${OPL2CSV}") > "${code}.csv"
    csv2html -c -t "${name}" "${code}.csv" | \
      sed 's|<tr><td>\([0-9]\+\)</td>|<tr><td><a href="https://www.openstreetmap.org/relation/\1">\1</a></td>|g' | \
      sed 's|<td>Q\([0-9]\+\)</td>|<td><a href="https://www.wikidata.org/wiki/Q\1">Q\1</a></td>|g' | \
      sed 's|<td>\([a-z]\{2\}\):\([^<]\+\)</td>|<td><a href="https://\1.wikipedia.org/wiki/\2">\1:\2</a></td>|g' | \
      sed 's|<td>\([0-9]\{23\}\)</td>|<td><a href="https://verum.icu/index.php?claster=gvr\&q=\1">\1</a></td>|g' > "${code}.html"
    echo "[${name}](${code}.html),$(($(wc -l < "${code}.csv") - 1))" >> index.csv
done

csv2html -c -t "Реки по регионам" index.csv | \
  sed 's|\[\([^]]*\)\](\([^)]*\))|<a href="\2">\1</a>|g' > index.html
