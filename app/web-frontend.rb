#encodind: utf-8
require 'sinatra'
require 'sinatra/streaming'
require 'sinatra/reloader'
require 'sinatra/assetpack'
require "sinatra/activerecord"
require 'erubis'

require 'net/http'
require 'digest/sha2'
require 'json'

require 'torigoya_kit'

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

class NodeApiAddress < ActiveRecord::Base
end


#
configure do
  set :server, :thin
  set :bind, '0.0.0.0'
  set :port, 8080
  enable :sessions
  set :session_secret, C.session_secret
  set :database_file, 'database.yml'
  set :erb, :escape_html => true

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
  css :application, [
                     '/css/style.css',
                     '/css/bootstrap.min.css',
                     '/css/bootstrap-theme.min.css'
                    ]

  serve '/js', :from => 'js'
  js :application, [
                    '/js/jquery-2.1.1.min.js',
                    '/js/bootstrap.min.js'
                   ]

  serve '/images', from: 'images'

  serve '/fonts', :from => 'fonts'
end

after do
  ActiveRecord::Base.connection.close
end


def unauthed_error()
  status 401
  return "To do this action, admin privilege is required."
end

def exception_raised(e)
  begin
    content = e.backtrace.join("\n")
    ActiveRecord::Base.connection_pool.with_connection do
      log = Log.new(title: "exception: #{e}", content: content, status: -1)
      log.save!
    end

  rescue => e
    # ...
  end

  status 500
  return "exception raised: #{e}"
end

# ========================================
#
# ========================================
get '/' do
  @builder = Torigoya::BuildServer::Builder.new(C)
  @tasks = RunningScripts.instance.tasks
  @tasks_queue = get_install_tasks_queue()

  erb 'index.html'.to_sym
end


# ========================================
#
# ========================================
get '/logs' do
  ActiveRecord::Base.connection_pool.with_connection do
    @logs = Log.all.order('created_at DESC')
  end

  erb 'logs.html'.to_sym
end


# ========================================
#
# ========================================
get '/deliver_messages' do
  if login?
    m = nil
    ActiveRecord::Base.connection_pool.with_connection do
      begin
        m = NodeApiAddress.find(1)
      rescue
        m = NodeApiAddress.new(:address => "???")
        m.save!
      end
    end

    @address = m.address
    erb 'deliver_messages.html'.to_sym

  else
    return unauthed_error()
  end
end

post '/deliver_messages' do
  if login?
    begin
      address = params['address']
      raise "address is nil" if address.nil?

      ActiveRecord::Base.connection_pool.with_connection do
        m = NodeApiAddress.find(1)
        m.address = address
        m.save!
      end

      redirect "/deliver_messages"

    rescue => e
      return exception_raised(e)
    end

  else
    return unauthed_error()
  end
end


get '/deliver_messages/update_proc_table' do
  if login?
    begin
      @results, e = update_nodes_proc_table_with_error_handling()
      erb 'update_proc_table.html'.to_sym

    rescue => e
      return exception_raised(e)
    end

  else
    return unauthed_error()
  end
end


get '/deliver_messages/update_packages' do
  if login?
    begin
      @results, e = update_nodes_packages_with_error_handling()
      erb 'update_packages.html'.to_sym

    rescue => e
      return exception_raised(e)
    end

  else
    return unauthed_error()
  end
end


# ========================================
#
# ========================================
get '/pull_package_list' do
  if login?
    builder = Torigoya::BuildServer::Builder.new(C)
    succeeded, message = builder.pull_package_list
    if succeeded
      redirect '/'
    else
      return message
    end

  else
    return unauthed_error()
  end
end



# ========================================
#
# ========================================
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



# ========================================
#
# ========================================
#
get "/logout" do
  session[:is_logged_in] = false
  redirect '/'
end



# ========================================
#
# ========================================
#
get '/packaging_and_install/*' do |name|
  if login?
    begin
      if name[name.length-6, 6] == "/reuse"
        status = install(name[0, name.length-6], true)
      else
        status = install(name, false)
      end

      stream_status(status)

    rescue => e
      return exception_raised(e)
    end

  else
    return unauthed_error()
  end
end


# ========================================
#
# ========================================
#
get '/packaging_and_install_lazy/*' do |name|
  if login?
    begin
      if name[name.length-6, 6] == "/reuse"
        add_to_install_task(name[0, name.length-6], true)
      else
        add_to_install_task(name, false)
      end

      redirect '/'

    rescue => e
      return exception_raised(e)
    end

  else
    return unauthed_error()
  end
end


# ========================================
#
# ========================================
#
get '/status/:index' do
  begin
    index = params['index'].to_i
    status = RunningScripts.instance.task_at(index)
    if status.is_active
      stream_status(status)
    else
      id = status.log_id
      raise "log_id is nil.." if id.nil?

      redirect "/log/#{id}"
    end

  rescue => e
    return exception_raised(e)
  end
end


# ========================================
#
# ========================================
#
get '/generate_proc_profile' do
  if login?
    is_succeeded, message = update_proc_profile
    #
    if is_succeeded
      @body = "succees: #{message}"
    else
      @body = "failed: #{err}"
    end
    erb 'generate_proc_profile.html'.to_sym

  else
    return unauthed_error()
  end
end


# ========================================
#
# ========================================
#
get '/temp' do
  if login?
    builder = Torigoya::BuildServer::Builder.new(C)

    @dir_name = builder.placeholder_path
    @files = []
    Dir.chdir(builder.placeholder_path) do
      Dir.glob('*.deb') do |f_name|
        @files << f_name
      end
    end

    erb 'temp.html'.to_sym

  else
    return unauthed_error()
  end
end

#
get '/temp/delete/:name' do
  if login?
    builder = Torigoya::BuildServer::Builder.new(C)

    name = params['name']

    Dir.chdir(builder.placeholder_path) do
      File.delete(name) if File.exists?(name)
    end

    redirect '/temp'

  else
    return unauthed_error()
  end
end



# ========================================
#
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
    return unauthed_error()
  end
end



# ========================================
#
# ========================================
get '/register_to_repository' do
  if login?
    begin
      message, err = register_to_repository()

      #
      if err.nil?
        @body = "succees: #{message}"
      else
        @body = "failed: #{err}"
      end
      erb 'register_to_repository.html'.to_sym

    rescue => e
      return exception_raised(e)
    end

  else
    return unauthed_error()
  end
end



# ==================================================
# webhook
# ==================================================

get "/webhooks" do
  if login?
    @hooks = WebHook.all
    erb 'webhooks.html'.to_sym
  else
    return unauthed_error()
  end
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

      ActiveRecord::Base.connection_pool.with_connection do
        hook = WebHook.new(target: target, secret: secret, script: script)
        hook.save!
      end

      redirect "/webhooks"

    rescue => e
      return exception_raised(e)
    end

  else
    return unauthed_error()
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

      ActiveRecord::Base.connection_pool.with_connection do
        hook = WebHook.find(id.to_i)
        hook.target = target
        hook.secret = secret
        hook.script = script
        hook.save!
      end

      redirect "/webhooks"

    rescue => e
      return exception_raised(e)
    end

  else
    return unauthed_error()
  end
end

post "/webhooks/delete/:id" do
  if login?
    begin
      id = params['id']
      raise "id is nil" if id.nil?

      ActiveRecord::Base.connection_pool.with_connection do
        hook = WebHook.find(id.to_i)
        hook.destroy!
      end

      redirect "/webhooks"

    rescue => e
      return exception_raised(e)
    end

  else
    return unauthed_error()
  end
end

# requested by webhook
post "/webhook/:target" do
  begin
    target = params['target']
    body = request.body.read
    payload = JSON.parse(body)

    github_sig = request.env['HTTP_X_HUB_SIGNATURE']

    hook = nil
    ActiveRecord::Base.connection_pool.with_connection do
      hook = WebHook.find_by_target(target)
    end

    expected_sig = 'sha1='+OpenSSL::HMAC.hexdigest(HMAC_DIGEST, hook.secret, body)
    raise "invalid signature" if github_sig != expected_sig

    ActiveRecord::Base.connection_pool.with_connection do
      payload = JSON.parse(body)
      log = Log.new(title: "webhook: #{target}", content: "#{payload.to_s}", status: 0)
      log.save!
    end

    #
    add_to_install_task(hook.script, false)

    return 200

  rescue => e
    return exception_raised(e)
  end
end



# ========================================
#
# ========================================
get "/log/:id" do
  begin
    id = params['id']
    raise "id is nil" if id.nil?
    ActiveRecord::Base.connection_pool.with_connection do
      @log = Log.find(id.to_i)
    end

    erb 'log.html'.to_sym

  rescue => e
    exception_raised(e)
  end
end

get "/log/delete/:id" do
  if login?
    begin
      id = params['id']
      raise "id is nil" if id.nil?

      ActiveRecord::Base.connection_pool.with_connection do
        Log.find(id.to_i).destroy!
      end

      redirect '/'

    rescue => e
      exception_raised(e)
    end

  else
    return unauthed_error()
  end
end
