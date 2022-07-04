.PHONY: server
server:
	@hugo server -e development --config config.toml,config.dev.toml -v --buildDrafts --buildFuture --disableFastRender

.PHONY: dev
dev:
	@hugo -e development --config config.toml,config.dev.toml -v --gc --cleanDestinationDir --buildDrafts --buildFuture

.PHONY: prod
prod:
	@hugo -e production -v --minify --gc --cleanDestinationDir