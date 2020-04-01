defmodule Cacheman.Backend.Redis.ConnectionPool do
  use Supervisor

  def start_link(opts) do
    children =
      for i <- 0..(pool_size() - 1) do
        name = :"#{name}_redix_#{i}"

        Supervisor.child_spec(
          {Redix, name: , host: host(), port: port()},
          id: {Redix, i}
        )
      end

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
