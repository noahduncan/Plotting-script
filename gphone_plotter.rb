require 'time'
require 'date'


class UserInput
  attr_reader :ftp_server,:data_path,:plot_path,:quiet,:start_date,:end_date,:meters
  def initialize
    @errors = []
    @meters = {}
    parse_args unless $*.nil?
    raise_exceptions unless @errors.empty?
    set_defaults
  end
  
  def parse_args
    $*.each do |a|
      parts = a.split('=')
      if a.match /^(-)/
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
          exit
        end
      else
        parts = a.split "@"
        if parts[1].nil?
          parts = a.split ":"
          @start_date ||= Date.parse parts[0]
          @end_date ||= Date.parse parts[1]
        else
          unless parts[1].match(/^\d\d?\d?\.\d\d?\d?.\d\d?\d?.\d\d?\d?$/)
            @errors = ["Invalid gPhone ip address"] 
            next
          end
          @meters[parts[0].to_s] = parts[1]
        end
      end
    end
  end
  
  def raise_exceptions
    @errors.map {|e| puts "Error: #{e}"}
    exit
  end
      
  def set_defaults
    @start_date ||= Date.today
    @end_date ||= @start_date - 7
    @data_path ||= ""
    @plot_path ||= ""
    @quiet ||= false
  end
    
  def help
    print "usage: ruby gphone_plotter.rb [-f|--ftp=server_ip] [-d|datafile=path] [-p|--plotname=path]
     [-q|--quiet] [-?|-h|--help] [meter_name@server_ip]... [start_date:end_date]
    
    This program takes the specified meters and servers from the user, downloads
    the necessary files (if found), plots the results, and (optionally) uploads the
    file to an ftp site.
    
    Modifiers:
      start_date, end_date      Time period to plot.  Default is 
                                7 days w/today as most recent
                                
      -f, --ftp=server_ip       If desired, the ftp server to upload the plot to.
                                
      -d, --datafile=path       path to where you want the data file saved
      
      -p, --plotname=path       Path to where you want the plot to be saved
      
      -q, --quiet               Force defaults, no prompts.
      
      -h, -?, --help            Display this help message
      
      "
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

class Tsf_file
  attr_reader :name
  
  def initialize(name)
    @f = File.open(name,"r")
    @name = name
  end
  
  def get_all_data
    output = []
    @f.rewind
    @f.each do |row|
      output << row.split
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
  attr_accessor :meterName, :server, :filenames
  attr_reader :data_array
  
  def initialize(meterName, server, start_date, end_date)
    @@now ||= Time.new
    @@today ||= Date.parse(@@now.getgm.to_s)
    @meterName = meterName
    @server = server
    @start_date = start_date
    @end_date = end_date
    @filenames = {}
    @data_array = []

    i=1
    while i <= (@end_date-@start_date).to_i do
      file_prefix = "#{(@@today-i).year}_#{"%03d" % (@@today-i).yday.to_i}"
      puts file_prefix
      @filenames[file_prefix] = "#{file_prefix}_#{@meterName}.tsf"
      i+=1
    end
  end
  
  def +(otherset)
    @data_array.concat otherset.data_array[1]
  end
  
  def download_data_files
    @files.each do |file|
      #download the .tsf files from the gphone computers using wget
      if File.exist?(file.name)
        puts "#{file.name} exists: skipping download."
      else
        puts "Downloading: \"#{@server}/gmonitor_data/#{file.name}\""
        `wget --user=mgl_admin --password=gravity \"#{@server}/gmonitor_data/#{file.name}\"`
      end
    end
  end
  
  def delete_irrelevant_data_files
    shell_file_names = Dir.glob("*#{meter_name}.tsf")
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
      file.get_time_and_corrected_gravity_data.each do |arr_row|
        @data_arr << arr_row
      end
    end
  end
  
end


user_data = UserInput.new

# puts user_data.inspect

data_sets = []
user_data.meters.each do |name,server|
  data_sets << DataSet.new(name,server, user_data.start_date, user_data.end_date)
  puts data_sets[data_sets.size-1].inspect
end


# data_sets.each do |data_set|
#   data_set.download_data_files
#   data_set.delete_irrelevant_data_files
#   data_set.process_files
# end

=begin
#download missing files:
data95.download_data_files
data97.download_data_files

data95.delete_data_files
data97.delete_data_files

arr95=data95.getDataArray.transpose
arr97=data97.getDataArray.transpose

data_sets.each do |data_set|
end

data95.filenames.sort.each do |filename|
  masterDataSet['time'].concat(arr95[filename[0..7]].transpose[0])
  masterDataSet['grav95'].concat(arr95[filename[0..7]].transpose[1])
  masterDataSet['grav97'].concat(arr97[filename[0..7]].transpose[1])
end
# find mean
mean95 = masterDataSet['grav95'].mean
puts mean95
# subtract mean from each element
masterDataSet['grav95'].map! {|x| x - mean95}


#find mean
mean97 = masterDataSet['grav97'].mean
puts mean97
# subtract mean from each element
masterDataSet['grav97'].map! {|x| x - mean97}
#apply static offset so plots don't overlap
offset = 2000
#apply offset to each element
masterDataSet['grav97'].map! {|x| x + offset}

puts "Writing datafile (plot_data.csv)..."
fout = File.open("plot_data.csv",'w')
for n in 1..masterDataSet['time'].size do
  fout.puts "#{masterDataSet['time'][n]} #{masterDataSet['grav95'][n]} #{masterDataSet['grav97'][n]}"
end
fout.close

puts "Creating gnuplot script..."
gnuconf = File.open('gnuplot_script.conf','w')
gnuconf.print %Q/set terminal png size 1600,900
set xdata time
set timefmt "%Y-%m-%d-%H:%M:%S"
set output "gPhoneComparisonPlot.png"
set xrange ["#{masterDataSet['time'][0]}":"#{masterDataSet['time'][masterDataSet['time'].size-1]}"]
set grid
set xlabel "Date\\nTime"
set ylabel "Acceleration"
set title "gPhone comparison: Toronto, Canada to Boulder, CO"
set key bmargin center horizontal box
f(x) = x+500
plot 'plot_data.csv' using 1:2 index 0 title "gPhone-95(Boulder, CO)" with lines, 'plot_data.csv' using 1:3 index 0 title 'gPhone-97(Toronto, Canada)' with lines
screendump/
gnuconf.close

puts "Running script to gnuplot..."
`gnuplot < gnuplot_script.conf`

puts "Uploading image via ftp..."
`ftp -s:ftp.txt ftp.microglacoste.com`

=end