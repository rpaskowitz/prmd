require 'prmd/commands/verify'
require 'prmd/rake_tasks/base'
require 'prmd/load_schema_file'

# :nodoc:
module Prmd
  # :nodoc:
  module RakeTasks
    # Schema Verify rake task
    #
    # @example
    #   Prmd::RakeTasks::Verify.new do |t|
    #     t.files << 'schema/api.json'
    #   end
    class Verify < Base
      # Schema files that should be verified
      # @return [Array<String>] list of files
      attr_accessor :files

      # Creates a new task with name +name+.
      #
      # @param [String, Symbol] name the name of the rake task
      def initialize(name = :verify)
        @files = []
        super
      end

      private

      # Defines the rake task
      #
      # @param [String] filename
      # @return [Array<String>] list of errors produced
      def verify_file(filename)
        data = Prmd.load_schema_file(filename)
        errors = Prmd.verify(data)
        unless errors.empty?
          errors.map! { |error| "#{filename}: #{error}" } if filename
          errors.each { |error| $stderr.puts(error) }
        end
        errors
      end

      protected

      # Defines the rake task
      # @return [void]
      def define
        desc 'Verifying schemas' unless Rake.application.last_comment
        task(name) do
          all_errors = []
          files.each do |filename|
            all_errors.concat(verify_file(filename))
          end
          fail unless all_errors.empty?
        end
      end
    end
  end
end
