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

also_reload 'src/proc_factory/*.rb'


#
get '/' do
  @builder = Torigoya::BuildServer::Builder.new(C)
  @tasks = RunningScripts.instance.tasks

  erb 'index.html'.to_sym
end



#
get '/packaging_and_install/:name' do
  stream do |out|
    begin
      name = params['name']

      status = install(name, false)

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
get '/packaging_and_install/:name/reuse' do
  name = params['name']
  install(name, true)
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

=begin

=end

get '/install' do
  begin
    stream do |out|
      builder = Torigoya::BuildServer::Builder.new(C)

      #
      err = builder.save_packages do |repository_path, placeholder_path, package_profiles|
        update_requred, err = Torigoya::Package::Recoder.save_available_packages_table(repository_path, package_profiles)
        next err if !err.nil? || update_requred == false

        err = Torigoya::Package::Recoder.add_to_apt_repository(repository_path, placeholder_path, package_profiles)
        next err
      end
      if err.nil?
        out.write"succees"
      else
        out.write"failed: #{err}"
      end
    end

  rescue IOError => e
    puts e
  end
end
