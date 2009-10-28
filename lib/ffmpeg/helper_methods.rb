module FFMpeg
  module HelperMethods
    
    def returning(value)
      yield  value
      return value
    end
    
    def colon_time_to_seconds(colon_time)
      colon_time.split(':').reverse.inject([0,0]) do |(seconds, power), number|
       [seconds+number.to_f*60**power, power+1]
      end.first
    end
    
  end
end