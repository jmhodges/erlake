require 'rake'
require 'rake/tasklib'

class NoProjectDirectoryGivenError < StandardError; end
class NoProjectNameGivenError < StandardError; end

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
    
    init
    
    if block_given?
      yield self 
      define
    end
  end
  
  def init
    self.output_path = default_output_path
    self.sources = default_sources
    self.app_sources = default_app_sources
    self.include_paths = default_include_paths
    self.dependencies = default_dependencies
    self.warnings = default_warnings
    
    self.code_paths = [ output_path ]
    
    self.test_sources = default_test_sources
    self.test_output_path = default_test_output_path
    self.test_code_paths = default_test_code_paths
    self.test_include_paths = default_test_include_paths
    self.test_warnings = default_test_warnings
  end
  
  def output_path=(dir)
    @output_path = dir_join dir
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
  
  def dependencies=(deps)
    deps.each do |d|
      
      unless code_paths.include? d.output_path
        self.code_paths << d.output_path 
      end
    end
    
    @dependencies = deps
  end
  
  def dependencies
    @dependencies.compact.uniq
  end
  
  def code_paths
    @code_paths.compact.uniq
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
      
      task :build => [:build_dependencies] do
        # FIXME edocs and extra files
        
        # FIXME this any could take a while. do something clever to make 
        # the output as nice as it is now.
        if generated_files.any?{|fn| ! File.exist? fn }
          puts "Building #{name}"
          
          build_sources
          build_app_sources
        end
      end # end build task
      
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
  def define!
    
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
   
  def default_dependencies; []; end
  
  def default_warnings; []; end

  def default_test_sources
    FileList["tests/*.erl"]
  end
  
  def default_test_output_path
    "tests/ebin"
  end
  
  def default_test_code_paths
    code_paths || default_code_paths
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

    cps = code_path_args(opts[:code_paths])
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

    puts "Built #{full_beam}.\n"
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
      "-W #{opts[:warnings].join(' ')} "
    else
      ""
    end
  end
end

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
recess = ErlangProject.new('recess', this_dir) do |proj|
  proj.dependencies = [eunit]
  proj.test_include_paths = ["./lib/include/eunit"]
end

recess.define!

class NotAnErlangFileError < StandardError; end

class ErlangBuildError < StandardError; end

def beam_filename(erl_file)
  basename = File.basename(erl_file, '.erl')

  if basename == erl_file
    raise NotAnErlangFileError.new("#{erl_file} is not a .erl file.")
  end

  basename += '.beam'
end

def erlc(filename, opts={})

  output_directory = opts[:to] || "./"

  pa = (opts[:paths] || []).map{|path| "-pa #{path} " }

  incs = (opts[:include] || []).map{|inc| "-I #{inc} " }

  if opts[:warnings]
    warns = "-W #{opts[:warnings].join(' ')} "
  end

  output_dir = "-o #{output_directory} "

  beam_name = beam_filename(filename)

  full_beam = File.join(output_directory, beam_name)

  return true if File.exists?(full_beam)

  # FIXME use rake's FileUtils#sh for this.
  erlc_command = "erlc #{pa} #{warns} #{incs} #{output_dir} #{filename}"

  puts erlc_command
  output = `#{erlc_command}`

  # TODO $? is the last subprocess sent out. Find a less cryptic
  # way of accessing it

  # A non-zero exit status means something went wrong
  if $?.exitstatus != 0

    raise ErlangBuildError.new("Build of '#{filename}' failed with output:\n#{output}\n")
  end

  puts "Built #{full_beam}."
  return true
end

task :build_eunit do
  sources = %w(
    eunit_autoexport.erl
    eunit_striptests.erl
    eunit.erl
    eunit_tests.erl
    eunit_server.erl
    eunit_proc.erl
    eunit_serial.erl
    eunit_test.erl
    eunit_lib.erl
    eunit_data.erl
    eunit_tty.erl
    code_monitor.erl
    file_monitor.erl
    autoload.erl
  )

  eunit_sources = sources.map{|f| File.join('./lib/eunit/src', f)}

  output_directory = './lib/eunit/ebin'

  warnings = %w(+warn_unused_vars +nowarn_shadow_vars +warn_unused_import)

  eunit_sources.each do |file|
    erlc file,
      :to => output_directory, :paths => [output_directory],
      :include => ["./lib/eunit/include"], :warnings => warnings
  end

  app_sources = ['eunit.app', 'eunit.appup']

  app_sources.each do |fn|
    install(
      File.join('./lib/eunit/src', fn), File.join(output_directory, fn)
    )
  end

end

task :build_mochiweb do
  sources = %w(
    mochihex.erl
    mochijson.erl
    mochijson2.erl
    mochinum.erl
    mochiweb.erl
    mochiweb_app.erl
    mochiweb_charref.erl
    mochiweb_cookies.erl
    mochiweb_echo.erl
    mochiweb_headers.erl
    mochiweb_html.erl
    mochiweb_http.erl
    mochiweb_multipart.erl
    mochiweb_request.erl
    mochiweb_response.erl
    mochiweb_skel.erl
    mochiweb_socket_server.erl
    mochiweb_sup.erl
    mochiweb_util.erl
    reloader.erl
  )

  output_directory = './lib/mochiweb/ebin'

  mochiweb_sources = sources.map{|f| File.join('./lib/mochiweb/src', f)}

  mochiweb_sources.each do |file|
    erlc file,
      :to => output_directory,
      :paths => [output_directory],
      :include => ["./lib/mochiweb/include"]
  end

  app_sources = ['mochiweb.app']

  app_sources.each do |fn|
    install(
      File.join('./lib/mochiweb/src', fn), File.join(output_directory, fn)
    )
  end
end

task :build_smerl do
  erlc 'lib/smerl/smerl.erl', :to => './ebin/'
end

task :clean_smerl do
  File.delete('./ebin/smerl.beam') if File.exist? './ebin/smerl.beam'
end

task :clean_eunit do
  FileList['./lib/eunit/ebin/*'].each do |fn|
    if File.exist? fn
      puts "Deleting #{fn}."
      File.delete fn
    end
  end
end

task :clean_mochiweb do
  FileList['./lib/mochiweb/ebin/*'].each do |fn|
    if File.exist? fn
      puts "Deleting #{fn}."
      File.delete fn
    end
  end
end

# task :build_dependencies => [:build_smerl, :build_mochiweb, :build_eunit]
# 
# task :build_recess => [:build_dependencies] do
# 
#   sources = FileList['./src/*.erl']
# 
#   output_directory = './ebin'
# 
#   sources.each do |file|
#     erlc file,
#     :to => output_directory,
#     :paths => ["./ebin", "./lib/eunit/ebin", "./lib/mochiweb/ebin"],
#     :include => ["./lib/eunit/include"]
#   end
# end
# 
# task :clean_recess do
#   # FIXME deletes smerl.beam instead of just letting it be
#   FileList['./ebin/*'].each do |fn|
#     if File.exist? fn
#       puts "Deleting #{fn}"
#       File.delete fn
#     end
#   end
# end

# task :build => :build_recess

# task :clean => [:clean_smerl, :clean_mochiweb, :clean_eunit, :clean_recess]

# task :build_tests => :build do
#   sources = FileList['./tests/*.erl']
# 
#   output_directory = './tests/ebin'
# 
#   sources.each do |file|
#     erlc file,
#     :to => output_directory,
#     :paths => ["./ebin", "./lib/eunit/ebin", "./lib/mochiweb/ebin"],
#     :include => ["./lib/eunit/include"]
#   end
# end
# 
# task :clean_tests => [:clean_recess] do
#   FileList['./tests/ebin/*'].each do |fn|
#     if File.exist? fn
#       puts "Deleting #{fn}"
#       File.delete fn
#     end
#   end
# end

# task :test => :build_tests do
#   output_directory = "./tests/ebin"
#   erl_test_command = "cd #{output_directory} && erl -noshell -pa ../../ebin -pa ../../lib/eunit/ebin -pa ../../lib/mochiweb/ebin -s test_runner run_all"
#   puts erl_test_command
#   `#{erl_test_command}`
# end
# 
# task :retest => [:clean_tests, :test]