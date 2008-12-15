#!/usr/bin/env ruby

require "date"

class Stat
  def init_country_codes
    @country_codes = {}
    open("#{File.dirname(__FILE__)}/country_codes.txt") do |f|
      f.readlines.each do |line|
        line.chomp!
        pair = line.split(/\s+/, 2)
        @country_codes[pair[0]] = pair[1]
      end
    end
    # p @country_codes
  end

  def initialize
    @date_cache = {}
    @countries = {}
    @dates = {}
    @total = 0
    init_country_codes
  end

  # Date.parse is expensive, so cache it
  def parse_date(date)
    @date_cache[date] ||= Date.parse(date)
  end

  def parse
    while line = $stdin.gets
      provider, prov_country, vendor, upc, isrc, show, title, label, product, units, royalty, begin_date, end_date, cust_curr, country = line.split(/\t/)
      next if "1" != product # don't count upgrades
      next if "Provider" == provider # skip header
      units = units.to_i
      @countries[country] ||= 0
      @countries[country] += units
      date = parse_date(begin_date)
      @dates[date] ||= 0
      @dates[date] += units
      @total += units
    end
  end

  def print_country(*args)
    top = args.first.to_i if args.size > 0
    data = @countries.to_a
    total = @total
    total_share = 0
    others = 0
    puts ["Rank", "Country", "Count", "Ratio%", "Cumulative%"].join("\t")
    data.sort_by{|d|-d[1]}.each_with_index do |pair, i|
      count = pair[1].to_i
      share = count.to_f / total * 100
      total_share += share
      if !top || i < top
        puts [i+1, @country_codes[pair[0]], count, 
              "%.2f" % share, 
              "%.2f" % total_share].join("\t")
      else
        others += count
      end
    end
    if top
      puts ["-", "Other", others, 
            "%.2f" % (others.to_f / total * 100),
            "%.2f" % total_share].join("\t")
    end
  end

  def print_date
    cumulative = 0
    puts ["Date", "Count", "Cumulative"].join("\t")
    @dates.keys.sort.each do |date|
      cumulative += @dates[date]
      puts [date.strftime("%Y-%m-%d"), @dates[date], cumulative].join("\t")
    end
  end

  def print_total
    puts @total
  end
end

stat = Stat.new
method = "print_#{ARGV[0]}"
if stat.respond_to?(method)
  args = ARGV[1..-1]
  stat.parse
  stat.send(method, *args)
else
  methods = stat.public_methods.select{|m|m=~/^print_/}.map{|m|m.sub(/^print_/,'')}.sort
  $stderr.puts "Usage: gzip -cd foo.gz bar.gz | #{$0} [#{methods.join("|")}]"
end
