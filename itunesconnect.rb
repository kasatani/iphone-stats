# Download daily reports
#
# Usage: ItunesConnect.download_daily_reports(".", "test@example.com")

require 'fileutils'
require 'zlib'
require 'mechanize'

class ItunesConnect
  def initialize
    @agent = WWW::Mechanize.new
    @agent.follow_meta_refresh = true
  end
  
  def login(account, password)
    page = @agent.get("https://itunesconnect.apple.com/")
    form = page.forms[0]
    form.theAccountName = account
    form.theAccountPW = password
    page = form.submit
    unless page.link_with(:text => "Manage Your Applications")
      raise "Failed to log in"
    end
  end

  def logout
    @agent.page.form_with(:name => "signOutForm").submit
  end

  def daily_reports(final_date = nil)
    reports = []
    page = @agent.page.link_with(:text => "Sales/Trend Reports").click

    form = page.form_with(:name => "frmVendorPage")
    form.field_with(:value => "Select Date Type").value="Daily"
    form.field_with(:name => "hiddenDayOrWeekSelection").value="Daily"
    form.field_with(:name => "hiddenSubmitTypeName").value="ShowDropDown"
    form.submit

    date = final_date
    while result = daily_report(date)
      date, file = result
      reports << [date, file]
    end
    @agent.page.link_with(:text => "Home").click
    reports
  end

  private

  def daily_report(final_date)
    form = @agent.page.form_with(:name => "frmVendorPage")
    form.field_with(:name => "hiddenSubmitTypeName").value="Download"
    select = form.fields.last
    options = select.options
    options = options.sort_by{|option| ItunesConnect.parse_date(option.value)}
    options.each do |option|
      date = ItunesConnect.parse_date(option.value)
      if !final_date || final_date < date
        select.value = option.value
        file = form.submit
        puts "downloaded: #{file.filename}"
        sleep 1
        @agent.back
        return [date, file]
      end
    end
    nil
  end

  class << self
    def parse_date(date)
      if date =~ /^(\d{4})(\d{2})(\d{2})$/
        parsed = Date.new($1.to_i, $2.to_i, $3.to_i)
      elsif date =~ /^(\d{2})\/(\d{2})\/(\d{4})$/
        parsed = Date.new($3.to_i, $1.to_i, $2.to_i)
      else
        raise "unknown format"
      end
      parsed
    end

    def parse_file_date(file)
      if File.basename(file) =~ /^S_D_\d+_\d+_(\d{4})(\d{2})(\d{2})_/
        begin
          Date.new($1.to_i, $2.to_i, $3.to_i)
        rescue ArgumentError
          if File.basename(file) =~ /^S_D_\d+_\d+_(\d{2})(\d{2})(\d{4})_/
            Date.new($3.to_i, $1.to_i, $2.to_i)
          else
            nil
          end
        end
      else
        nil
      end
    end
    
    def echo_off
      require "termios"
      term = Termios.getattr($stdin)
      term.c_lflag &= ~Termios::ECHO
      Termios.setattr($stdin, Termios::TCSANOW, term)
    end

    def echo_on
      term = Termios.getattr($stdin)
      term.c_lflag |= Termios::ECHO
      Termios.setattr($stdin, Termios::TCSANOW, term)
    end

    def download_daily_reports(base_dir, account, password = nil)
      unless password
        begin
          echo_off
          print "Password: "
          password = $stdin.gets.chomp
          puts
        ensure
          echo_on
        end
      end
      max = nil
      Dir.glob("#{base_dir}/??????/*{.txt,.txt.gz}").each do |file|
        if date = parse_file_date(file)
          max = date if !max || max < date
        end
      end
      c = ItunesConnect.new
      c.login(account, password)
      c.daily_reports(max).each do |date, file|
        dir = File.join(base_dir, date.strftime("%Y%m"))
        FileUtils.mkdir_p(dir)
        filename = File.join(dir, file.filename)
        filename.sub!(/\.gz$/, "")
        open(filename, "w") do |f|
          f << file.body
        end
      end
      c.logout
      nil
    end
  end
end
