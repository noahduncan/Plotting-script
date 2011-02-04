# this object creates a new file that contains the script info for the plotting program.
# earthquakes are plotted with a vertical line (arrow) and the coordinates are found in 
# the @quake_file.  Data_sets are necessary to find where the meters are located and what
# their names are.
class GnuplotScript
  def initialize(file_path,meters)
    @file = file_path
    @quake_file = File.new(CONSTANTS[:earthquake_file_path],'r')
    @y_max = (meters.length-1) * CONSTANTS[:offset] / 1000 + 1.5   # divide by 1000 to convert offset to mGal (should clean this up) and
    
    @meter_names = []  # will contain each meter name from each data_set
    @locations = []    # the locations from each data set
    meters.each do |meter|
      @meter_names << meter[0]
      @locations << meter[2]
    end
  end

  # used by create method
  def quake_str
    quakes = ""
    @quake_file.each do |line|
      cols = line.split(",")
      next if cols[0].length != "yyyy-mm-dd-hh:mm:ss".length
      if Date.parse(cols[0]) <= CONSTANTS[:end_date] && Date.parse(cols[0]) >= CONSTANTS[:start_date]
        quakes << %Q/set arrow from '#{cols[0]}', graph 0 to '#{cols[0]}', graph 1 nohead lw 3\n/
        quakes << %Q/set label right "#{cols[1].chomp}\\n#{cols[0]}" at '#{cols[0]}', graph 0.98\n/
      end
    end
    quakes
  end
  
  # used by create method
  def loc_str
    locs = nil
    @locations.each do |location|
      locs.nil? ? locs = location : locs += " and #{location}"
    end
    locs
  end
  
  # used by create method
  def using_str
    using = nil
    @meter_names.each_index do |n|
      if using.nil?
        using = "'#{CONSTANTS[:data_file_path]}' using #{n*2+1}:#{n*2+2} index 0 title '#{@meter_names[n]}(#{@locations[n]})\' with lines"
      else    
        using << ", '#{CONSTANTS[:data_file_path]}' using #{n*2+1}:#{n*2+2} index 0 title '#{@meter_names[n]}(#{@locations[n]})\' with lines"
      end
    end
    using
  end

  # write all info to file
  def create
    f = File.new(@file, 'w')
    f.print %Q/set terminal png size 1600,900
set output '#{CONSTANTS[:plot_file_path]}'

# Graph settings
set xdata time
set timefmt '%Y-%m-%d-%H:%M:%S'
set output '#{CONSTANTS[:plot_file_path]}'
set xrange ['#{CONSTANTS[:start_date]}-00:00:00':'#{CONSTANTS[:end_date]}-23:59:59']
set yrange [-1.5:#{@y_max}]
set grid

# Labels
set xlabel "Date\\nTime"
set ylabel 'Acceleration (mGals)'
set title 'Ground Motion recorded between #{loc_str}'
set key bmargin center horizontal box\n

# Earthquakes
#{quake_str}

# Plot settings
set datafile separator ','
plot #{using_str}

# Save Image
screendump/
    f.close
  end

  # run file to gnuplot
  # NOTE: gnuplot must be in path
  def execute
    `gnuplot #{CONSTANTS[:gnuplot_script_path]}`
  end
end
