require 'rake'
require 'rake/tasklib'

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

  def define
    fail "Name required" unless name
    namespace name do

      task :build_sources do

        sources.each do |file|

          erlc(
            file,
            :to => output_path, :paths => code_paths,
            :include => include_paths, :warnings => warnings
          )
        end
      end

      task :build_app_sources do
        app_sources.each do |fn|
          install( fn, File.join(output_path, File.basename(fn)) )
        end
      end

      task :build_dependencies => dependencies_build_tasks

      # FIXME edocs and extra files
      task :build => [:build_dependencies, :build_sources, :build_app_sources]

      task :clean => [] do

        if generated_files.any?{|fn| File.exist? fn}
          puts "Cleaning #{name}"

          generated_files.each{|fn| File.delete(fn) if File.exist?(fn) }
        end
      end # end clean task

      task :build_test_sources do

        test_sources.each do |file|
          erlc file,
          :to => test_output_path,
          :paths => test_code_paths,
          :include => test_include_paths
        end
      end

      task :test => :build_test_sources do
        old_dir = pwd

        # This is only done because I haven't worked out the extra/data/dist
        # file stuff which would be included for tests

        chdir test_output_path
        sh "erl -noshell #{code_path_args(test_code_paths)} #{include_args(test_include_paths)} #{warning_args(test_warnings)}-o #{test_output_path} -s test_runner run_all"
        chdir old_dir
      end

      task :clean_test_sources do
        generated_test_files.each do |file|
          File.delete(fn) if File.exist?(fn)
        end
      end

      task :retest => [:clean_test_sources, :test]
    end
  end

  # Defines the tasks in Rake application instead of just its own namespace
  def top_level_define!
    task :build   =>  "#{name}:build"
    task :clean   =>  current_and_dependency_tasks(:clean)
    task :test    =>  "#{name}:test"
    task :retest  =>  "#{name}:retest"
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

  private

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

# Examples

this_dir = File.dirname(__FILE__)

eunit = ErlangProject.new('eunit', File.join(this_dir, 'lib/eunit')) do |proj|

  # Required ordering.
  proj.sources = %w(
    src/eunit_autoexport.erl
    src/eunit_striptests.erl
    src/eunit.erl
    src/eunit_tests.erl
    src/eunit_server.erl
    src/eunit_proc.erl
    src/eunit_serial.erl
    src/eunit_test.erl
    src/eunit_lib.erl
    src/eunit_data.erl
    src/eunit_tty.erl
    src/code_monitor.erl
    src/file_monitor.erl
    src/autoload.erl
  )

  proj.include_paths = ["include"]
  proj.warnings = %w(+warn_unused_vars +nowarn_shadow_vars +warn_unused_import)
end

mochiweb = ErlangProject.new('mochiweb', File.join(this_dir, 'lib/mochiweb'))

smerl = ErlangProject.new('smerl', File.join(this_dir, 'lib/smerl')) do |proj|
  proj.sources = ['smerl.erl']
  proj.output_path = '../../ebin'
end

recess = ErlangProject.new('recess', this_dir) do |proj|
  proj.dependencies = [eunit, mochiweb, smerl]
  proj.test_include_paths = ["./lib/include/eunit"]
end

recess.top_level_define!
