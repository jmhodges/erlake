
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

task :build_dependencies => [:build_smerl, :build_mochiweb, :build_eunit]

task :build_recess => [:build_dependencies] do

  sources = FileList['./src/*.erl']

  output_directory = './ebin'

  sources.each do |file|
    erlc file,
    :to => output_directory,
    :paths => ["./ebin", "./lib/eunit/ebin", "./lib/mochiweb/ebin"],
    :include => ["./lib/eunit/include"]
  end
end

task :clean_recess do
  # FIXME deletes smerl.beam instead of just letting it be
  FileList['./ebin/*'].each do |fn|
    if File.exist? fn
      puts "Deleting #{fn}"
      File.delete fn
    end
  end
end

task :build => :build_recess

task :clean => [:clean_smerl, :clean_mochiweb, :clean_eunit, :clean_recess]

task :build_tests => :build do
  sources = FileList['./tests/*.erl']

  output_directory = './tests/ebin'

  sources.each do |file|
    erlc file,
    :to => output_directory,
    :paths => ["./ebin", "./lib/eunit/ebin", "./lib/mochiweb/ebin"],
    :include => ["./lib/eunit/include"]
  end
end

task :clean_tests => [:clean_recess] do
  FileList['./tests/ebin/*'].each do |fn|
    if File.exist? fn
      puts "Deleting #{fn}"
      File.delete fn
    end
  end
end

task :test => :build_tests do
  output_directory = "./tests/ebin"
  erl_test_command = "cd #{output_directory} && erl -noshell -pa ../../ebin -pa ../../lib/eunit/ebin -pa ../../lib/mochiweb/ebin -s test_runner run_all"
  puts erl_test_command
  `#{erl_test_command}`
end

task :retest => [:clean_tests, :test]