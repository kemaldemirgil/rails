require "active_support/core_ext/class/attribute"
require "minitest"

module Rails
  class TestUnitReporter < Minitest::StatisticsReporter
    class_attribute :executable
    self.executable = "bin/rails test"

    COLOR_CODES_FOR_RESULTS = {
      "." => :green,
      "E" => :red,
      "F" => :red,
      "S" => :yellow
    }

    COLOR_CODES = {
      red: 31,
      green: 32,
      yellow: 33
    }

    def record(result)
      super
      color = COLOR_CODES_FOR_RESULTS[result.result_code]

      if options[:verbose]
        io.puts color_output(format_line(result), color)
      else
        io.print color_output(result.result_code, color)
      end

      if output_inline? && result.failure && (!result.skipped? || options[:verbose])
        io.puts
        io.puts
        io.puts format_failures(result).map { |line| color_output(line, color) }
        io.puts
        io.puts format_rerun_snippet(result)
        io.puts
      end

      if fail_fast? && result.failure && !result.error? && !result.skipped?
        raise Interrupt
      end
    end

    def report
      return if output_inline? || filtered_results.empty?
      io.puts
      io.puts "Failed tests:"
      io.puts
      io.puts aggregated_results
    end

    def aggregated_results # :nodoc:
      filtered_results.map { |result| format_rerun_snippet(result) }.join "\n"
    end

    def filtered_results
      if options[:verbose]
        results
      else
        results.reject(&:skipped?)
      end
    end

    def relative_path_for(file)
      file.sub(/^#{app_root}\/?/, '')
    end

    private
      def output_inline?
        options[:output_inline]
      end

      def fail_fast?
        options[:fail_fast]
      end

      def format_line(result)
        "%s#%s = %.2f s = %s" % [result.class, result.name, result.time, result.result_code]
      end

      def format_failures(result)
        result.failures.map do |failure|
          "#{failure.result_label}:\n#{result.class}##{result.name}:\n#{failure.message}\n"
        end
      end

      def format_rerun_snippet(result)
        # Try to extract path to assertion from backtrace.
        if result.location =~ /\[(.*)\]\z/
          assertion_path = $1
        else
          assertion_path = result.method(result.name).source_location.join(':')
        end

        "#{self.executable} #{relative_path_for(assertion_path)}"
      end

      def app_root
        @app_root ||= defined?(ENGINE_ROOT) ? ENGINE_ROOT : Rails.root
      end

      def colored_output?
        options[:color] && io.respond_to?(:tty?) && io.tty?
      end

      def color_output(string, color)
        if colored_output?
          "\e[#{COLOR_CODES[color]}m#{string}\e[0m"
        else
          string
        end
      end
  end
end
