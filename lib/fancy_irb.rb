require 'stringio'
require 'wirble'

class << FancyIrb = Module.new
  # setup instance variable accessors
  attr_reader :options
  def [](key, key2 = nil)
    if key2
      @options[key][key2]
    else
      @options[key]
    end
  end

  attr_accessor :original_stdout
  attr_accessor :capture_irb_errors
  attr_accessor :real_lengths
  attr_accessor :stdout_colorful

  def start(user_options = {})
    @height_counter = []
    @real_lengths = { :output => 1, :input_prompt => 9999 } # or whatever
    @stdout_colorful = false

    # set default and parse user options
    default_result_proc = proc{ |context|
      if context.inspect?
        context.last_value.inspect
      else
        context.last_value
      end
    }

    default_colorizer_proc = proc{ |value|
      FancyIrb.real_lengths[:output] =    value.size
      if defined?(Wirble) && FancyIrb[:colorize, :output]
        Wirble::Colorize.colorize value
      else
        value 
      end
    }

    default_options = {
      :rocket_mode     => true,
      :rocket_prompt   => '#=> ',
      :result_prompt   => '=> ',
      :colorize => {
        :rocket_prompt => nil,
        :result_prompt => nil,
        :input_prompt  => nil,
        :irb_errors    => nil,
        :stderr        => nil,
        :stdout        => nil,
        :input         => :red,
        :output        => nil, # wirble's colorization
#        :rocket_prompt => :blue,
#        :result_prompt => nil,
#        :input_prompt  => nil,
#        :irb_errors    => :red,
#        :stderr        => :light_red,
#        :stdout        => :yellow,
#        :input         => nil,
#        :output        => true, # wirble's colorization
       },
      :result_proc     => default_result_proc,
      :output_procs    => [default_colorizer_proc],
    }

    @options = default_options

    default_options.each{ |key, value|
      # (ugly) 1 level deep merge, maybe refactor
      if key == :colorize
        if user_options.has_key?(:colorize) && user_options[:colorize].nil?
          @options[:colorize] = {}
        else
          value.each{ |key2, _|
            if user_options[key] && user_options[key].has_key?(key2)
              @options[:colorize][key2] = user_options[key][key2]
            end
          }
        end
      else
        @options[key] = user_options.has_key?(key) ? user_options[key] : default_options[key]
      end
    }

    # hook code into IRB
    require './fancy_irb/irb_ext' #TODO

    "Enjoy your FancyIrb :)"
  end

  def add_output_proc(prepend = false, &proc)
    action = prepend ? :unshift : :push
    @options[:output_procs].send action, proc
  end

  def set_result_proc(&proc)
    @options[:result_proc] = proc
  end

  def reset_height
    @height_counter = []
  end

  def track_height(data)
    lines      = data.to_s.count("\n")
    long_lines = data.to_s.split("\n").inject(0){ |sum, line| line.size / `tput cols`.to_i }
    @height_counter << lines + long_lines
  end

  def get_height
    1 + ( @height_counter == [0] ? 0 : @height_counter.reduce(:+) || 0 )
  end

  def write_stream(stream, data, color = nil)
    stream.write_non_fancy(
      if defined?(Wirble) && FancyIrb.stdout_colorful && color
        Wirble::Colorize::Color.escape( color ) + data.to_s + Wirble::Colorize::Color.escape(:nothing)
      else
        data.to_s
      end
    )
  end
end

FancyIrb.start

# gets height bug
# wrong input colorization bug