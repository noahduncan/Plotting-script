require "gphone_plotter_constants"
require "gphone_plotter_GnuplotScript"
require "gphone_plotter_FtpScript"
require "digest"

hash_file_path = "outputs/plot_hash.txt"
md5_new = Digest::MD5.hexdigest(File.read(CONSTANTS["earthquake_file_path"]))

gnuplot_script = GnuplotScript.new(CONSTANTS['gnuplot_script_path'], METERS)
ftp_script = FtpScript.new(CONSTANTS['ftp_script_path'], CONSTANTS['www_ftp_user'], CONSTANTS['www_ftp_pass'], [CONSTANTS['plot_file_path']])

if File.exist?(hash_file_path)
  md5_f = File.new(hash_file_path,"r+")
  md5_s = md5_f.gets.chomp
  
  if md5_s == md5_new
    puts "No changes detected in '#{CONSTANTS['earthquake_file_path']}'"
  else
    puts "Creating gnuplot script..."
    gnuplot_script.create
    puts "Running '#{CONSTANTS["data_file_path"]}' to gnuplot..."
    gnuplot_script.execute
    
    puts "\nCreating FTP script..."
    ftp_script.create
    puts "Running FTP script..."
    ftp_script.execute
    
    puts "\nWriting new MD5: #{md5_new}"
    md5_f.rewind
    md5_f.print md5_new
  end
else
  puts "Creating '#{hash_file_path}'"
  md5_f = File.new(hash_file_path,'w')
  
  puts "Writing MD5: #{md5_new}"
  md5_f.print md5_new
end

sleep 2
