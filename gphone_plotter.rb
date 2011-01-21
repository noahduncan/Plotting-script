require 'time'
require 'date'


class UserInput
  attr_reader :ftp_server,:data_path,:plot_path,:quiet,:start_date,:end_date,:meters
  def initialize
    @errors = []
    @meters = []
    parse_args unless $*.nil?
    raise_exceptions unless @errors.empty?
    set_defaults
  end
  
  def parse_args
    help if $*.empty?
    $*.each do |a|
      case a
      when /^'/
        meter_hash = {}
        part = a.match(/'.*'/)[0]
        meter_hash['name'] = part[1..(part.size-2)]
        meter_hash['server'] = a.match(/\d\d?\d?\.\d\d?\d?\.\d\d?\d?\.\d\d?\d?/)[0]
        unless meter_hash['server']
          @errors = ["Invalid gPhone ip address"] 
          next
        end
        a.scan(/-[uPl]=[^\s.]*/).each do |arg|
          parts = arg.split '='
          case parts[0]
          when "--user", "-u"
            meter_hash['user'] = parts[1]
          when "--password", "-P"
            meter_hash['password'] = parts[1] 
          when "--location", "-l"
            meter_hash['location'] = parts[1]
          end
        end
        @meters << meter_hash
      when /:/
        parts = a.split ":"
        @start_date ||= Date.parse parts[0]
        @end_date ||= Date.parse parts[1]
      else
        parts = a.split('=')
        case parts[0]
        when "--ftp", "-f"
          @ftp_server = parts[1]
        when "--datafile", "-d"
          @data_path = parts[1]
        when "--plotname", "-p"
          @plot_path = parts[1]
        when "--quiet", "-q"
          @quiet = true
        when "--help", "-h", "-?"
          help
        end
      end 
    end
    puts @meters.inspect
  end
  
  def raise_exceptions
    @errors.map {|e| puts "Error: #{e}"}
    exit
  end
      
  def set_defaults
    @end_date ||= Date.today - 1
    @start_date ||= @end_date - 7
    @data_path ||= ""
    @plot_path ||= ""
    @quiet ||= false
  end
    
  def help
    print "usage: ruby gphone_plotter.rb [-f|--ftp=server_ip] [-d|datafile=path] [-p|--plotname=path]
     [-q|--quiet] [-?|-h|--help] [\"meter_name@server_ip -u|-user -P|--password -l|--location\"]... [start_date:end_date]
    
    This program takes the specified meters and servers from the user, downloads
    the necessary files (if found), plots the results, and (optionally) uploads the
    file to an ftp site.
    
    Modifiers:
      start_date, end_date      Time period to plot.  Default is 
                                7 days w/today as most recent
                                
       ___________________FTP_SERVER_CONFIGURATION_________________________________
      |                                                                            |
      |--ftp-server=             If desired, the ftp server to upload the plot to. |
      |                                                                            |
      |--ftp-user=               Ftp server username                               |
      |                                                                            |
      |--ftp-password=           Ftp server password                               |
      |____________________________________________________________________________|
                                
      -d, --datafile=path       path to where you want the data file saved
      
      -p, --plotname=path       Path to where you want the plot to be saved
      
      -q, --quiet               Force defaults, no prompts.
      
      -h, -?, --help            Display this help message
      
      -u, --user=               Username required to access meter's files
      
      -P, --password            Password required to access meter's files
      
      -l, --location            Location of meter
      
      "
      exit
  end
end

class Array
  def sum
    inject(0.0) { |result, el| result + el }
  end
  
  def mean
    sum / size
  end
end

class TsfFile
  attr_reader :name
  
  def initialize(name)
    @f = File.open(name,"r")
    @name = name
  end
  
  def get_data(cols="all")
    output = []
    @f.rewind
    if cols == "all"
      @f.each do |row|
        output << row.split
      end
    else
      @f.each do |row|
        next unless row.match /^\d/
        f_cols = row.split
        out_row = ""
        cols.each do |col|
          out_row << "#{f_cols[col]} "
        end
        output << out_row
      end
    end        
    output
  end
  
  def get_time_and_corrected_gravity_data
    output = []
    @f.rewind
    until @f.eof 
      cols = parse_row(@f.gets)
      output << cols unless cols === false
    end
    output
  end

  def check_data_integrity
    f_seconds = get_data([5])
    second_count = -1
    f_seconds.each do |f_second|
      # puts "f_second: #{f_second.to_i ==  0}  second_count:#{second_count == -1}"
      if f_second.to_i == 0
        unless (second_count % 60 == 59 || second_count == -1)
          puts "Data integrity check failed in #{@name}:line #{second_count+47}"
          exit
        end
      else
        unless (second_count+1) % 60 == f_second.to_i 
          puts "Data integrity check failed in #{@name}:line #{second_count+47}"
          exit
        end
      end
      second_count += 1
    end    
  end
  
  private
  def parse_row(data_str)
    return false unless data_str.match /^\d/
    cols =  data_str.split
    cor_grav = cols[6].to_f - cols[8].to_f
    output = [cols[0..2].join('-') + "-" + cols[3..5].join(":"), cor_grav]
    return output
  end
  #Too modular.  I think i can get away with just 
  #-make sure the latest 7 files are downloaded, 
  #---download any that aren't
  #---delete any that are not needed anymore
  #-rebuild data set
  #---process each file
  #-----parse out data
end

class DataSet
  attr_accessor :meterName, :server, :files, :location
  attr_reader :data_array
  
  def initialize(meterName, server, start_date, end_date, user = nil, password = nil, location = nil)
    @@now ||= Time.new
    @@today ||= Date.parse(@@now.getgm.to_s)
    @meterName = meterName
    @server = server
    @start_date = start_date
    @end_date = end_date
    @files = []
    @data_array = []
    @user = user
    @password = password
    @location = location
    
    i=0
    while i <= (@end_date-@start_date).to_i.abs do
      filename = "#{(@end_date-i).year}_#{"%03d" % (@end_date-i).yday.to_i}_#{@meterName}.tsf"
      if File.file?(filename)
        puts "#{filename} exists: skipping download."
      else
        download_data_file(filename)
      end
      @files << TsfFile.new(filename)
      i+=1
    end
  end
  
  def +(otherset)
    @data_array.empty? ? @data_array = otherset.data_array : @data_array |= otherset.data_array[1]
  end
  
  def download_data_file(filename)
    #download the .tsf file from the gphone computers using wget
    puts "Downloading: \"#{@server}/gmonitor_data/#{filename}\""
    `wget --user=#{@user} --password=#{@password} \"#{@server}/gmonitor_data/#{filename}\"`
  end
  
  def delete_irrelevant_data_files
    shell_file_names = Dir.glob("*#{meterName}.tsf")
    @files.each do |file|
      unless shell_file_names.include? file.name
        puts "Deleting: #{file.name}"
        File.delete(file.name)
      end
    end
  end
  
  def process_files
    @files.each do |file|
      puts "Processing #{file.name}..."
      # puts "\tChecking Data Integrity..."
      # file.check_data_integrity
      puts "\tExtracting Corrected Gravity Data..."
      file.get_time_and_corrected_gravity_data.each do |row|
        @data_array << row
      end
    end
  end
  
end

user_data = UserInput.new

# puts user_data.inspect

data_sets = []
user_data.meters.each do |hash|
  data_sets << DataSet.new(hash['name'], hash['server'], user_data.start_date, user_data.end_date, hash['user'], hash['password'], hash['location'])
  # puts data_sets[data_sets.size-1].inspect
end
master_set = []
data_sets.each do |data_set|
  unless user_data.quiet
    # print "Delete irrelevant data files (Y/n)? "
    # case command
    # when "Y"
    #   data_set.delete_irrelevant_data_files
    # when "n", "N"
    #   break
    # else
    #   print "\nEnter Y or n only. "
    # end
  end
  data_set.process_files
  if master_set.empty?
    master_set = data_set.data_array.transpose
    puts "master_set.size: #{master_set.size}"
  else 
    master_set = master_set + data_set.data_array.transpose
  end
end
master_set.each_index do |n|
  next if n % 2 != 1
# find and subtract mean
  mean = master_set[n].mean
  puts mean
  master_set[n].map! {|x| x-mean}
#apply offset to each element
  offset = 2000*(n-1)/2
  puts offset
  master_set[n].map! {|x| x + offset}
  while master_set[n].size < 86400 * ((user_data.start_date-user_data.end_date).abs+1)
    master_set[n][master_set[n].size]=nil
    master_set[n-1][master_set[n-1].size]=nil
  end
end

puts "Writing datafile (plot_data.csv)..."
fout = File.open("#{user_data.plot_path}plot_data.csv",'w')
master_set.transpose.each do |line|
  fout.puts line.join " "
end
fout.close

using_str = ""
data_sets.each_index do |n|
  using_str << "using #{n*2+1}:#{n*2+2} index 0 title '#{data_sets[n].meterName}(#{data_sets[n].location})\' with lines, "
end

puts "Creating gnuplot script..."
gnuconf = File.open('gnuplot_script.conf','w')
gnuconf.print %Q/set terminal png size 1600,900
set xdata time
set timefmt '%Y-%m-%d-%H:%M:%S'
set output 'gPhoneComparisonPlot.png'
set xrange ['#{user_data.start_date}-00:00:00':'#{user_data.end_date}-23:59:59']
set grid
set xlabel 'Date\\nTime'
set ylabel 'Acceleration''
set title 'Ground Motion recorded between Toronto, Cananda and Boulder, CO'
set key bmargin center horizontal box
plot '#{user_data.plot_path}plot_data.csv' #{using_str}
screendump/
gnuconf.close

puts "Running script to gnuplot..."
# `gnuplot < gnuplot_script.conf`

puts "Uploading image via ftp..."
#`ftp -s:ftp.txt ftp.microglacoste.com`
