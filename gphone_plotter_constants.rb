require "date"
require "time"

# These include usernames, passwords, and file locations for the entire gphone_plotter script
CONSTANTS = {
  :now => Time.new                                                   # DO NOT CHANGE: seed to find yesterday's date in gmt
}                                                                     
CONSTANTS.merge!({                                                    
  :end_date => Date.parse(CONSTANTS[:now].getgm.to_s)-1,            # DO NOT CHANGE: Yesterday's date
########======================== Edit this section =================###############
  :num_files => 7                                                    # Number of previous files (days) to load / process in each DataSet
})
CONSTANTS.merge!({
  :start_date => CONSTANTS[:end_date] - (CONSTANTS[:num_files]-1), # DO NOT CHANGE: -1 for indexing offset
  :lines_in_file => 86400,                                           # DO NOT CHANGE: number of secs in a day
  :offset => 2000,                                                   # Change this to change the separation distance of the meter plots
  :gphone_user => "mgl_admin",                                       # Global username for gPhone http file access
  :gphone_pass => "gravity",                                         # Global password for gPhone https file access
  :www_ftp_server => "ftp.someserver.com",                           # WWW Ftp Sever address if you are uploading to a website 
  :www_ftp_user => "********",                                       # Ftp username
  :www_ftp_pass => "*********",                                      # Ftp Password
  :www_ftp_path => "public_html",                                    # Path to navigate to on ftp server
  :tsf_file_path => "tsf_files/",                                    # Path to where tsf_files should be stored
  :ftp_script_path => "outputs/ftp.txt",                             # Path to where ftp script will be saved
  :plot_file_path => "outputs/gPhoneComparisonPlot.png",             # Path/filename of where you want the plot saved (file will be overwritten)
  :data_file_path => "outputs/plot_data.csv",                        # Path/filename of configuration file to be run into gnuplot (file will be overwritten)
  :gnuplot_script_path => "outputs/gnuplot_script.conf",             # Path/filename of the script to run to gnuplot
  :earthquake_file_path => "inputs/earthquakes.csv"                  # Path/filename of the file containing earthquake events that should be plotted
})

# Each meter in this section will have it's data downloaded and plotted
# Format: [meter_name, server_ip, location]
# NOTE: meter_name MUST be _identical_ to the name that appears in the files on the file system
# (i.e. if you enter ...gPhone 95... when the file is ...gPhone 095.. this script will error and exit)
METERS = [
  ["gPhone 095","10.0.1.119","Boulder, CO"],
  ["gPhone 097","ip.or.url","Toronto, Canada"]
]
###############=================  End Editable Section =================##################
