# frozen_string_literal: true

module BoltRb
  # Fixed-size pool of threads that run handler jobs.
  #
  # The Socket Mode client reads frames on one thread. Handlers that
  # wait on the network must not run on that thread, or pings and later
  # events stall behind them. The App posts each event to this pool
  # and the socket thread returns to reading at once.
  #
  # @example
  #   pool = BoltRb::WorkerPool.new(size: 4, logger: BoltRb.logger)
  #   pool.start
  #   pool.post { do_slow_work }
  #   pool.shutdown
  class WorkerPool
    # @return [Integer] Number of worker threads
    attr_reader :size

    # Creates a new pool. Call #start to spawn the threads.
    #
    # @param size [Integer] Number of worker threads
    # @param logger [Logger] Logger for job errors
    # @param shutdown_timeout [Numeric] Seconds to wait for each worker on shutdown
    def initialize(size:, logger:, shutdown_timeout: 30)
      @size = size
      @logger = logger
      @shutdown_timeout = shutdown_timeout
      @queue = nil
      @threads = []
      @running = false
    end

    # Spawns the worker threads
    #
    # @return [void]
    def start
      return if @running

      @queue = Queue.new
      @running = true
      @threads = Array.new(size) { |index| spawn_worker(index) }
    end

    # Queues a job for a worker thread
    #
    # If the pool is not running, the job runs on the calling thread.
    #
    # @yield The job to run
    # @return [void]
    def post(&job)
      if @running
        @queue << job
      else
        run_job(job)
      end
    end

    # Stops accepting jobs, finishes queued jobs, and joins the workers
    #
    # Workers that do not finish inside the shutdown timeout are left to
    # exit on their own. The pool reports not running either way.
    #
    # @return [void]
    def shutdown
      return unless @running

      @running = false
      @queue.close
      @threads.each do |thread|
        next if thread.join(@shutdown_timeout)

        @logger.warn "[WorkerPool] #{thread.name} did not finish within #{@shutdown_timeout}s"
      end
      @threads = []
    end

    # @return [Boolean] Whether the pool accepts jobs
    def running?
      @running
    end

    # @return [Integer] Number of jobs waiting for a worker
    def queue_size
      @queue ? @queue.size : 0
    end

    private

    # Creates one worker thread that drains the queue until it closes
    #
    # @param index [Integer] Worker number, used in the thread name
    # @return [Thread]
    def spawn_worker(index)
      Thread.new do
        Thread.current.name = "bolt-rb-worker-#{index}"
        while (job = @queue.pop)
          run_job(job)
        end
      end
    end

    # Runs one job and logs any error it raises
    #
    # @param job [Proc]
    # @return [void]
    def run_job(job)
      job.call
    rescue StandardError => e
      @logger.error "[WorkerPool] Job failed: #{e.class}: #{e.message}"
      @logger.error e.backtrace.first(5).join("\n") if e.backtrace
    end
  end
end
