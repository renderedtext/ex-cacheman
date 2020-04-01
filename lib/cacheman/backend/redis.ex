defmodule Cacheman.Backend.Redis do
  def start_link(opts) do
    {:ok, conn} = Redix.start_link(host: opts.host, port: opts.port)
  end

  def get(conn, key) do
    Redix.command(conn, ["GET", key])
  end

  def put(conn, key, value, ttl) do
    case Redix.command(conn, ["SET", key, value] ++ ttl_command(ttl)) do
      {:ok, "OK"} -> {:ok, value}
      e -> e
    end
  end

  def ttl_command(ttl: :infinity), do: []
  def ttl_command(ttl: ttl), do: ["PX", "#{ttl}"]
end
