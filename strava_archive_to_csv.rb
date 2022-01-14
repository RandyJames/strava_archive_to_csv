require 'json'
require 'csv'
require 'nokogiri' # xml
require 'logger'
require 'optparse'
require 'fitreader'
require 'zlib'
require 'gpx'


# Basic flow
# * Open an output.csv for this whole run
#   It's going to be big, so best to stream the writes?
# * Find/load activities.csv
# * For each row in activities.csv
#   * Skip if not correct year
#   * Skip if the type does not have location data
#   * If it uses a GPX file
#     * Load GPX parser and stream to output.csv
#   * If it uses a FIT file
#     * Load FIT parser and stream to output.csv
#
class Log
  def self.method_missing(symbol, *args)
    @logger ||= Logger.new($stdout)
    @logger.send(symbol, *args)
  end
end

Log.level = Logger::INFO

ONE_DAY=86400
TWENTY_YEARS=631152000
HEADER=%w{activity_id,path_id,time,latitude,longitude,altitude}
class StravaArchiveToCsv
  attr_reader :strava_dir, :year, :out_file

  def initialize(strava_dir:, year:, out_file: nil)
    @strava_dir = strava_dir
    @year       = year.to_i
    if out_file
      @out_file = File.open(out_file, 'a')
    else
      @out_file = File.open("#{@year}.csv", 'a')
    end
    # Write the header
    @out_file.write("#{HEADER.join(',')}\n")
  end

  I_ID=0
  I_DATE=1
  I_NAME=2
  I_TYPE=3
  I_FILENAME=11
  # Types
  #  Alpine Ski
  #  Canoe
  #  Crossfit
  #  Hike
  #  Inline Skate
  #  Kayaking
  #  Nordic Ski
  #  Ride
  #  Run
  #  Snowshoe
  #  Swim
  #  Walk
  #  Weight Training
  #  Workout
  #  Yoga
  def go
    CSV.foreach("#{@strava_dir}/activities.csv") do |row|
      activity_id = row[I_ID]
      # skip the header
      next if activity_id.to_i == 0
      activity_date = DateTime.parse(row[I_DATE])
      unless row[I_FILENAME]
        Log.warn "File for #{activity_id} is nil"
        next
      end
      file = File.join(@strava_dir, row[I_FILENAME])
      file = file.gsub(/.gz$/,'')
      unless File.exist?(file)
        Log.warn "File #{file} for #{activity_id} does not exist"
        next
      end

      Log.info "#{activity_date} : #{file}"
      unless activity_date.year == @year or @year == 0
        Log.warn "Skipping unwanted year..."
        next
      end

      # Annnnnd.... the rest
      ActivityMotion.new(file, activity_id, @out_file)
    end
    @out_file.close
  end

  class ActivityMotion
    attr_reader :header, :records
    def initialize(file_path, activity_id, out_file)
      @header      = HEADER
      @activity_id = activity_id
      @out_file    = out_file

      if file_path =~ /.fit.gz$/
        _load_fit(Zlib::Inflate.inflate(File.read(file)))
      elsif file_path =~ /.fit$/
        _load_fit(file_path)
      elsif file_path =~ /.gpx/
        _load_gpx(file_path, activity_id)
      end
    end

    def has_motion?
      # do any of the records have longitude/latitude that are not zero?
    end

    # This is what we get.
    # I, [2022-01-08T05:58:08.737239 #19753]  INFO -- : {:timestamp=>985180822, :position_lat=>42.61950102634728, :position_long=>-72.8749430179596, :altitude=>714.8, :speed=>5.27}
    # I, [2022-01-08T05:58:08.737265 #19753]  INFO -- : {:timestamp=>985180827, :position_lat=>42.61941301636398, :position_long=>-72.8749010246247, :altitude=>720.0, :speed=>7.075}
    # This is what we want:
    # activity_id,path_id,time,latitude,longitude,altitude,speed(m/s)
    # 13774999,1,2017-05-22 11:04:49+00:00,42.430133,-71.450274,64.0,5.27
    # 13774999,2,2017-05-22 11:04:53+00:00,42.43013,-71.45035,63.8,7.875
    def _load_fit(file_path)
      fit_file = Fit.new(File.open(file_path,'r'))
      records = fit_file.type :record
      records.data.each_with_index do |r, path_id|
        next if skip_index?(path_id)
        # The timestamp is off by 20 years - 1 day for things that come from Slopes?
        time = Time.at(r[:timestamp]+TWENTY_YEARS-ONE_DAY)
        record = [@activity_id, path_id, time, r[:position_lat], r[:position_long], r[:altitude]]
        Log.debug "RECORD:FIT : #{record}"
        # skip things that don't have location information
        next unless has_location?(r[:position_lat], r[:position_long])
        @out_file.write(record.join(","))
        @out_file.write("\n")
      end
    end

    # @lat=42.42194, @lon=-71.462076, @latr=0.7404025280834833, @lonr=-1.2472485165104192, @time=2012-07-18 21:24:28 UTC, @elevation=62.9,
    def _load_gpx(file_path, activity_id)
      gpx =  GPX::GPXFile.new(:gpx_file => file_path)
      #Log.debug gpx.tracks.count
      # Assuming there is one track only
      unless gpx.tracks.count == 1
        Log.error "GPX TRAKCKS Count != 1 : #{gpx.tracks.count}"
        return
      end
      track = gpx.tracks.first
      #Log.debug track.public_methods
      #Log.debug track.points.count
      track.points.each_with_index do |point, path_id|
        next if skip_index?(path_id)
        # point.public_methods
        # [:recalculate_distance, :segments, :to_s, :bounds, :lowest_point, :highest_point, :moving_duration, :name=, :empty?, :name, :comment=, :distance, :append_segment, :description=, :contains_time?, :segments=, :gpx_file=, :closest_point, :crop, :delete_area, :description, :gpx_file, :comment, :points, :instantiate_with_text_elements, :to_yaml, :to_json, :dup, :itself, :yield_self, :then, :taint, :tainted?, :untaint, :untrust, :untrusted?, :trust, :frozen?, :methods, :singleton_methods, :protected_methods, :private_methods, :public_methods, :instance_variables, :instance_variable_get, :instance_variable_set, :instance_variable_defined?, :remove_instance_variable, :instance_of?, :kind_of?, :is_a?, :tap, :class, :display, :hash, :singleton_class, :clone, :public_send, :method, :public_method, :singleton_method, :define_singleton_method, :gem, :extend, :to_enum, :enum_for, :<=>, :===, :=~, :!~, :nil?, :eql?, :respond_to?, :freeze, :inspect, :object_id, :send, :__send__, :!, :==, :!=, :__id__, :equal?, :instance_eval, :instance_exec]
        record = [activity_id, path_id, point.time, point.lat, point.lon, point.elevation]
        Log.debug "RECORD:GPX : #{record}"
        # skip things that don't have location information
        next unless has_location?(point.lat, point.lon)
        @out_file.write(record.join(","))
        @out_file.write("\n")
      end
    end

    ONE_OUT_OF=1
    def skip_index?(i)
      # take one in X samples, basically
      i % ONE_OUT_OF != 0
    end

    def has_location?(lon, lat)
      return false unless lon and lat
      lon.to_i != 0 and lat.to_i != 0
    end
  end
end

options = {}
OptionParser.new do |parser|
  parser.banner = "Usage: strava_archive_to_csv.rb [options]"
  parser.on('--dir DIR', String)
  parser.on('--year YEAR', Integer)
  parser.on('-v', '--verbose')
end.parse!(into: options)

Log.info options

Log.level = Logger::DEBUG if options[:verbose]

atc = StravaArchiveToCsv.new(strava_dir: options[:dir], year: options[:year])

atc.go