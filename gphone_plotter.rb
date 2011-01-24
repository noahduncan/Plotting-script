require 'time'
require 'date'

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
   
  def get_time_and_corrected_gravity_data
    output = []
    @f.rewind
    until @f.eof 
      cols = parse_row(@f.gets)
      output << cols unless cols === false
    end
    output
  end
  
  def parse_row(data_str)
    return false unless data_str.match /^\d/
    cols =  data_str.split
    cor_grav = cols[6].to_f - cols[8].to_f
    output = [cols[0..2].join('-') + "-" + cols[3..5].join(":"), cor_grav]
    return output
  end
end

class DataSet
  attr_accessor :meterName, :server, :files, :location
  attr_reader :data_array
  
  def initialize(meterName, server, location)
    @@now ||= Time.new
    @meterName = meterName
    @server = server
    @files = []
    @data_array = []
    @location = location
    
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
  
  def download_data_file(filename)
    #download the .tsf file from the gphone computers using wget
    puts "Downloading: \"#{@server}/gmonitor_data/#{filename}\""
    `wget --user=#{CONSTANTS["gphone_user"]} --password=#{CONSTANTS["gphone_pass"]} \"#{@server}/gmonitor_data/#{filename}\"`
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
      puts "Processing #{file.name}.."
      puts "  Extracting Corrected Gravity Data..."
      file.get_time_and_corrected_gravity_data.each do |row|
        @data_array << row
      end
    end
  end
end

CONSTANTS = {
  "now" => Time.new
}
CONSTANTS.merge!({
  "end_date" => Date.parse(CONSTANTS["now"].getgm.to_s)-1,
  "num_files" => 7
})
CONSTANTS.merge!({
  "start_date" => CONSTANTS["end_date"] - (CONSTANTS["num_files"]-1), #1 for index offset
  "lines_in_file" => 86400,
  "offset" => 2000,
  "gphone_user" => "mgl_admin",
  "gphone_pass" => "gravity",
  "www_ftp_user" => "microgla",
  "www_ftp_pass" => "microg422",
  "www_ftp_path" => "public_html",
  "gnu_conf_path" => "gnuplot_script.conf",
  "plot_file_path" => "gPhoneComparisonPlot.png",
  "data_file_path" => "plot_data.dat"
})

puts CONSTANTS["start_date"]
puts CONSTANTS["end_date"]
data_sets = []
master_set = []

meters = [["gPhone 095","10.0.1.119","Boulder, CO"],["gPhone 097","216.254.148.51","Toronto, Canada"]]

meters.each do |meter|
  data_sets << DataSet.new(meter[0],meter[1],meter[2])
end

data_sets.each do |data_set|
  data_set.process_files
  if master_set.empty?
    master_set = data_set.data_array.transpose
  else 
    master_set = master_set + data_set.data_array.transpose
  end
end
master_set.each_index do |n|
  next if n % 2 != 1 # perform operations only on gravity data, not time data
# find and subtract mean
  mean = master_set[n].mean
  puts mean
  master_set[n].map! {|x| x-mean}
#apply offset to each element
  offset = CONSTANTS["offset"]*(n-1)/2
  puts offset
  master_set[n].map! {|x| x + offset}
  while master_set[n].size < CONSTANTS["lines_in_file"] * CONSTANTS["num_files"]
    master_set[n][master_set[n].size]=nil
    master_set[n-1][master_set[n-1].size]=nil
  end
end

puts "Writing datafile (#{CONSTANTS["data_file_path"]})..."
fout = File.new("#{CONSTANTS["data_file_path"]}",'w')
master_set.transpose.each do |line|
  fout.puts line.join ","
end
fout.close

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

puts "Creating gnuplot script..."
gnuconf = File.open(CONSTANTS["gnu_conf_path"],'w')
gnuconf.print %Q/set terminal png size 1600,900
set xdata time
set timefmt '%Y-%m-%d-%H:%M:%S'
set output '#{CONSTANTS["plot_file_path"]}'
set xrange ['#{CONSTANTS["start_date"]}-00:00:00':'#{CONSTANTS["end_date"]}-23:59:59']
set grid
set xlabel 'Date\\nTime'
set ylabel 'Acceleration ({\/Symbol m}gal)'
set title 'Ground Motion recorded between #{loc_str}'
set key bmargin center horizontal box
set datafile separator ","
plot #{using_str}
screendump/
gnuconf.close

puts "Running script to gnuplot..."
`gnuplot < gnuplot_script.conf`

puts "Uploading image via ftp..."
# `ftp -s:ftp.txt ftp.microglacoste.com`
