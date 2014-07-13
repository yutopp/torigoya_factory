#encodind: utf-8
require 'sinatra'
require 'sinatra/streaming'
require 'sinatra/reloader'

require_relative "src/config"
require_relative "src/builder"
require_relative "src/recorder"
require_relative "src/running_scripts"

#
C = Torigoya::BuildServer::Config.new

#
set :server, :thin
set :bind, '0.0.0.0'
set :port, 8080

also_reload 'src/*.rb'


#
get '/' do
  @builder = Torigoya::BuildServer::Builder.new(C)
  @tasks = RunningScripts.instance.tasks

  erb 'index.html'.to_sym
end


def stream_status(status)
  stream do |out|
    begin
      output_index = 0
      while status.is_active || output_index < status.logs.length
        cur = status.logs.length
        status.logs[output_index...cur].each do |l|
          out.write(l.class.to_s + " : " + l.line + "<br>")
        end
        output_index = cur

        sleep 0.5
      end
      status.join

      out.write status.is_updated ? "succeeded!<br>" : "failed<br>"

    rescue IOError => e
      puts e
    end
  end
end

#
get '/packaging_and_install/:name' do
  begin
    name = params['name']
    status = install(name, false)

    stream_status(status)

  rescue => e
    "reised #{e}"
  end
end

#
get '/packaging_and_install/:name/reuse' do
  begin
    name = params['name']
    status = install(name, true)

    stream_status(status)

  rescue => e
    "reised #{e}"
  end
end

#
get '/status/:index' do
  begin
    index = params['index'].to_i
    status = RunningScripts.instance.task_at(index)

    stream_status(status)

  rescue => e
    "reised #{e}"
  end
end

#
get '/pre' do
  builder = Torigoya::BuildServer::Builder.new(C)

  @dir_name = builder.placeholder_path
  @files = []
  Dir.chdir(builder.placeholder_path) do
    Dir.glob('*.deb') do |f_name|
      @files << f_name
    end
  end

  erb 'pre.html'.to_sym
end

get '/pre/delete/:name' do
  builder = Torigoya::BuildServer::Builder.new(C)

  name = params['name']

  Dir.chdir(builder.placeholder_path) do
    File.delete(name) if File.exists?(name)
  end

  redirect '/pre'
end

# ========================================
get '/packages' do
  @registered_packages, @err = Torigoya::Package::Recoder.packages_list(C.apt_repository_path)
  if @registered_packages == nil
    erb 'packages_error.html'.to_sym
    return
  end

  erb 'packages.html'.to_sym
end

get '/packages/delete/:name' do
  name = params['name']

  @err = Torigoya::Package::Recoder.remove_from_apt_repository(C.apt_repository_path, name)
  if @err != nil
    erb 'packages_error.html'.to_sym
  else
    redirect '/packages'
  end
end


get '/install' do
  begin
    stream do |out|
      builder = Torigoya::BuildServer::Builder.new(C)

      #
      message, err = builder.save_packages do |placeholder_path, package_profiles|
        update_requred, err = Torigoya::Package::Recoder.save_available_packages_table(C.apt_repository_path, package_profiles)
        next "", err if !err.nil? || update_requred == false

        message, err = Torigoya::Package::Recoder.add_to_apt_repository(C.apt_repository_path, placeholder_path, package_profiles)
        next message, err
      end
      if err.nil?
        out.write "succees: #{message}"
      else
        out.write "failed: #{err}"
      end
    end

  rescue => e
    puts "exception: #{e} / #{e.backtrace}"
  end
end
