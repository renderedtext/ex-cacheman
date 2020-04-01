defmodule Cacheman do
  use GenServer

  def start_link(name, opts) do
    GenServer.start_link(name, opts)
  end

  def init(name, opts) do
    {:ok, backend} = start_backend(opts)

    {:ok, opts}
  end

  def start_backend(opts) do
    %{

    }
  end

  def backend(opts) do
    backend_name = :"cacheman_#{name}_backend"

    {:ok, backend} = Cacheman.Backend.Redis.start_link(name, host, port, pool_size)
  end

end

  def put(key, value) do
    put(key, value, ttl: :infinity)
  end

  def put(key, value, ttl: ttl) do
    command = [
      "SET",
      fully_qualified_key_name(key),
      value
    ]

    command =
      if ttl == :infinity do
        command
      else
        command ++ ["PX", "#{ttl}"]
      end

    {:ok, "OK"} = Cacheman.Redis.command(command)
    {:ok, value}
  end

  def get(key) do
    {:ok, content} =
      Cacheman.Redis.command([
        "GET",
        fully_qualified_key_name(key)
      ])

    {:ok, content}
  end

  def fetch(key, fallback) do
    fetch(key, [ttl: :infinity], fallback)
  end

  def fetch(key, options, fallback) do
    case get(key) do
      {:ok, nil} ->
        value = fallback.()

        put(key, value, options)

        {:ok, value}

      {:ok, value} ->
        {:ok, value}

      {:error, _} ->
        {:ok, fallback.()}
    end
  end

  def fully_qualified_key_name(key) do
    prefix <> key
  end

  defp prefix do
    Application.get_env(:cacheman, :prefix)
  end
end
