# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoltRb::WorkerPool do
  let(:logger) { Logger.new(IO::NULL) }
  subject(:pool) { described_class.new(size: 2, logger: logger) }

  after { pool.shutdown if pool.running? }

  # Wait until the block returns true or the deadline passes
  def wait_until(seconds = 2)
    deadline = Time.now + seconds
    sleep 0.01 until yield || Time.now > deadline
  end

  describe '#post' do
    it 'runs the job on a worker thread' do
      pool.start
      seen = nil
      pool.post { seen = Thread.current }
      wait_until { seen }
      expect(seen).not_to be_nil
      expect(seen).not_to eq(Thread.current)
    end

    it 'runs jobs at the same time up to the pool size' do
      pool.start
      gate = Queue.new
      started = Queue.new
      2.times { pool.post { started << true; gate.pop } }
      wait_until { started.size == 2 }
      expect(started.size).to eq(2)
      2.times { gate << true }
    end

    it 'keeps working after a job raises' do
      pool.start
      done = false
      pool.post { raise 'boom' }
      pool.post { done = true }
      wait_until { done }
      expect(done).to be true
    end

    it 'runs the job inline when the pool is not started' do
      seen = nil
      pool.post { seen = Thread.current }
      expect(seen).to eq(Thread.current)
    end
  end

  describe '#shutdown' do
    it 'finishes queued jobs before it returns' do
      pool.start
      count = 0
      mutex = Mutex.new
      10.times { pool.post { sleep 0.01; mutex.synchronize { count += 1 } } }
      pool.shutdown
      expect(count).to eq(10)
    end

    it 'marks the pool as not running' do
      pool.start
      pool.shutdown
      expect(pool.running?).to be false
    end

    it 'returns even when a job does not finish in time' do
      pool = described_class.new(size: 1, logger: logger, shutdown_timeout: 0.05)
      pool.start
      pool.post { sleep 5 }
      sleep 0.01
      expect { pool.shutdown }.not_to raise_error
      expect(pool.running?).to be false
    end
  end
end
