SHELL := /bin/bash
DATE := $(shell date "+%Y%m%d%H%M%S")

.PHONY: ansible tilemaker icons

tiles/norway.osm.pbf:
	curl --create-dirs --fail https://download.geofabrik.de/europe/norway-latest.osm.pbf -o $@

tiles/drammen.osm.pbf: tiles/norway.osm.pbf
	osmium extract tiles/norway.osm.pbf --polygon tilemaker/drammen.geojson -o $@ --overwrite

tilemaker: tiles/drammen.osm.pbf icons
	cp tilemaker/* tiles
	jq '. | .settings.filemetadata.tiles=["http://localhost:8123/{z}/{x}/{y}.pbf"]' tilemaker/config-openmaptiles.json > tiles/temp.json
	mv tiles/temp.json tiles/config-openmaptiles.json

	podman run \
		-it \
		-v $(PWD)/tiles/:/srv:z \
		--name tilemaker-map \
		--rm \
		docker.io/stadtnavi/tilemaker:523fb9b2cfa0d85cd8e0948bf97d02e2040e8144\
		/srv/drammen.osm.pbf \
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
