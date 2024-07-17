defmodule CachemanTest do
  use ExUnit.Case
  import Mock
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

    {:ok, _} =
      Cacheman.start_link(:good_auth, %{
        prefix: "good_auth/",
        backend: %{
          type: :redis,
          host: "redis-2",
          port: 6379,
          password: "my-pass",
          pool_size: 5
        }
      })

    {:ok, _} =
      Cacheman.start_link(:bad_auth, %{
        prefix: "bad_auth/",
        backend: %{
          type: :redis,
          host: "redis-2",
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

    test "put_batch" do
      key1 = "test-#{:rand.uniform(10_000)}"
      key2 = "test-#{:rand.uniform(10_000)}"

      assert {:ok, nil} = Cacheman.get(:good, key1)
      assert {:ok, nil} = Cacheman.get(:good, key2)

      assert {:ok, 2} = Cacheman.put_batch(:good, [{key1, "value1"}, {key2, "value2"}])

      assert {:ok, "value1"} = Cacheman.get(:good, key1)
      assert {:ok, "value2"} = Cacheman.get(:good, key2)
    end

    test "put_batch with TTL" do
      key1 = "test-#{:rand.uniform(10_000)}"
      key2 = "test-#{:rand.uniform(10_000)}"

      assert {:ok, nil} = Cacheman.get(:good, key1)
      assert {:ok, nil} = Cacheman.get(:good, key2)

      ttl = :timer.seconds(1)

      assert {:ok, 2} = Cacheman.put_batch(:good, [{key1, "value1"}, {key2, "value2"}], ttl: ttl)

      assert {:ok, "value1"} = Cacheman.get(:good, key1)
      assert {:ok, "value2"} = Cacheman.get(:good, key2)

      :timer.sleep(ttl)

      assert {:ok, nil} = Cacheman.get(:good, key1)
      assert {:ok, nil} = Cacheman.get(:good, key2)
    end

    test "put_batch with custom timeout" do
      timeout = 10_000

      with_mock Redix, [],
        pipeline: fn _, _, opts ->
          :timer.sleep(trunc(timeout * 0.7))
          assert opts[:timeout] == timeout
        end do
        assert Cacheman.put_batch(:good, [{"test_key", "test_value"}], timeout: timeout)
      end
    end

    test "get_batch" do
      key1 = "test-#{:rand.uniform(10_000)}"
      key2 = "test-#{:rand.uniform(10_000)}"

      assert {:ok, 2} = Cacheman.put_batch(:good, [{key1, "value1"}, {key2, "value2"}])

      assert {:ok, ["value1", "value2"]} = Cacheman.get_batch(:good, [key1, key2])
    end

    test "fetch and store" do
      key = "test-#{:rand.uniform(10_000)}"

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
      key = "test-#{:rand.uniform(10_000)}"
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

    test "clear" do
      Cacheman.put(:good, "random-key", "hey")
      assert Cacheman.exists?(:good, "random-key")
      Cacheman.clear(:good)
      refute Cacheman.exists?(:good, "random-key")
    end

    test "delete key" do
      Cacheman.put(:good, "key1", "hehe")
      assert Cacheman.exists?(:good, "key1")
      Cacheman.delete(:good, "key1")
      refute Cacheman.exists?(:good, "key1")
    end

    test "delete [keys]" do
      Cacheman.put(:good, "key1", "it doesn't matter")
      Cacheman.put(:good, "key2", "it doesn't matter")
      Cacheman.put(:good, "key3", "it doesn't matter")

      assert Cacheman.exists?(:good, "key1")
      assert Cacheman.exists?(:good, "key1")
      assert Cacheman.exists?(:good, "key1")

      Cacheman.delete(:good, ["key1", "key2"])

      refute Cacheman.exists?(:good, "key1")
      refute Cacheman.exists?(:good, "key2")
      assert Cacheman.exists?(:good, "key3")
    end
  end

  describe "redis - broken" do
    test "put and get" do
      assert {:ok, nil} = Cacheman.get(:broken, "test1")
    end

    test "put_batch cant reach redis server" do
      key1 = "test-#{:rand.uniform(10_000)}"
      key2 = "test-#{:rand.uniform(10_000)}"

      assert {:ok, nil} = Cacheman.get(:good, key1)
      assert {:ok, nil} = Cacheman.get(:good, key2)

      assert {:error, _} = Cacheman.put_batch(:broken, [{key1, "value1"}, {key2, "value2"}])

      assert {:ok, nil} = Cacheman.get(:good, key1)
      assert {:ok, nil} = Cacheman.get(:good, key2)
    end

    test "put_batch with custom timeout excided" do
      timeout = 10_000

      with_mock Redix, [],
        pipeline: fn _, _, opts ->
          assert opts[:timeout] == timeout
          :timer.sleep(trunc(timeout * 1.2))
        end do
        catch_exit(Cacheman.put_batch(:broken, [{"test_key", "test_value"}], timeout: timeout))
      end
    end

    test "get_batch" do
      key1 = "test-#{:rand.uniform(10_000)}"
      key2 = "test-#{:rand.uniform(10_000)}"

      assert {:ok, [nil, nil]} = Cacheman.get_batch(:broken, [key1, key2])
    end

    test "fetch and store" do
      key = "test-#{:rand.uniform(10_000)}"

      assert {:ok, nil} = Cacheman.get(:broken, key)

      assert {:ok, "hello"} =
               Cacheman.fetch(:broken, key, fn passed_key ->
                 assert passed_key == key
                 {:ok, "hello"}
               end)

      assert {:ok, nil} = Cacheman.get(:broken, key)

      assert {:ok, "this-is-not-used"} =
               Cacheman.fetch(:broken, key, fn _ -> {:ok, "this-is-not-used"} end)
    end

    test "TTL for keys" do
      key = "test-#{:rand.uniform(10_000)}"
      ttl = :timer.seconds(1)

      assert {:error, _} = Cacheman.put(:broken, key, "hello", ttl: ttl)
      assert {:ok, nil} = Cacheman.get(:broken, key)
      assert {:ok, nil} = Cacheman.get(:broken, key)
    end

    test "exists?" do
      assert Cacheman.exists?(:broken, "test1") == false
    end
  end

  describe "redis - good auth" do
    test "put and get good auth" do
      content = "hello"

      assert {:ok, value} = Cacheman.put(:good_auth, "test13", content)
      assert value == content

      assert {:ok, value} = Cacheman.get(:good_auth, "test13")
      assert value == content

      assert {:ok, value} = Cacheman.get(:bad_auth, "test13")
      assert value == nil
    end

    test "put_batch" do
      key1 = "test-#{:rand.uniform(10_000)}"
      key2 = "test-#{:rand.uniform(10_000)}"

      assert {:ok, nil} = Cacheman.get(:good_auth, key1)
      assert {:ok, nil} = Cacheman.get(:good_auth, key2)

      assert {:ok, 2} = Cacheman.put_batch(:good_auth, [{key1, "value1"}, {key2, "value2"}])

      assert {:ok, "value1"} = Cacheman.get(:good_auth, key1)
      assert {:ok, "value2"} = Cacheman.get(:good_auth, key2)
    end

    test "put_batch with TTL" do
      key1 = "test-#{:rand.uniform(10_000)}"
      key2 = "test-#{:rand.uniform(10_000)}"

      assert {:ok, nil} = Cacheman.get(:good_auth, key1)
      assert {:ok, nil} = Cacheman.get(:good_auth, key2)

      ttl = :timer.seconds(1)

      assert {:ok, 2} = Cacheman.put_batch(:good_auth, [{key1, "value1"}, {key2, "value2"}], ttl: ttl)

      assert {:ok, "value1"} = Cacheman.get(:good_auth, key1)
      assert {:ok, "value2"} = Cacheman.get(:good_auth, key2)

      :timer.sleep(ttl)

      assert {:ok, nil} = Cacheman.get(:good_auth, key1)
      assert {:ok, nil} = Cacheman.get(:good_auth, key2)
    end

    test "put_batch with custom timeout" do
      timeout = 10_000

      with_mock Redix, [],
        pipeline: fn _, _, opts ->
          :timer.sleep(trunc(timeout * 0.7))
          assert opts[:timeout] == timeout
        end do
        assert Cacheman.put_batch(:good_auth, [{"test_key", "test_value"}], timeout: timeout)
      end
    end

    test "get_batch" do
      key1 = "test-#{:rand.uniform(10_000)}"
      key2 = "test-#{:rand.uniform(10_000)}"

      assert {:ok, 2} = Cacheman.put_batch(:good_auth, [{key1, "value1"}, {key2, "value2"}])

      assert {:ok, ["value1", "value2"]} = Cacheman.get_batch(:good_auth, [key1, key2])
    end

    test "fetch and store" do
      key = "test-#{:rand.uniform(10_000)}"

      # at the start, there is no value
      assert {:ok, nil} = Cacheman.get(:good_auth, key)

      # if we fetch on empty value, the fallback function is executed
      assert {:ok, "hello"} = Cacheman.fetch(:good_auth, key, fn -> {:ok, "hello"} end)

      # the value of the fallback is saved into the cache
      assert {:ok, "hello"} = Cacheman.get(:good_auth, key)

      # when the value is present, the fallback is not evaluated
      assert {:ok, "hello"} = Cacheman.fetch(:good_auth, key, fn -> {:ok, "this-is-not-used"} end)
    end

    test "TTL for keys" do
      key = "test-#{:rand.uniform(10_000)}"
      ttl = :timer.seconds(1)

      assert {:ok, "hello"} = Cacheman.put(:good_auth, key, "hello", ttl: ttl)

      # key is still available after 200 millis
      :timer.sleep(200)
      assert {:ok, "hello"} = Cacheman.get(:good_auth, key)
      #
      # key is not available after TTL second
      :timer.sleep(1000)
      assert {:ok, nil} = Cacheman.get(:good_auth, key)
    end

    test "exists?" do
      content = "hello"

      assert {:ok, value} = Cacheman.put(:good_auth, "test1", content)
      assert value == content

      assert Cacheman.exists?(:good_auth, "test1")
      refute Cacheman.exists?(:good_auth, "test2")
    end

    test "clear" do
      Cacheman.put(:good_auth, "random-key", "hey")
      assert Cacheman.exists?(:good_auth, "random-key")
      Cacheman.clear(:good_auth)
      refute Cacheman.exists?(:good_auth, "random-key")
    end

    test "delete key" do
      Cacheman.put(:good_auth, "key1", "hehe")
      assert Cacheman.exists?(:good_auth, "key1")
      Cacheman.delete(:good_auth, "key1")
      refute Cacheman.exists?(:good_auth, "key1")
    end

    test "delete [keys]" do
      Cacheman.put(:good_auth, "key1", "it doesn't matter")
      Cacheman.put(:good_auth, "key2", "it doesn't matter")
      Cacheman.put(:good_auth, "key3", "it doesn't matter")

      assert Cacheman.exists?(:good_auth, "key1")
      assert Cacheman.exists?(:good_auth, "key1")
      assert Cacheman.exists?(:good_auth, "key1")

      Cacheman.delete(:good_auth, ["key1", "key2"])

      refute Cacheman.exists?(:good_auth, "key1")
      refute Cacheman.exists?(:good_auth, "key2")
      assert Cacheman.exists?(:good_auth, "key3")
    end
  end

  describe "redis - bad auth" do
    test "put and get" do
      key = "test11"
      content = "hello"

      assert {:error, %{message: "NOAUTH Authentication required."}} = Cacheman.put(:bad_auth, key, content)

      assert {:ok, nil} = Cacheman.get(:bad_auth, key)

      assert {:ok, value} = Cacheman.put(:good_auth, key, content)
      assert value == content

      assert {:ok, nil} = Cacheman.get(:bad_auth, key)
    end

    test "put and get bad auth" do
      key = "test10"
      content = "hello"

      assert {:error, %{message: "NOAUTH Authentication required."}} = Cacheman.put(:bad_auth, key, content)
      assert {:ok, nil} = Cacheman.get(:bad_auth, key)

      assert {:ok, value} = Cacheman.put(:good_auth, key, content)
      assert value == content

      assert {:ok, value} = Cacheman.get(:good_auth, key)
      assert value == content

      assert {:ok, nil} = Cacheman.get(:bad_auth, key)
    end

    test "put_batch cant reach redis server" do
      key1 = "test-#{:rand.uniform(10_000)}"
      key2 = "test-#{:rand.uniform(10_000)}"

      assert {:ok, nil} = Cacheman.get(:good_auth, key1)
      assert {:ok, nil} = Cacheman.get(:good_auth, key2)

      assert {:ok, 0} = Cacheman.put_batch(:bad_auth, [{key1, "value1"}, {key2, "value2"}])

      assert {:ok, nil} = Cacheman.get(:good_auth, key1)
      assert {:ok, nil} = Cacheman.get(:good_auth, key2)
    end

    test "put_batch with custom timeout excided" do
      timeout = 10_000

      with_mock Redix, [],
        pipeline: fn _, _, opts ->
          assert opts[:timeout] == timeout
          :timer.sleep(trunc(timeout * 1.2))
        end do
        catch_exit(Cacheman.put_batch(:bad_auth, [{"test_key", "test_value"}], timeout: timeout))
      end
    end

    test "get_batch" do
      key1 = "test-#{:rand.uniform(10_000)}"
      key2 = "test-#{:rand.uniform(10_000)}"

      assert {:ok, [%{message: "NOAUTH Authentication required."}, %{message: "NOAUTH Authentication required."},]} = Cacheman.get_batch(:bad_auth, [key1, key2])
    end

    test "fetch and store" do
      key = "test-#{:rand.uniform(10_000)}"

      assert {:ok, nil} = Cacheman.get(:bad_auth, key)

      assert {:ok, "hello"} =
               Cacheman.fetch(:bad_auth, key, fn passed_key ->
                 assert passed_key == key
                 {:ok, "hello"}
               end)

      assert {:ok, nil} = Cacheman.get(:bad_auth, key)

      assert {:ok, "this-is-not-used"} =
               Cacheman.fetch(:bad_auth, key, fn _ -> {:ok, "this-is-not-used"} end)
    end

    test "TTL for keys" do
      key = "test-#{:rand.uniform(10_000)}"
      ttl = :timer.seconds(1)

      assert {:error, _} = Cacheman.put(:bad_auth, key, "hello", ttl: ttl)
      assert {:ok, nil} = Cacheman.get(:bad_auth, key)
      assert {:ok, nil} = Cacheman.get(:bad_auth, key)
    end

    test "exists?" do
      assert Cacheman.exists?(:bad_auth, "test1") == false
    end

    test "delete key" do
      key = "test-del-1"
      content = "value"

      assert {:ok, value} = Cacheman.put(:good_auth, key, content)
      assert value == content

      assert {:error, %{message: "NOAUTH Authentication required."}} = Cacheman.delete(:bad_auth, key)
      assert Cacheman.exists?(:good_auth, key)
      refute Cacheman.exists?(:bad_auth, key)

      Cacheman.delete(:good_auth, key)
      refute Cacheman.exists?(:good_auth, key)
      refute Cacheman.exists?(:bad_auth, key)
    end
  end
end
