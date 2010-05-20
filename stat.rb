#!/usr/bin/env ruby
#
#   Copyright 2008 Shinya Kasatani
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

require "date"

class Stat
  attr_accessor :date_type

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
    parsed = @date_cache[date]
    if parsed
      parsed
    else
      if date =~ /^(\d{4})(\d{2})(\d{2})$/
        parsed = Date.new($1.to_i, $2.to_i, $3.to_i)
      elsif date =~ /^(\d{2})\/(\d{2})\/(\d{4})$/
        parsed = Date.new($3.to_i, $1.to_i, $2.to_i)
      else
        raise "unknown format"
      end
      if :month == date_type
        parsed = Date.new(parsed.year, parsed.month)
      end
      @date_cache[date] = parsed
    end
  end

  def parse(input, options = {})
    while line = input.gets
      provider, prov_country, vendor, upc, isrc, show, title, label, product, units, royalty, begin_date, end_date, cust_curr, country = line.split(/\t/)
      next unless ["1", "IA1"].include?(product) # don't count upgrades
      next if "Provider" == provider # skip header
      if options[:app]
        next if options[:app] != vendor
      end
      units = units.to_i
      @countries[country] ||= 0
      @countries[country] += units
      date = parse_date(begin_date)
      @dates[date] ||= 0
      @dates[date] += units
      @total += units
    end
    self
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
if ARGV[0] == "-a"
  ARGV.shift
  app = ARGV.shift
end
if ARGV[0] == "-m"
  ARGV.shift
  stat.date_type = :month
end
method = "print_#{ARGV.shift}"
if stat.respond_to?(method)
  args = ARGV
  stat.parse($stdin, :app => app)
  stat.send(method, *args)
else
  methods = stat.public_methods.select{|m|m=~/^print_/}.map{|m|m.sub(/^print_/,'')}.sort
  $stderr.puts "Usage: gzip -cd foo.gz bar.gz | #{$0} [-a APP_SKU] {#{methods.join("|")}}"
end
