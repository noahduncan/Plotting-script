require 'time'
require 'date'

# Add function "mean" to all Arrays
class Array
  def sum
    inject(0.0) { |result, el| result + el } #return floating point cumulative sum of all elements
  end
  
  def mean
    sum / size #return mean of the array.
  end
end


# TsfFile is a particularly formatted file used in gravity and seismology
# it can be imported into anothe program called Tsoft.  Here I've created
# methods so that the data I want can be extracted, checked, and reformatted.
class TsfFile
  attr_reader :name
  
  def initialize(name)
    @f = File.open(name,"r")
    @name = name
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
  
  # pull out columns
  def parse_row(data_str)
    grav_col = 6
    tide_col = 8
    date_cols = 0..2
    time_cols = 3..5
    return false unless data_str.match /^\d/  # ignore header rows, all other rows start with a number
    cols =  data_str.split
    cor_grav = cols[grav_col].to_f - cols[tide_col].to_f
    output = [cols[date_cols].join('-') + "-" + cols[time_cols].join(":"), cor_grav]
    return output
  end
end

# DataSet contains all files information about the meter whose files it will contain
# Also, the data_array variable will contain the combined output of all of the TsfFiles
# that the DataSet contains.
# Also the Dataset contains functions to make the calls to download necessary data files, 
# delete unused files, and process, or parse through, the files.
class DataSet
  attr_accessor :meterName, :server, :files, :location, :offset
  attr_reader :data_array, :mean
  
  def initialize(meterName, server, location)
    defined?(@@data_set_count).nil? ? @@data_set_count = 0 : @@data_set_count += 1
    @meterName = meterName
    @server = server
    @location = location
    @files = []
    @data_array = []
    @offset = @@data_set_count * CONSTANTS["offset"]
    
    # create the array of files that composes the DataSet.  Name is determined by a convention.  Want
    # the last 7 full days of data.
    (0..CONSTANTS["num_files"]-1).to_a.reverse.each do |i|
      filename = "#{(CONSTANTS["end_date"]-i).year}_#{"%03d" % (CONSTANTS["end_date"]-i).yday.to_i}_#{@meterName}.tsf"
      if File.file?(filename)
        puts "#{filename} exists: skipping download."
      else
        download_data_file(filename)
      end
      @files << TsfFile.new(filename)
    end
  end
  
  # Download data using wget from each meter's http server.
  def download_data_file(filename)
    #download the .tsf file from the gphone computers using wget
    puts "Downloading: \"#{@server}/gmonitor_data/#{filename}\""
    `wget --user=#{CONSTANTS["gphone_user"]} --password=#{CONSTANTS["gphone_pass"]} \"#{@server}/gmonitor_data/#{filename}\"`
  end
  
  # if there is a TSF file in the FS Tree that is not in the files array remove it
  # as it is not needed anymore
  def delete_irrelevant_data_files
    shell_file_names = Dir.glob("*#{meterName}.tsf")
    @files.each do |file|
      unless shell_file_names.include? file.name
        puts "Deleting: #{file.name}"
        File.delete(file.name)
      end
    end
  end
  
  # extract the desired data (will be datetime and corrected gravity) from each file
  # and concatenate it onto the data_arrray variable
  def process_files
    @files.each do |file|
      puts "Processing #{file.name}.."
      puts "  Extracting Corrected Gravity Data..."
      file_data = file.get_time_and_corrected_gravity_data
      file_data.each do |row|
        @data_array << row
      end
    end
    find_mean
  end
   
  def num_gaps
    CONSTANTS["lines_in_file"] * CONSTANTS["num_files"] - @data_array.size
  end
  
  def fix_gaps(length_diff)
    puts "  DataSet is too short: adding #{length_diff} empty lines"
    nil_array = []
    (0..length_diff).each do
      nil_array << nil
    end
    @data_array << nil_array
  end
  
  def normalize
    @data_array.map! {|x| [x[0], x[1] -= @mean]}
  end
  
  def find_mean
    @mean = @data_array.transpose[1].mean
  end
  
  def add_offset
    @data_array.map! {|x| [x[0], x[1] += @offset]}
  end
end

def create_gnuplot_script(data_sets)
  using_str = ""
  loc_str = ""
  data_sets.each_index do |n|
    if n==0
      using_str << "'#{CONSTANTS["data_file_path"]}' using #{n*2+1}:#{n*2+2} index 0 title '#{data_sets[n].meterName}(#{data_sets[n].location})\' with lines"
      loc_str << "#{data_sets[n].location}"
    else    
      using_str << ", '#{CONSTANTS["data_file_path"]}' using #{n*2+1}:#{n*2+2} index 0 title '#{data_sets[n].meterName}(#{data_sets[n].location})\' with lines"
      loc_str << " and #{data_sets[n].location}"
    end
  end
  
  gnuconf = File.open("gnuplot_script.conf",'w')
  gnuconf.print %Q/set terminal png size 1600,900
  set xdata time
  set timefmt '%Y-%m-%d-%H:%M:%S'
  set output '#{CONSTANTS["plot_file_path"]}'
  set xrange ['#{CONSTANTS["start_date"]}-00:00:00':'#{CONSTANTS["end_date"]}-23:59:59']
  set grid
  set xlabel 'Date\\nTime'
  set ylabel 'Acceleration'
  set title 'Ground Motion recorded between #{loc_str}'
  set key bmargin center horizontal box
  set datafile separator ","
  plot #{using_str}
  screendump/
  gnuconf.close
end

###########  Begin CONSTANTS Creation ################
CONSTANTS = {
  "now" => Time.new                                 # seed to find yesterday's date in gmt
}
CONSTANTS.merge!({
  "end_date" => Date.parse(CONSTANTS["now"].getgm.to_s)-1,  # Yesterday
  "num_files" => 1                                          # Number of previous files to load / process in each DataSet
})
CONSTANTS.merge!({
  "start_date" => CONSTANTS["end_date"] - (CONSTANTS["num_files"]-1), #1 for index offset
  "lines_in_file" => 86400,                         # set-in-stone: number of secs in a day
  "offset" => 2000,                                 # Change this to change the separation distance of the meter plots
  "gphone_user" => "mgl_admin",                     # Global username for gPhone http file access
  "gphone_pass" => "gravity",                       # Global password for gPhone https file access
  "www_server" => "xxx.xxx.xxx.xxx",                 # WWW Ftp Sever address if you are uploading to a website 
  "www_ftp_user" => "secret",                       # Ftp username
  "www_ftp_pass" => "secret",                       # Ftp Password
  "www_ftp_path" => "www_root",                     # Path to navigate to on ftp server
  "plot_file_path" => "gPhoneComparisonPlot.png",   # Path/filename of where you want the plot saved (file will be overwritten)
  "data_file_path" => "plot_data.dat"               # Path/filename of output file to be run into gnuplot via configuration script (file will be overwritten)
})
########## End CONSTANTS Creation ######################

######## Edit meter info in this section ###############
####### Format: [meter_name, server_ip, location] ######
meters = [
  ["gPhone 097","216.254.148.51","Toronto, Canada"]
]
  # ["gPhone 095","10.0.1.119","Boulder, CO"],
##########  End Editable Section #######################

data_sets = []
master_set = []

meters.each do |meter|
  data_sets << DataSet.new(meter[0],meter[1],meter[2])
  data_sets << DataSet.new(meter[0],meter[1],meter[2])
end

data_sets.each do |data_set|
  data_set.process_files
  data_set.normalize
  data_set.add_offset
  data_set.fix_gaps(data_set.num_gaps) if data_set.num_gaps > 0
  master_set += data_set.data_array.transpose
end

puts "Writing datafile (#{CONSTANTS["data_file_path"]})..."
fout = File.new("#{CONSTANTS["data_file_path"]}",'w')
master_set.transpose.each do |line|
  fout.puts line.join ","
end
fout.close

puts "Creating gnuplot script..."
create_gnuplot_script(data_sets)

puts "Running script to gnuplot..."
`gnuplot < gnuplot_script.conf`

# puts "Uploading image via ftp..."
# `ftp -s:ftp.txt #{CONSTANTS["ftp_server"]}`
