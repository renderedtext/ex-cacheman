defmodule Cacheman do
  use GenServer
  require Logger

  #
  # Cacheman API
  #

  def start_link(name, opts) do
    GenServer.start_link(__MODULE__, opts, name: full_process_name(name))
  end

  def full_process_name(name) do
    :"cacheman-client-#{name}"
  end

  def get(name, key) do
    GenServer.call(full_process_name(name), {:get, key})
  end

  @default_put_options [ttl: :infinity]

  def put(name, key, value, put_opts \\ @default_put_options) do
    GenServer.call(full_process_name(name), {:put, key, value, put_opts})
  end

  def fetch(name, key, fallback), do: fetch(name, key, @default_put_options, fallback)

  def fetch(name, key, put_opts, fallback) do
    case get(name, key) do
      {:ok, nil} ->
        value = fallback.()

        put(name, key, value, put_opts)

        {:ok, value}

      {:ok, value} ->
        {:ok, value}

      {:error, _} ->
        {:ok, fallback.()}
    end
  end

  #
  # GenServer impl
  #

  def init(opts) do
    if opts.backend.type != :redis do
      raise "TOOD"
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
