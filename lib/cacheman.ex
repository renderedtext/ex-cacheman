defmodule Cacheman do
  @doc """
  Cacheman is a Redis backed Rails.cache equivalent for Elixir applications.

  The primary API for using Cacheman is Cacheman.fetch.

  Example usage of Cacheman:

  1. Add an instance of cache to your app's supervisor:

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

  2. Fetch from the Cache, with a fallback function in case the entry is not found:

  {:ok, dash} = Cacheman.fetch(:app, "users-dashboard", fn ->
    {:ok, dashboard} = render_dashboard(user)

    dashboard
  end)

  Advanced usage include setting a TTL on the keys, and low level get/put APIs:

  1. TTL for entries:

  {:ok, dash} = Cacheman.fetch(:app, "users-dashboard", ttl: :timer.hours(6), fn ->
    {:ok, dashboard} = render_dashboard(user)

    dashboard
  end)

  2. Get a key:

  {:ok, entry} = Cacheman.get(:app, "user-dashboard")

  3. Put values in cache:

  {:ok, dashboard} = render_dashboard(user)

  {:ok, _} = Cacheman.put(:app, "user-dashboard", dashboard, ttl: :timer.hours(6))


  Every Cacheman instance must define a cache key prefix. This allows multiplexing
  of caches accross multiple clients or areas of work.

  Example, a dedicated namespace for user caches and project caches:

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
  """

  use GenServer
  require Logger

  #
  # Cacheman API
  #

  def start_link([name, opts]) do
    GenServer.start_link(__MODULE__, opts, name: full_process_name(name))
  end

  def start_link(name, opts) do
    GenServer.start_link(__MODULE__, opts, name: full_process_name(name))
  end

  @doc """
  Each cacheman process is has a registered name. For example the :app cache
  would be registered as "cacheman-client-app".
  """
  def full_process_name(name) do
    :"cacheman-client-#{name}"
  end

  @doc """
  Gets a value from the cache.

  {:ok, user} = Cacheman.get(:app, "user-id")

  The response can be one of the following:

   - {:ok, value}          - if the entry is found
   - {:ok, nil}            - if the entry is not-found
   - {:error, description} - if there was an error while communicating with cache backends
  """
  def get(name, key) do
    GenServer.call(full_process_name(name), {:get, key})
  end

  @default_put_options [ttl: :infinity]

  @doc """
  Puts a value into the cache.

  {:ok, user} = Cacheman.put(:app, "user-id", "hello-I-am-peter")

  The response can be one of the following:

   - {:ok, value}          - if the entry is sucessfully inserted
   - {:error, description} - if there was an error while communicating with cache backends

  Optionally, a TTL option can be passed to the put action:

  {:ok, user} = Cacheman.put(:app, "user-id", "hello-I-am-peter", ttl: :timer.minutes(5))

  Where in the previous example, the cache key will be storred for 5 minutes.

  Nil values are not storrable in the cache.
  """
  def put(name, key, value, put_opts \\ @default_put_options) do
    if value == nil do
      {:ok, nil}
    else
      GenServer.call(full_process_name(name), {:put, key, value, put_opts})
    end
  end

  @doc """
  Fetch is the main entrypoint for caching. The algorithm works like this:

  - if the cache key is found, it returns the found value
  - otherwise, it calculates the value of the fallback function
     - if the fallback result is {:ok, val}, it is storred in the cache and returned
     - otherwise, the vaue is returned and it is not storred in the cache
  """
  def fetch(name, key, fallback), do: fetch(name, key, @default_put_options, fallback)

  def fetch(name, key, put_opts, fallback) do
    case get(name, key) do
      {:ok, nil} ->
        case fallback.() do
          {:ok, value} ->
            put(name, key, value, put_opts)
            {:ok, value}

          e ->
            e
        end

      {:ok, value} ->
        {:ok, value}

      {:error, _} ->
        {:ok, fallback.()}
    end
  end

  def exists?(name, key) do
    GenServer.call(full_process_name(name), {:exists?, key})
  end

  #
  # GenServer impl
  #

  def init(opts) do
    if opts.backend.type != :redis do
      raise "Unknown backend type #{opts.backend.type}"
    end

    {:ok, backend} = Cacheman.Backend.Redis.start_link(opts.backend)

    {:ok,
     %{
       backend_module: Cacheman.Backend.Redis,
       backend_pid: backend,
       prefix: opts.prefix
     }}
  end

  def handle_call({:get, key}, _from, opts) do
    response =
      apply(opts.backend_module, :get, [
        opts.backend_pid,
        fully_qualified_key_name(opts, key)
      ])

    case response do
      {:ok, val} ->
        {:reply, {:ok, val}, opts}

      e ->
        Logger.error("Cacheman - #{inspect(e)}")
        {:reply, {:ok, nil}, opts}
    end
  end

  def handle_call({:exists?, key}, _from, opts) do
    response =
      apply(opts.backend_module, :exists?, [
        opts.backend_pid,
        fully_qualified_key_name(opts, key)
      ])

    {:reply, response, opts}
  end

  def handle_call({:put, key, value, put_opts}, _from, opts) do
    response =
      apply(opts.backend_module, :put, [
        opts.backend_pid,
        fully_qualified_key_name(opts, key),
        value,
        put_opts
      ])

    {:reply, response, opts}
  end

  def fully_qualified_key_name(opts, key), do: opts.prefix <> key
end
