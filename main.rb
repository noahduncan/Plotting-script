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

class DataSet
  attr_accessor :meterName, :server, :filenames
  
  def initialize(meterName, server)
    @meterName = meterName
    @server = server
    @now = Time.new
    @today = Date.today
    @filenames = Array.new
    i=1
    while i <= 7 do
      @filenames << "#{@now.getgm.year}_#{"%03d" % (@now.getgm.yday.to_i-i)}_#{@meterName}.tsf"
      i+=1
    end
  end
  
  def downloadSet
    @filenames.each do |filename|
      #download the .tsf files from the gphone computers using wget
      if File.exist?(filename)
        puts "#{filename} exists: skipping download."
      else
        puts "Downloading: \"#{server}/gmonitor_data/#{filename}\""
        `wget --user=mgl_admin --password=gravity \"#{server}/gmonitor_data/#{filename}\"`
      end
    end
  end
  
  def deleteOldFiles
    datafilenames = Dir.glob("*#{@meterName}.tsf")
    datafilenames.each do |datafilename|
      filenameparts = datafilename.split("_")
      file_date = Date.parse("#{filenameparts[0]}-#{filenameparts[1]}")
      if @today - file_date > 7
        puts "Deleting: #{datafilename}"
        File.delete(datafilename)
      end
    end
  end
  
  def getDataArray
    @dataArray = Hash.new
    @filenames.each do |filename|
      f = File.open(filename,'r')
      puts "Processing #{filename}..."
      @dataArray[filename[0..7]] = []
      until f.eof
        cols = parse_str(f.gets)
        @dataArray[filename[0..7]] << cols unless cols === false
      end
    end
    @dataArray
  end

  private
  def parse_str(data_str)
    return false unless data_str.match /^\d/
    cols =  data_str.split(" ")
    cor_grav = cols[6].to_f - cols[8].to_f
    output = [cols[0..2].join('-') + "-" + cols[3..5].join(":"), cor_grav]
    return output
  end
end

class TsfData < DataSet
  def initialize()
    @f = File.open(@name,"r")
  end
  
  def all_data
    output = Array.new
    @f.rewind
    @f.each do |row|
      output << row.split
    end
    return output
  end
  
  def extractData
    @f.rewind
    @f.each do |row|
      cols = parse_str(row)
      output[cols[0][0..9]] << cols
    end
    return output
  end
  #Too modular.  I think i can get away with just 
  #-make sure the latest 7 files are downloaded, 
  #---download any that aren't
  #---delete any that are not needed anymore
  #-rebuild data set
  #---process each file
  #-----parse out data
  #-----overwrite data file
end
#determine file name prefix for downloads
# now = Time.new
# file_prefix = "#{now.getgm.year}_#{"%03d" % (now.getgm.yday-1)}_"

data95 = DataSet.new("gPhone 095", "10.0.1.119")
data97 = DataSet.new("gPhone 097", "216.254.148.51")

#download missing files:
data95.downloadSet
data97.downloadSet

data95.deleteOldFiles
data97.deleteOldFiles

arr95=data95.getDataArray
arr97=data97.getDataArray

masterDataSet = {'time'=>[],'grav95'=>[],'grav97'=>[]}

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

=begin
#open and parse files
new95 = File.new("#{file_prefix}gPhone 095.tsf","r")
new97 = File.new("#{file_prefix}gPhone 097.tsf","r")
time = Array.new
grav1 = Array.new
grav2 = Array.new
while(!new97.eof?)
  row95 = new95.gets
  row97 = new97.gets
  entry = parse_str(row95,row97)
  
  next if entry == false
  time << entry[0]
  grav1 << entry[1]
  grav2 << entry[2]
end
new95.close
new97.close

# find mean
g1mean = grav1.mean
puts g1mean
# subtract mean from each element
grav1.map! {|x| x - g1mean}

#find mean
g2mean = grav2.mean
puts g2mean
# subtract mean from each element
grav2.map! {|x| x - g2mean}
#find offset so plots don't overlap
offset = grav1.max - grav2.min
#apply offset to each element
grav2.map! {|x| x + offset}

fout = File.open("plot_data.csv",'w')
for n in 1..time.size do
  fout.puts "#{time[n]} #{grav1[n]} #{grav2[n]}"
end
fout.close
=end
