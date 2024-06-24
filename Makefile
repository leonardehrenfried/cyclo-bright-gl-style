SHELL := /bin/bash
DATE := $(shell date "+%Y%m%d%H%M%S")

.PHONY: ansible tilemaker icons

tiles/berlin.osm.pbf:
	curl --create-dirs --fail https://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf -o $@

tiles/kreuzberg.osm.pbf: tiles/berlin.osm.pbf
	osmium extract tiles/berlin.osm.pbf --polygon tilemaker/berlin.geojson -o $@ --overwrite

tilemaker: tiles/kreuzberg.osm.pbf icons
	cp tilemaker/* tiles
	jq '. | .settings.filemetadata.tiles=["http://localhost:8123/{z}/{x}/{y}.pbf"]' tilemaker/config-openmaptiles.json > tiles/temp.json
	mv tiles/temp.json tiles/config-openmaptiles.json

	podman run \
		-it \
		-v $(PWD)/tiles/:/srv:z \
		--name tilemaker-map \
		--rm \
		ghcr.io/leonardehrenfried/tilemaker:latest \
		/srv/kreuzberg.osm.pbf \
		--output=/srv/tiles/  \
		--config=/srv/config-openmaptiles.json \
		--process=/srv/process-openmaptiles.lua

	cp -r sprite* tiles/tiles/

	cp index.html tiles/tiles

	jinja2 style.jinja.json -o style.json
	jq '. | .sources.openmaptiles.url="http://localhost:8123/metadata.json" | .sprite="http://localhost:8123/sprite"' style.json > tiles/tiles/style.json

	python3 -m http.server 8123 --directory tiles/tiles/


icons:
	spritezero sprite icons
	spritezero --retina sprite@2x icons
