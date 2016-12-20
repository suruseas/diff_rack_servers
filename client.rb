require 'mechanize'
require 'benchmark'
require 'pp'
require './stopwatch'

class Worker
  attr_reader :error_count
  def initialize(concurrencies)
    @concurrencies = concurrencies
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
    @error_count
  end
end

def start
  result = {}
  w = Worker.new(10)
  w.run!(1000)
  puts "error_count=#{w.error_count}"
end


COMMANDS = {
  thin:    'bundle exec thin start -C config/thin.yml',
  puma:    'bundle exec puma -C config/puma.rb',
  unicorn: 'bundle exec unicorn -c config/unicorn.rb',
}

s = Stopwatch.new
start
puts '-' * 40
s.elapsed_time