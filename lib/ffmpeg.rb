require 'ffmpeg/class_methods'
require 'ffmpeg/main_options'
require 'ffmpeg/file_extensions'
require 'ffmpeg/video_options'
require 'ffmpeg/video_advanced_options'
require 'ffmpeg/audio_options'
require 'ffmpeg/ffmpeg_command'
require 'ffmpeg/helper_methods'
require 'ffmpeg/meta_data'
require 'ffmpeg/output_reading'

module FFMpeg
  include HelperMethods
  include MainOptions
  include VideoOptions
  include VideoAdvancedOptions
  include AudioOptions
  include MetaData
  include OutputReading
  
  class FFmpegError < Exception
  end
  
  class << self
    
    #
    # Allows you to specify a block that is called everytime FFMpeg spits out something on the
    # command line
    #
    #  convert "file1.ext", :to => "file2.ext" do
    #    while_converting do
    #      puts current_eta
    #    end
    #  end
    #
    def while_converting(&block)
      @while_block = block
    end
    
    #
    # Returns the proc set by the while_converting block  
    #
    def while_block
      @while_block || nil
    end
    
    #
    # Log command line output for review
    #
    def log_output(output)
      @output ||= []
      @output << [Time.now, output]
    end
    
    #
    # Returns the command line log 
    #
    def log
      @output || []
    end
    
    #
    # Clear the command line log
    #
    def clear_log
      @output = []
    end
    
    #
    # flag the new duration has been overridden by FFMpeg::MainOptions.duration, 
    # required for proper eta calculations
    #
    def set_duration_override(duration)
      @duration = colon_time_to_seconds(duration)
    end
    
    #
    # The new duration put forth by set_duration_override
    #
    def new_duration
      @duration
    end
    
  end
  
  #
  # When mixed into a class, extend  
  # it with the ClassMethods module
  #
  def self.included(klass)
    klass.extend ClassMethods
    
    #
    # Everytime a method is added to the
    # class, check for conflicts with existing
    # module methods
    #
    def klass.method_added(name)
      check_method(name) if method_checking_enabled?
    end
  end
  
  #
  # Sets up an FFmpegCommand for converting files:
  #
  #  convert "file1.ext", :to => "file2.ext" do
  #    seek       "00:03:00"
  #    duration   "01:10:00"
  #    resolution "800x600"
  #  end
  #
  def convert(from_file, to_file = {})
    @from_file = from_file
    FFMpegCommand << "-i #{from_file}"
    begin
      yield if block_given?
    rescue Exception => exception
      disable_method_checking!
      raise exception
    end
    
    build_output_file_name(from_file, to_file[:to]) do |file_name|
      FFMpegCommand << file_name
    end
  end
  
  #
  # Explicitly set ffmpeg path
  #
  def ffmpeg_path(path)
    @@ffmpeg_path = path
  end

  #
  # Runs ffmpeg
  #
  def run
    @@ffmpeg_path ||= locate_ffmpeg
    unless @@ffmpeg_path.empty?
      execute_command FFMpegCommand.command(@@ffmpeg_path)
    else
      $stderr.puts "Couldn't locate ffmpeg, try to specify an explicit path
                    with the ffmpeg_path(path) method"
    end
  end
  
  private
  
  #
  # Allows you to specify a block that is called everytime FFMpeg spits out something on the
  # command line
  #
  #  convert "file1.ext", :to => "file2.ext" do
  #    while_converting do
  #      puts current_eta
  #    end
  #  end
  #
  def while_converting(&block)
    FFMpeg.while_converting do
      yield
    end
  end
  
  #
  # Returns the file name to output to
  #
  def build_output_file_name(from_file, to_file)
    return if to_file.nil?
    if FileExtensions::EXT.include?(to_file.to_s)
      yield from_file.gsub(/#{File.extname(from_file)}$/, ".#{to_file}")
    else
      yield "#{to_file}"
    end
  end

  #
  # Checks if the thread local varialble 'method checking disabled'
  # is true or false
  #
  def method_checking_enabled?
    !Thread.current[:'method checking disabled']
  end
  
  #
  # Turns off the method checking functionality
  #
  def disable_method_checking!
    Thread.current[:'method checking disabled'] = true
  end

  #
  # Tries to locate the FFmpeg executable
  #
  def locate_ffmpeg
    ffmpeg_executable = %x[which ffmpeg].strip
  end
  
  #
  # Executes FFmpeg with the specified command. Output is stored in the log
  # and the while_converting block is call, if it has been set.
  #
  def execute_command(cmd)
    IO.popen("#{cmd} 2>&1") do |pipe|
      pipe.each("\r") do |line|
        FFMpeg.log_output line
        FFMpeg.while_block.call if !!FFMpeg.while_block
      end
    end
    FFMpegCommand.clear
    FFMpeg.clear_log
    # Dufunct right now, need to take a look later
    raise FFmpegError, "FFmpeg command (#{cmd}) failed" if $? != 0
  end
end
