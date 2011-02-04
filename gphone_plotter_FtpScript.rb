# Object that can generate and run an ftp script for uploading
class FtpScript
  def initialize(filename, user, pass, uploads)
    @filename = filename   # file path/name on filesystem
    @user = user           # ftp username
    @pass = pass           # ftp password
    @uploads = uploads     # Array of files to send
  end
  
  # Create file
  def create
    f = File.new(@filename,'w')
    
    f.puts @user
    f.puts @pass
    f.puts "cd #{:www_ftp_path}"
    f.puts "binary"
    @uploads.each do |upload|
      f.puts "put #{upload}"
    end
    f.puts "bye"
    f.close
  end
  
  # Run script to ftp program.
  # NOTE: ftp must be in path
  def execute
    `ftp -s:#{@filename} #{CONSTANTS[:www_ftp_server]}`
  end
end
