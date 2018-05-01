require_relative "helper"
require "ostruct"

describe Squirm do

  before { Squirm.disconnect }
  after  { Squirm.disconnect }

  it "should quote identifiers" do
    assert_equal '"table"', Squirm.quote_ident("table")
  end

  it "should be a module" do
    assert Squirm.is_a? Module
  end

  it "should evaluate a block inside an Executor instance" do
    assert_raises RuntimeError do
      Squirm do
        raise "SUCCESS" if self.class == Squirm::Executor
      end
    end
  end

  describe "#procedure" do
    it "should get a procedure instance and load it" do
      Squirm.connect $squirm_test_connection
      proc = Squirm.procedure "date", args: "abstime", schema: "pg_catalog"
      assert proc.kind_of? Squirm::Procedure
    end
  end

  describe "#connect" do
    it "should use a pool if given" do
      pool = OpenStruct.new
      Squirm.connect pool: pool
      assert_equal pool, Squirm.pool
    end

    it "should establish a connection pool" do
      Squirm.connect $squirm_test_connection
      assert !Squirm.pool.connections.empty?
    end

    it "should establish :pool_size connections" do
      Squirm.connect $squirm_test_connection.merge pool_size: 2
      assert_equal 2, Squirm.pool.connections.count
    end

    it "should set :timeout to the pool's timeout" do
      Squirm.connect $squirm_test_connection.merge timeout: 9999
      assert_equal 9999, Squirm.pool.timeout
    end
  end

  describe "#disconnect" do
    it "should close all connections" do
      mock = MiniTest::Mock.new
      mock.expect :close, nil
      Squirm.instance_variable_set :@pool, [mock]
      Squirm.disconnect
      mock.verify
    end
  end

  describe "#use" do
    it "should set a connection as a Thread local var only during yield" do
      connection = OpenStruct.new
      Squirm.instance_variable_set :@pool, Squirm::Pool.new
      Squirm.pool.checkin connection
      Squirm.use do |conn|
        assert_equal conn, Thread.current[:squirm_connection]
      end
      assert_nil Thread.current[:squirm_connection]
    end

    it "should use connection if given as an argument" do
      mock = Object.new
      Squirm.use(mock) do |conn|
        assert mock == conn
      end
    end
  end

  describe "#exec" do
    it "should execute a query" do
      Squirm.connect $squirm_test_connection
      Squirm.exec "SELECT 'world' as hello" do |result|
        assert_equal "world", result.getvalue(0,0)
      end
    end

    it "should use the thread local connection if set" do
      mock = MiniTest::Mock.new
      mock.expect(:exec, true, [String])
      begin
        Thread.current[:squirm_connection] = mock
        Squirm.exec "SELECT * FROM table"
        mock.verify
      ensure
        Thread.current[:squirm_connection] = nil
      end
    end
  end

  describe "#transaction" do
    it "should set the connection to a transaction state" do
      Squirm.connect $squirm_test_connection
      Squirm.transaction do |conn|
        assert_equal PG::Connection::PQTRANS_INTRANS, conn.transaction_status
      end
    end
  end

  describe "#rollback" do
    it "should exit the block" do
      Squirm.connect $squirm_test_connection
      Squirm.transaction do |conn|
        Squirm.rollback
        assert false, "rollback should have exited the block"
      end
    end
  end

end
