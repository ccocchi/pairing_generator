#! /usr/bin/ruby
# frozen_string_literal: true

require 'optparse'
require 'json'

begin
  content = File.read('db.json')
rescue Errno::ENOENT
  content = "{}"
end

db = JSON.parse(content)

options = {}
parser  = OptionParser.new do |opts|
  opts.banner = "Usage: tournament.rb [options] <arg>"

  opts.on('--set-results', '12w,14w,73w') do
    options[:mode] = :set_results
  end

  opts.on('--drop-player', '12,32') do
    options[:mode] = :drop_player
  end

  opts.on('--initialize-pool', '<spirit|witch> 12,345,23') do
    options[:mode] = :initialize_pool
  end

  opts.on('--pairing', 'Generate new pairing. Do not forget to validate it') do
    options[:mode] = :pairing
  end

  opts.on('--print-pairing', 'Print current pairing') do
    options[:mode] = :print_pairing
  end

  opts.on('--print-results', 'Print current leaderboard') do
    options[:mode] = :print_results
  end

end
parser.parse!

class Tournament
  attr_reader :db

  def initialize(db)
    @db = db
  end

  def initialize_pool(name, pool)
    raise ArgumentError, 'name should either be `spirit` or `witch`' if name != 'witch' && name != 'spirit'
    puts 'Cannot initialize an already started tournament' if @db['round']

    values = pool.split(',').map(&:strip)
    @db["#{name}_pool"] = values

    values.each do |seed|
      players[seed] = []
      results[seed] = 0
    end

    true
  end

  def set_results(values)
    values.split(',').each do |val|
      val.strip!
      seed = val[0..-2]

      unless @db['current_winners'].include?(seed)
        results[seed] += 1
        @db['current_winners'] << seed
      end
    end

    true
  end

  def drop_player(values)
    values.split(',').each do |val|
      val.strip!
      players.delete(val)
      results.delete(val)
      spirit_pool.delete(val)
      witch_pool.delete(val)
    end

    true
  end

  def results
    (@db['results'] || @db['results'] = Hash.new(0))
  end

  def players
    (@db['players'] || @db['players'] = Hash.new { |h, k| h[k] = [] })
  end

  def print_pairing
    if @db.key?('current_pairing')
      puts "Pairing round #{db['round']}:"
      @db['current_pairing'].each do |k, v|
        winner = @db['current_winners'].find { |e| e == k || e == v }
        print "#{k}\tvs\t#{v}"
        winner ? puts("\t winner=#{winner}") : puts
      end
    else
      puts 'No current pairing'
    end

    false
  end

  def pairing
    if @db['current_pairing'] && (diff = @db['current_pairing'].size - @db['current_winners'].size) > 0
      puts "Cannot generate new pairing, missing #{diff} result(s)"
      return false
    end

    res       = Hash.new
    groups    = results.group_by { |_, v| v }.each_with_object({}) { |(k, vs), h| h[k] = vs.map(&:first) }.to_a
    overflow  = []

    groups.each do |_, values|
      vs = values + overflow
      overflow = []

      splayers, wplayers = vs.partition { |v| spirit_pool.include?(v) }.map(&:shuffle!)

      while (splayer = splayers.pop) do
        i       = 0
        paired  = false
        while i < wplayers.length
          wplayer = wplayers[i]
          if players[splayer].include?(wplayer)
            i += 1
          else
            wplayers.delete(wplayer)
            res[splayer] = wplayer
            players[splayer] << wplayer
            paired = true
            break
          end
        end

        overflow << splayer unless paired
      end
      overflow.concat(wplayers) unless wplayers.empty?
    end

    puts "New pairing:"
    res.map { |k, v| puts "#{k}\tvs\t#{v}" }
    puts
    if overflow.any?
      puts "Players without pairing: #{overflow.join(' ')}"
      puts
    end
    puts "Pairing for toornament:"
    puts res.map { |k, v| "#{k}v#{v}" }.join(' ')
    puts

    puts 'Validate pairing? (y/n)'
    valid = gets.chomp.downcase

    if valid == 'y'
      @db['current_pairing'] = res
      @db['current_winners'] = []
      @db['round'] ||= 0
      @db['round'] += 1
      true
    else
      false
    end
  end

  def spirit_pool
    @db['spirit_pool']
  end

  def witch_pool
    @db['witch_pool']
  end

  def print_results
    if results.empty?
      puts 'No results yet'
    else
      puts results.sort { |(_, v1), (_, v2)| v2 <=> v1 }
                  .map { |k, v| "#{k}:\t#{v} victories" }
                  .join("\n")
    end

    false
  end
end

if !options[:mode]
  puts parser.help
  exit(1)
end

service = Tournament.new(db)
res     = false
begin
  res = service.public_send(options[:mode], *ARGV)
rescue ArgumentError
  puts parser.help
  exit(1)
end

if res
  file = File.open('db.json', 'w')
  file.puts(JSON.dump(service.db))
  file.close
end
