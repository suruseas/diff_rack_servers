require 'benchmark'
require 'mechanize'
require 'pp'

class Worker
  attr_reader :error_count, :process_count

  COMMANDS = {
    thin:    'bundle exec thin start -C config/thin.yml',
    puma:    'bundle exec puma -C config/puma.rb',
    unicorn: 'bundle exec unicorn -c config/unicorn.rb',
  }

  def initialize(command, concurrencies)
    @command = command
    @concurrencies = concurrencies
  end

  def start_server
    @server = fork do
      [STDOUT, STDERR].each { |o| o.reopen '/dev/null' }
      exec COMMANDS[@command]
    end
    # wait
    sleep 10
    # count server process
    @process_count = `ps -ef | grep #{@command.to_s} | grep -v grep | wc -l`.strip.to_i
  end
  def run!(loop_count)
    @error_count = 0
    threads = []
    @concurrencies.times do
      threads.push(Thread.new(self) { self.execute(loop_count / @concurrencies) })
    end
     threads.each {|t| t.join}
  end
  def execute(loop_count)
    agent = Mechanize.new
    loop_count.times do 
      begin
        ['set', 'get'].each do |path|
          page = agent.get("http://127.0.0.1:8080/#{path}")
          raise 'invalid request' unless page.code.to_i == 200
        end
      rescue => ex
        @error_count += 1
      end
    end
  end
  def kill
    Process.kill 'KILL', @server
  end
end

result = {}

REQUEST_COUNT  = 1000

Benchmark.bm 10 do |r|
  [:thin, :puma, :unicorn].each do |cmd|
    begin
      w = Worker.new(cmd, 50)
      w.start_server
      r.report cmd do
        w.run!(REQUEST_COUNT)
      end
      result[cmd] = {
        process_count: w.process_count,
        error_count:   w.error_count
      }
    ensure
      w.kill
      # wait
      sleep 10
    end
  end
end

puts "-" * 40
pp result

