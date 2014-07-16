#encodind: utf-8
require 'sinatra'
require 'sinatra/streaming'
require 'sinatra/reloader'
require 'sinatra/assetpack'
require "sinatra/activerecord"

require 'digest/sha2'

require_relative "src/config"
require_relative "src/builder"
require_relative "src/recorder"
require_relative "src/running_scripts"

#
C = Torigoya::BuildServer::Config.new
HMAC_DIGEST = OpenSSL::Digest::Digest.new('sha1')

class Log < ActiveRecord::Base
end

class WebHook < ActiveRecord::Base
  self.table_name = 'webhooks'
end

class ScheduledTask < ActiveRecord::Base
end

#
configure do
  set :server, :thin
  set :bind, '0.0.0.0'
  set :port, 8080
  enable :sessions
  set :session_secret, C.session_secret
  set :database_file, 'database.yml'

  also_reload 'src/*.rb'
end

helpers do
  def login?
    return session[:is_logged_in] == true
  end
end

register Sinatra::AssetPack
assets do
  serve '/css', :from => 'css'
  css :application, ['/css/style.css']
end

#
get '/' do
  @builder = Torigoya::BuildServer::Builder.new(C)
  @tasks = RunningScripts.instance.tasks
  @is_logged_in = login?
  @is_nopass_mode = C.admin_pass_sha512.nil?
  @logs = Log.all

  erb 'index.html'.to_sym
end

get '/pull_package_list' do
  builder = Torigoya::BuildServer::Builder.new(C)
  succeeded, message = builder.pull_package_list
  if succeeded
    redirect '/'
  else
    return message
  end
end

get '/login' do
  erb 'login.html'.to_sym
end

post "/login" do
  if params.has_key?("password")
    if C.admin_pass_sha512.nil? || C.admin_pass_sha512 == Digest::SHA512.hexdigest(params["password"])
      session[:is_logged_in] = true
      redirect '/'
    else
      return "Authenication failed"
    end
  else
    return "error"
  end
end

get "/logout" do
  session[:is_logged_in] = false
  redirect '/'
end






#
get '/packaging_and_install/:name' do
  if login?
    begin
      name = params['name']
      status = install(name, false)

      stream_status(status)

    rescue => e
      "reised #{e}"
    end

  else
    return "To do this action, admin privilege is required."
  end
end

#
get '/packaging_and_install/:name/reuse' do
  if login?
    begin
      name = params['name']
      status = install(name, true)

      stream_status(status)

    rescue => e
      "reised #{e}"
    end

  else
    return "To do this action, admin privilege is required."
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
get '/temp' do
  builder = Torigoya::BuildServer::Builder.new(C)

  @dir_name = builder.placeholder_path
  @files = []
  Dir.chdir(builder.placeholder_path) do
    Dir.glob('*.deb') do |f_name|
      @files << f_name
    end
  end

  erb 'temp.html'.to_sym
end

get '/temp/delete/:name' do
  if login?
    builder = Torigoya::BuildServer::Builder.new(C)

    name = params['name']

    Dir.chdir(builder.placeholder_path) do
      File.delete(name) if File.exists?(name)
    end

    redirect '/temp'

  else
    return "To do this action, admin privilege is required."
  end
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
  if login?
    name = params['name']

    @err = Torigoya::Package::Recoder.remove_from_apt_repository(C.apt_repository_path, name)
    if @err != nil
      erb 'packages_error.html'.to_sym
    else
      redirect '/packages'
    end

  else
    return "To do this action, admin privilege is required."
  end
end


get '/install' do
  if login?
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

  else
    return "To do this action, admin privilege is required."
  end
end


# ==================================================
# webhook
# ==================================================

get "/webhooks" do
  @hooks = WebHook.all
  erb 'webhooks.html'.to_sym
end

post "/webhooks/append" do
  if login?
    begin
      target = params['target']
      secret = params['secret']
      script = params['script']
      raise "target is nil" if target.nil?
      raise "secret is nil" if secret.nil?
      raise "script is nil" if script.nil?

      hook = WebHook.new(target: target, secret: secret, script: script)
      hook.save!

      redirect "/webhooks"

    rescue => e
      "reised: #{e}"
    end

  else
    return "To do this action, admin privilege is required."
  end
end

post "/webhooks/update/:id" do
  if login?
    begin
      id = params['id']
      target = params['target']
      secret = params['secret']
      script = params['script']
      raise "id is nil" if id.nil?
      raise "target is nil" if target.nil?
      raise "secret is nil" if secret.nil?
      raise "script is nil" if script.nil?

      hook = WebHook.find(id.to_i)
      hook.target = target
      hook.secret = secret
      hook.script = script
      hook.save!

      redirect "/webhooks"

    rescue => e
      "reised: #{e}"
    end

  else
    return "To do this action, admin privilege is required."
  end
end

post "/webhooks/delete/:id" do
  if login?
    begin
      id = params['id']
      raise "id is nil" if id.nil?

      hook = WebHook.find(id.to_i)
      hook.destroy!

      redirect "/webhooks"

    rescue => e
      "reised: #{e}"
    end

  else
    return "To do this action, admin privilege is required."
  end
end

# requested by webhook
post "/webhook/:target" do
  begin
    target = params['target']
    body = request.body.read
    payload = JSON.parse(body)

    github_sig = request.env['HTTP_X_HUB_SIGNATURE']

    hook = WebHook.find_by_target(target)

    expected_sig = 'sha1='+OpenSSL::HMAC.hexdigest(HMAC_DIGEST, hook.secret, body)
    raise "invalid signature" if github_sig != expected_sig

    payload = JSON.parse(body)
    log = Log.new(title: "webhook: #{target}", content: "#{payload.to_s}", status: 0)
    log.save!

    install(hook.script, false)

    return 200

  rescue => e
    puts "exception: #{e}"
    e.backtrace.each do |t|
      puts "> #{t}"
    end
    return 400
  end
end
