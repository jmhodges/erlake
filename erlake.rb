require 'rake'
require 'rake/tasklib'

module Erlake
  Version = "0.1.0"
  class NoProjectDirectoryGivenError < StandardError; end
  class NoProjectNameGivenError < StandardError; end
  class NotAnErlangFileError < StandardError; end
  class ErlangBuildError < StandardError; end

  class ErlangProject < Rake::TaskLib
    attr_accessor :name
    attr_accessor :version
    attr_accessor :sources
    attr_accessor :app_sources
    attr_accessor :output_path
    attr_accessor :code_paths
    attr_accessor :include_paths
    attr_accessor :dependencies
    attr_accessor :project_directory
    attr_accessor :warnings

    attr_accessor :test_sources
    attr_accessor :test_output_path
    attr_accessor :test_code_paths
    attr_accessor :test_include_paths
    attr_accessor :test_warnings

    attr_reader :extras
    attr_reader :test_extras

    attr_reader :generated_files

    def initialize(proj_name, proj_directory)
      raise NoProjectNameGivenError.new unless proj_name
      raise NoProjectDirectoryGivenError.new unless proj_directory

      # FIXME document that this name must be namespacable
      self.name = proj_name
      self.project_directory = proj_directory

      # We change the directory to allow for relative FileLists.
      # See the default_* methods and their related setters methods.
      chdir project_directory

      set_defaults!

      if block_given?
        yield self
      end

      define
    end

    def set_defaults!
      self.output_path = default_output_path
      self.sources = default_sources
      self.app_sources = default_app_sources
      self.include_paths = default_include_paths
      self.warnings = default_warnings

      self.test_sources = default_test_sources
      self.test_output_path = default_test_output_path
      self.test_include_paths = default_test_include_paths
      self.test_warnings = default_test_warnings
    end

    def output_path=(dir)
      @output_path = File.join(project_directory, dir)
    end

    def sources=(file_list)
      @sources = dir_join file_list
    end

    def app_sources=(file_list)
      @app_sources = dir_join file_list
    end

    def include_paths=(file_list)
      @include_paths = dir_join file_list
    end

    def code_paths
      @code_paths ||= [ output_path ] + dependencies.map{|d| d.output_path }
      @code_paths
    end

    def code_paths=(paths)
      @code_paths = paths.uniq

      # Magic to make `code_paths += arr` and `code_paths << path` maintain
      # the uniqueness of the paths.
      class << @code_paths
        def <<(path)
          self.push(path) unless self.include?(path)
        end
      end

      @code_paths
    end

    def test_code_paths
      @test_code_paths ||= code_paths
      @test_code_paths
    end

    def test_code_paths=(paths)
      @test_code_paths = paths.uniq

      class << @test_code_paths
        def <<(path)
          self.push(path) unless self.include?(path)
        end
      end
    end

    def dependencies=(deps)
      self.code_paths += deps.map{|d| d.output_path}

      # FIXME cycle detection and eigenclass magic
      @dependencies = deps
    end

    def dependencies
      @dependencies ||= []
      @dependencies
    end

    def extras
      @extras ||= []
      @extras
    end

    def test_extras
      @test_extras ||= []
      @test_extras
    end

    def copy_extras(file_list, opts={})
      opts[:to] ||= "doc"
      @extras ||= []
      @extras << {:files => file_list, :to => opts[:to] }
    end

    def copy_test_extras(file_list, opts={})
      opts[:to] ||= test_output_path
      @test_extras ||= []
      puts "HERE WITH #{file_list}"
      @test_extras << {:files => file_list, :to => opts[:to]}
    end

    def use_globally!
      top_level_define!
    end

    private

    def define
      fail "Name required" unless name

      namespace name do

        desc "Build the sources for #{name}."
        task :build_sources do

          sources.each do |file|

            erlc(
              file,
              :to => output_path, :paths => code_paths,
              :include => include_paths, :warnings => warnings
            )
          end
        end

        desc "Build the app sources for #{name}."
        task :build_app_sources do
          app_sources.each do |fn|
            install( fn, File.join(output_path, File.basename(fn)) )
          end
        end

        desc "Build the dependencies of #{name}."
        task :build_dependencies => dependencies_build_tasks

        desc "Copy the extra files over."
        task :copy_extras do

          extras.each do |hsh|
            hsh[:files].each do |fn|
              puts "Copying extra file #{fn} to #{hsh[:to]}"
              copy(fn, hsh[:to])
            end
          end

        end

        # FIXME edocs and extra files
        desc "Build #{name}."
        task :build => [:copy_extras, :build_dependencies, :build_sources, :build_app_sources]

        desc "Remove the extra files for #{name}."
        task :clean_extras do
          extras.each do |hsh|
            hsh[:files].each do |fn|
              rm File.join(hsh[:to], File.basename(fn))
            end
          end

        end

        desc "Remove all the files generated from the source files "
        task :clean_sources do

          if generated_files.any?{|fn| File.exist? fn}
            puts "Cleaning #{name}."

            generated_files.each{|fn| File.delete(fn) if File.exist?(fn) }
          end
        end

        desc "Remove all the generated files for #{name}."
        task :clean => [:clean_tests, :clean_extras, :clean_sources]

        desc "Build the test sources for #{name}."
        task :build_test_sources do

          test_sources.each do |file|
            erlc file,
            :to => test_output_path,
            :paths => test_code_paths,
            :include => test_include_paths
          end
        end

        desc "Copy the extra files over for the tests."
        task :copy_test_extras do

          test_extras.each do |hsh|
            hsh[:files].each do |fn|
              copy(fn, hsh[:to])
            end
          end

        end

        desc "Test #{name}."
        task :test => [:copy_test_extras, :build_test_sources] do
          old_dir = pwd

          # This is only done because I haven't worked out the extra/data/dist
          # file stuff which would be included for tests

          chdir test_output_path
          sh "erl -noshell #{code_path_args(test_code_paths)} #{include_args(test_include_paths)} #{warning_args(test_warnings)} -o #{test_output_path} -s test_runner run_all"
          chdir old_dir
        end

        desc "Clean test extras for #{name}."
        task :clean_test_extras do
          test_extras.each do |hsh|
            hsh[:files].each do |fn|
              rm File.join(hsh[:to], File.basename(fn))
            end
          end
        end

        desc "Clean the test sources for #{name}."
        task :clean_test_sources do
          generated_test_files.each do |fn|
            File.delete(fn) if File.exist?(fn)
          end
        end

        desc "Clean up the tests for #{name}."
        task :clean_tests => [:clean_test_extras, :clean_test_sources]

        desc "Retest #{name}."
        task :retest => [:clean_test_sources, :test]

        desc "Open an erl console with #{name} and its dependencies available to be imported."
        task :erl => :build do
          sh "erl #{code_path_args(code_paths)} #{include_args(include_paths)} "
        end
      end
    end

    # Defines the tasks in Rake application instead of just its own namespace
    def top_level_define!
      desc "Build #{name}."
      task :build   =>  "#{name}:build"

      desc "Clean #{name} and its dependencies."
      task :clean   =>  current_and_dependency_tasks(:clean)

      desc "Test #{name}."
      task :test    =>  "#{name}:test"

      desc "Retest #{name}."
      task :retest  =>  "#{name}:retest"

      desc "Open an erl console with #{name} and its dependencies available to be imported."
      task :erl => :build
    end

    def generated_files
      # FIXME edoc and extras
      output_source_files + output_app_source_files
    end

    def generated_test_files
      output_test_source_files # + output_test_data_files
    end

    def output_source_files
      sources.map{|fn| File.join( output_path, File.basename(beamify(fn)) )}
    end

    def output_app_source_files
      app_sources.map{|fn| File.join(output_path, File.basename(fn)) }
    end

    def output_test_source_files
      test_sources.map { |fn|
        File.join( test_output_path, File.basename(beamify(fn)) )
      }
    end

    def dependencies_build_tasks
      tasks_from_dependencies("build")
    end

    def current_and_dependency_tasks(task_name)
      ["#{name}:#{task_name}"] + tasks_from_dependencies(task_name)
    end

    def tasks_from_dependencies(task_name)
      (dependencies || []).map {|d| "#{d.name}:#{task_name}" }
    end

    def default_output_path
      "ebin"
    end

    def default_sources
      FileList["src/*.erl"]
    end

    def default_app_sources
      FileList["src/*.app", "src/*.appup"]
    end

    def default_include_paths; []; end

    def default_warnings; []; end

    def default_test_sources
      FileList["tests/*.erl"]
    end

    def default_test_output_path
      "tests/ebin"
    end

    def default_test_include_paths; []; end

    def default_test_warnings
      warnings || default_warnings
    end

    def dir_join(file_list)
      file_list.map{|fn| File.join(project_directory, fn) }
    end

    def beamify(erl_file)
      basename = File.basename(erl_file, '.erl')

      if basename == erl_file
        raise NotAnErlangFileError.new("#{erl_file} is not a .erl file.")
      end

      basename += '.beam'
    end

    def erlc(filename, opts={})

      output_dir = opts[:to] || "./"

      cps = code_path_args(opts[:paths])
      incs = include_args(opts[:include])
      warns = warning_args(opts[:warnings])

      output_dir_arg = "-o #{output_dir} "

      beam_name = beamify(filename)

      full_beam = File.join(output_dir, beam_name)

      return true if File.exists?(full_beam)

      # FIXME use rake's FileUtils#sh for this.
      erlc_command = "erlc #{cps} #{warns} #{incs} #{output_dir_arg} #{filename}"

      puts erlc_command
      output = `#{erlc_command}`

      # TODO $? is the last subprocess sent out. Find a less cryptic
      # way of accessing it

      # A non-zero exit status means something went wrong
      if $?.exitstatus != 0

        raise ErlangBuildError.new("Build of '#{filename}' failed with output:\n#{output}\n")
      end

      puts "Built #{full_beam}.\n\n"
      return true
    end

    def code_path_args(paths)
      (paths || []).map{|path| "-pa #{path} " }
    end

    def include_args(paths)
      (paths || []).map{|inc| "-I #{inc} " }
    end

    def warning_args(warnings)
      if warnings && ! warnings.empty?
        "-W #{warnings.join(' ')} "
      else
        ""
      end
    end
  end
end