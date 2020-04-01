defmodule Cacheman do
  def start_link(name, opts) do
    if opts.backend == :redis do
      {:ok, _} = Cacheman.Backend.Redis.start_link(name, opts)

      {:ok,
       %{
         backend_module: Cacheman.Backend.Redis,
         backend_pid: backend_pid,
         opts: opts
       }}
    end
  end

  def get(conn, key) do
    apply(conn.backend_module, :get, [conn.backend_pid, fully_qualified_key_name(conn, key)])
  end

  def put(conn, key, value), do: put(key, value, ttl: :infinity)

  def put(conn, key, value, ttl: ttl) do
    apply(conn.backend_module, :put, [
      conn.backend_pid,
      fully_qualified_key_name(conn, key),
      value,
      ttl
    ])
  end

  def fetch(conn, key, fallback), do: fetch(conn, key, [ttl: :infinity], fallback)

  def fetch(conn, key, options, fallback) do
    case get(conn, key) do
      {:ok, nil} ->
        value = fallback.()

        put(conn, key, value, options)

        {:ok, value}

      {:ok, value} ->
        {:ok, value}

      {:error, _} ->
        {:ok, fallback.()}
    end
  end

  def fully_qualified_key_name(conn, key) do
    conn.opts.prefix <> key
  end
end
