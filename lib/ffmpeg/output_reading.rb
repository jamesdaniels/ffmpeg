module FFMpeg
  module OutputReading
  
    #
    # The estimated time until conversion is complete in seconds. This function requires that FFMpeg
    # can read the duration of the video properly, to be accurate 
    #
    def current_eta
      ((FFMpeg.new_duration || ETAHelpers.current_duration)  - ETAHelpers.last_timestamp) / ETAHelpers.current_rate
    end
    
    #
    # The current conversion progress as a float: 0.0-1.0
    #
    def current_progress
      ETAHelpers.last_timestamp / (FFMpeg.new_duration || ETAHelpers.current_duration)
    end
  
    module ETAHelpers
      extend self
   
      #
      # Give the duration in the movie in seconds read from the FFMpeg Output
      #
      def current_duration
        if (FFMpeg.log || []).join =~ /Duration: ([\w|:|.]+)/
          colon_time_to_seconds($1)
        end
      end
   
      #
      # Reads the current time column in the FFMpeg Output, so we know how far
      # into conversion we are. Puts it into a 2-d array with the Time the output
      # was returned
      #
      def read_timestamps
        FFMpeg.log.inject([]) do |array, log|
          array << (log[1] =~ /time=([\w|\.]+ )/ && [log[0], $1.to_f] || nil)
        end.compact
      end
    
      #
      # Retreives the last shown time in the FFMpeg conversion stats
      #
      def last_timestamp
        read_timestamps.last[1]
      rescue
        0
      end
    
      #
      # Returns an array of delta-conversion-rate/delta-time computed from timestamps
      #
      def deltas
        delta_array = [0]
        timestamps = read_timestamps
        read_timestamps.each_index do |index|
          delta_array << (timestamps[index][1]-timestamps[index-1][1])/(timestamps[index][0]-timestamps[index-1][0]) unless index == 0
        end
        delta_array
      end
      
      #
      # Takes the deltas and weighs them toward the end
      #
      def weighted_deltas
        delta_array = []
        d = deltas
        d.each_index do |index|
          delta_array << (d[index] * (index+1))
        end
        delta_array
      end
    
      #
      # The weight for the weighted_deltas function, so we can create a weighted average 
      #
      def weight
        s = deltas.size
        (s**2+s)/2.0
      end
    
      #
      # The weighted average rate of conversion in video-seconds per second
      #
      def current_rate
        (weighted_deltas.inject(0) {|sum, element| sum += element} / weight)
      rescue
        0.0000000001
      end
    
    end
  end
end