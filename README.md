# Cacheman

Cacheman is a Redis backed Rails.cache equivalent for Elixir applications.

The primary API for using Cacheman is Cacheman.fetch.

## Install

Add Cacheman to your mix file

``` elixir
defp deps do
  [
    {:cacheman, github: "renderedtext/ex-cacheman"}
  ]
end
```

## How to use

Add an instance of cache to your app's supervisor:

``` elixir
  cache_name = :app
  cache_opts = %{
    prefix: "example/",       # every key in the cache store will be prefixed with example/
    backend: %{
      type: :redis,           # redis for backend
      host: "localhost",      # redis instance is listening on localhost
      port: 6379,             # redis instance is listening on port 6379
      pool_size: 5            # 5 parallel connections are established to the cache server
    }
  }

  children = [
    {Cacheman, [cache_name, cache_opts]}
  ]
```

Fetch from the Cache, with a fallback function in case the entry is not found:

``` elixir
{:ok, dash} = Cacheman.fetch(:app, "users-#{user.id}-dashboard", fn ->
  {:ok, dashboard} = render_dashboard(user)
end)
```

The fallback function saves everything into the cache that has the
`{:ok, value}` format.

## Advanced usage (TTL, and low level get/put APIs)

TTL for entries:

``` elixir
{:ok, dash} = Cacheman.fetch(:app, "users-#{user.id}-dashboard", ttl: :timer.hours(6), fn -> render_dashboard(user) end)
```

Get a key:

``` elixir
{:ok, entry} = Cacheman.get(:app, "user-#{user.id}-dashboard")
```

Put values in cache:

``` elixir
{:ok, dashboard} = render_dashboard(user)

{:ok, _} = Cacheman.put(:app, "user-#{user.id}-dashboard", dashboard, ttl: :timer.hours(6))
```

## Multiplexing caches

Every Cacheman instance must define a cache key prefix. This allows multiplexing
of caches across multiple clients or areas of work.

Example, a dedicated namespace for user caches and project caches:

``` elixir
{:ok, _} = Cacheman.start_link(:user, %{
  prefix: "users/",
  backend: %{
    type: :redis,
    host: "redis",
    port: 6379,
    pool_size: 5
  }
})

{:ok, _} = Cacheman.start_link(:project, %{
  prefix: "projects/",
  backend: %{
    type: :redis,
    host: "redis",
    port: 6379,
    pool_size: 5
  }
})
```

## License

This software is licensed under [the Apache 2.0 license](LICENSE).
