defmodule CachemanTest do
  use ExUnit.Case
  doctest Cacheman

  setup_all do
    {:ok, _} =
      Cacheman.start_link(:good, %{
        prefix: "good/",
        backend: %{
          type: :redis,
          host: "redis-1",
          port: 6379,
          pool_size: 5
        }
      })

    {:ok, _} =
      Cacheman.start_link(:broken, %{
        prefix: "broken/",
        backend: %{
          type: :redis,
          host: "fake-host",
          port: 6379,
          pool_size: 5
        }
      })

    :ok
  end

  describe "redis" do
    test "put and get" do
      content = "hello"

      assert {:ok, value} = Cacheman.put(:good, "test1", content)
      assert value == content

      assert {:ok, value} = Cacheman.get(:good, "test1")
      assert value == content
    end

    test "fetch and store" do
      key = "test-#{System.unique_integer([:positive])}"

      # at the start, there is no value
      assert {:ok, nil} = Cacheman.get(:good, key)

      # if we fetch on empty value, the fallback function is executed
      assert {:ok, "hello"} = Cacheman.fetch(:good, key, fn -> {:ok, "hello"} end)

      # the value of the fallback is saved into the cache
      assert {:ok, "hello"} = Cacheman.get(:good, key)

      # when the value is present, the fallback is not evaluated
      assert {:ok, "hello"} = Cacheman.fetch(:good, key, fn -> {:ok, "this-is-not-used"} end)
    end

    test "TTL for keys" do
      key = "test-#{System.unique_integer([:positive])}"
      ttl = :timer.seconds(1)

      assert {:ok, "hello"} = Cacheman.put(:good, key, "hello", ttl: ttl)

      # key is still available after 200 millis
      :timer.sleep(200)
      assert {:ok, "hello"} = Cacheman.get(:good, key)
      #
      # key is not available after TTL second
      :timer.sleep(1000)
      assert {:ok, nil} = Cacheman.get(:good, key)
    end

    test "exists?" do
      content = "hello"

      assert {:ok, value} = Cacheman.put(:good, "test1", content)
      assert value == content

      assert Cacheman.exists?(:good, "test1")
      refute Cacheman.exists?(:good, "test2")
    end
  end

  describe "redis - broken" do
    test "put and get" do
      assert {:ok, nil} = Cacheman.get(:broken, "test1")
    end

    test "fetch and store" do
      key = "test-#{System.unique_integer([:positive])}"

      assert {:ok, nil} = Cacheman.get(:broken, key)
      assert {:ok, "hello"} = Cacheman.fetch(:broken, key, fn -> {:ok, "hello"} end)
      assert {:ok, nil} = Cacheman.get(:broken, key)

      assert {:ok, "this-is-not-used"} =
               Cacheman.fetch(:broken, key, fn -> {:ok, "this-is-not-used"} end)
    end

    test "TTL for keys" do
      key = "test-#{System.unique_integer([:positive])}"
      ttl = :timer.seconds(1)

      assert {:error, _} = Cacheman.put(:broken, key, "hello", ttl: ttl)
      assert {:ok, nil} = Cacheman.get(:broken, key)
      assert {:ok, nil} = Cacheman.get(:broken, key)
    end

    test "exists?" do
      assert Cacheman.exists?(:broken, "test1") == false
    end
  end
end
