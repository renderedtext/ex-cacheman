.PHONY: lint build test

setup:
	docker-compose build
	docker-compose run -e MIX_ENV=test app mix deps.get
	docker-compose run -e MIX_ENV=test app mix deps.compile

test:
	docker-compose run -e MIX_ENV=test app mix test $(FILE) $(FILTER) --trace

console:
	docker-compose run -e MIX_ENV=test app iex -S mix
