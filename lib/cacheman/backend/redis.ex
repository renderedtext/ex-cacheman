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

  def get_batch(conn, keys) when is_list(keys) do
    list_of_commands =
      Enum.map(keys, fn key ->
        ["GET", key]
      end)

    :poolboy.transaction(conn, fn c ->
      Redix.pipeline(c, list_of_commands)
    end)
  end

  def exists?(conn, key) do
    :poolboy.transaction(conn, fn c ->
      case Redix.command(c, ["EXISTS", key]) do
        {:ok, 1} -> true
        {:ok, 0} -> false
        {:error, reason} -> reason
      end
    end)
  end

  def put(conn, key, value, opts) do
    :poolboy.transaction(conn, fn c ->
      case Redix.command(c, ["SET", key, value] ++ ttl_command(opts[:ttl]),
             timeout: opts[:timeout]
           ) do
        {:ok, "OK"} -> {:ok, value}
        e -> e
      end
    end)
  end

  def put_batch(conn, key_value_pairs, opts) when is_list(key_value_pairs) do
    list_of_commands =
      Enum.map(key_value_pairs, fn {key, value} ->
        ["SET", key, value] ++ ttl_command(opts[:ttl])
      end)

    :poolboy.transaction(conn, fn c ->
      Redix.pipeline(c, list_of_commands, timeout: opts[:timeout])
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

  def ttl_command(:infinity), do: []
  def ttl_command(ttl), do: ["PX", "#{ttl}"]
end
