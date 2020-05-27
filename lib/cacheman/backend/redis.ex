defmodule Cacheman.Backend.Redis do
  def start_link(opts) do
    poolboy_config = [
      {:worker_module, Redix},
      {:size, opts.pool_size},
      {:max_overflow, 0}
    ]

    redix_config = [
      host: opts.host,
      port: opts.port
    ]

    :poolboy.start_link(poolboy_config, redix_config)
  end

  def get(conn, key) do
    :poolboy.transaction(conn, fn c ->
      Redix.command(c, ["GET", key])
    end)
  end

  def exists?(conn, key) do
    :poolboy.transaction(conn, fn c ->
      case Redix.command(c, ["EXISTS", key]) do
        {:ok, 1} -> true
        {:ok, 0} -> false
        _ -> false
      end
    end)
  end

  def put(conn, key, value, ttl) do
    :poolboy.transaction(conn, fn c ->
      case Redix.command(c, ["SET", key, value] ++ ttl_command(ttl)) do
        {:ok, "OK"} -> {:ok, value}
        e -> e
      end
    end)
  end

  def delete(conn, keys) do
    :poolboy.transaction(conn, fn c ->
      Redix.command(c, ["DEL"] ++ keys)
    end)
  end

  def clear(conn) do
    :poolboy.transaction(conn, fn c ->
      Redix.command(c, ["FLUSHALL"])
    end)
  end

  def ttl_command(ttl: :infinity), do: []
  def ttl_command(ttl: ttl), do: ["PX", "#{ttl}"]
end
