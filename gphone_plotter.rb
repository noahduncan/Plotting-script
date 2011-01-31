require 'time'
require 'date'
require "gphone_plotter_constants"
require "gphone_plotter_GnuplotScript"
require "gphone_plotter_FtpScript"

# Add function "mean" to all Arrays
class Array
  # return floating point cumulative sum of all elements
  def sum
    inject(0.0) { |result, el| result + el } 
  end
  
  # return mean of the array.
  def mean
    sum / size
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
  
  #loop through file and extract time and gravity
  #return array with columns time and gravity
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

# DataSet contains all pieces of information about the meter whose files it will contain
# Also, the data_array instance variable will contain the combined output of all of the TsfFiles
# that the DataSet contains (after process_files is called).
# The Dataset contains methods to download necessary data files, delete unused files, 
# and process (i.e. parse through) the files.
class DataSet
  attr_accessor :meterName, :server, :files, :location, :offset
  attr_reader :data_array, :mean
  
  def initialize(meterName, server, location)
    defined?(@@data_set_count).nil? ? @@data_set_count = 0 : @@data_set_count += 1
    @meterName = meterName
    @server = server
    @location = location
    @files = []
    @filenames = []
    @data_array = []
    @offset = @@data_set_count * CONSTANTS["offset"]
    
    # create the array of files that composes the DataSet.  Fileame is determined by a convention.  Number of days
    # to download is determined by CONSTANTS["num_files"]
    (0..CONSTANTS["num_files"]-1).each do |i|
      filename = "#{(CONSTANTS["start_date"]+i).year}_#{"%03d" % (CONSTANTS["start_date"]+i).yday.to_i}_#{@meterName}.tsf"
      # if File.file?(CONSTANTS["tsf_file_path"] + filename)
      #   puts "#{filename} exists: skipping download."
      # else
        download_data_file(filename)
      # end
      @files << TsfFile.new(CONSTANTS["tsf_file_path"] + filename)
      @filenames << CONSTANTS["tsf_file_path"] + filename
    end
  end
  
  # Download data using wget from each meter's http server.
  def download_data_file(filename)
    #download the .tsf file from the gphone computers using wget
    puts "Downloading: \"#{@server}/gmonitor_data/#{filename}\""
    `wget -c --directory-prefix=#{CONSTANTS["tsf_file_path"]} --user=#{CONSTANTS["gphone_user"]} --password=#{CONSTANTS["gphone_pass"]} \"#{@server}/gmonitor_data/#{filename}\"`
  end
  
  # if there is a TSF file in the os Tree that is not in the files array remove it
  # as it is not needed anymore
  def delete_irrelevant_data_files
    shell_file_names = Dir.glob("#{CONSTANTS["tsf_file_path"]}*#{meterName}.tsf")
    shell_file_names.each do |shell_file_name|
      unless @filenames.include? shell_file_name
        puts "Deleting: #{shell_file_name}"
        File.delete(shell_file_name)
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
    (0..length_diff-1).each do
      nil_array << [nil,nil]
    end
    @data_array += nil_array
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
  
  def convert_to_mGals
    @data_array.map! {|x| [x[0], x[1] / 1000]}
  end
end



data_sets = []             # Array containing the DataSet objects for each meter entry
master_set = []            # Array that will contain the compilation of all DataSets' data_arrays

METERS.each do |meter|
  data_sets << DataSet.new(meter[0],meter[1],meter[2])
end

data_sets.each do |data_set|
  data_set.delete_irrelevant_data_files
  data_set.process_files
  data_set.normalize
  data_set.add_offset
  data_set.convert_to_mGals
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
gnuplot_script = GnuplotScript.new(CONSTANTS['gnuplot_script_path'], METERS)
gnuplot_script.create

puts "Running script to gnuplot..."
gnuplot_script.execute

puts "Creating ftp script..."
ftp_script = FtpScript.new(CONSTANTS['ftp_script_path'], CONSTANTS['www_ftp_user'], CONSTANTS['www_ftp_pass'], [CONSTANTS['plot_file_path']])
ftp_script.create

puts "Uploading image via ftp..."
ftp_script.execute
