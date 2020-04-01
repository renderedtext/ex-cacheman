defmodule Cacheman.Backend.Redis do
  def start_link(opts) do
    {:ok, conn} = Redix.start_link(host: opts.host, port: opts.port)
  end

  def get(conn, key) do
    Redix.command(conn, ["GET", key])
  end

  def put(conn, key, value, ttl) do
    Redix.command(conn, ["SET", key, value] ++ ttl_command(ttl))
  end

  def ttl_command(:infinity), do: []
  def ttl_command(ttl), do: ["PX", "#{ttl}"]
end
