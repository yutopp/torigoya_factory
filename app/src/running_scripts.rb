require 'singleton'


class StdoutLog
  def initialize(line)
    @line = line
  end
  attr_reader :line
end

class StderrLog
  def initialize(line)
    @line = line
  end
  attr_reader :line
end


class Status
  def initialize(name)
    @name = name
    @is_active = true
    @is_updated = false
    @logs = []
    @log_id = nil
    @thread = nil
  end
  attr_reader :name, :is_active, :is_updated, :logs, :log_id

  def finished( is_updated, log_id )
    @is_active = false
    @is_updated = is_updated
    @log_id = log_id
  end

  def append_stdout_line(line)
    @logs << StdoutLog.new(line)
  end

  def append_stderr_line(line)
    @logs << StderrLog.new(line)
  end

  def bind(thread)
    @thread = thread
  end

  def join()
    @thread.join unless @thread.nil?
    @thread = nil
  end

  def cleanup_if_unused()
    unless @is_active
      @logs = []
    end
  end
end # class Status


class RunningScripts
  include Singleton

  def initialize()
    @tasks = []
  end
  attr_reader :tasks

  def make_running_status(name)
    s = Status.new(name)
    @tasks << s
    return s
  end

  def task_at(index)
    raise "task_at :: out of range ${index}" if index < 0 || index >= @tasks.length
    return @tasks[index]
  end
end


##
class TaskQueue
  include Singleton

  #
  def initialize()
    @queue = Queue.new
    @tasks = []

    @m = Mutex.new

    @th = Thread.new do
      while td = @queue.pop
        begin
          if td.name != "<NONE>"
            status = install(td.name, td.do_reuse)
            status.join
          end

          #
          @m.synchronize do
            @tasks = @tasks.drop(1)

            if @tasks.size == 0
              message, err = register_to_repository()
              if err.nil?
                r, is_error = update_nodes_proc_table_with_error_handling()
                unless is_error
                  r, is_error = update_nodes_packages_with_error_handling()
                end
              end
            end
          end

          rescue => e
        end
      end
    end
  end
  attr_reader :tasks

  def add_task(name, do_reuse)
    td = TaskDetail.new(name, do_reuse)

    @m.synchronize do
      @tasks << td
    end

    @queue.push(td)
  end

  private
  class TaskDetail
    def initialize(name, do_reuse)
      @name = name
      @do_reuse = do_reuse
    end
    attr_reader :name, :do_reuse
  end
end


##
def add_to_install_task(name, do_reuse = false)
  tq = TaskQueue.instance
  tq.add_task(name, do_reuse)
end

def get_install_tasks_queue
  tq = TaskQueue.instance
  return tq.tasks
end

##
def install(name, do_reuse = false)
  builder = Torigoya::BuildServer::Builder.new(C)

  #
  status = RunningScripts.instance.make_running_status(name)

  #
  th = Thread.new do
    begin
      updated = builder.build_and_install_by_name(name, do_reuse) do |type, line|
        case type
        when :out
          status.append_stdout_line(line)
        when :err
          status.append_stderr_line(line)
        end # case
      end # block update=

    rescue IOError => e
      puts "rescue => #{e}"

    ensure
      log_id = nil
      begin
        ActiveRecord::Base.connection_pool.with_connection do
          log = Log.new(title: "packaging: #{status.name}",
                        content: status.logs.map{|l| l.class.to_s + " : " + l.line}.join(''),
                        status: if updated then 0 else -1 end
                        )
          log.save!

          log_id = log.id
        end

        if C.notification == 'twitter'
          puts "Sending a tweet..."
          sentence = if updated then
                       "OK! #{name}."
                     else
                       "Failed to build #{name}."
                     end
          C.twitter_client.update("@yutopp @wx257osn2 #{sentence} #{Time.now} / http://packages.sc.yutopp.net:8080/log/#{log_id}")
        end

      rescue => e
        puts "rescued in install => #{e}"
        # ...
      end

      status.finished(updated, log_id)
    end
  end # Thread.new

  #
  status.bind(th)

  return status
end


##
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

ensure
  status.cleanup_if_unused
end


##
def register_to_repository()
  builder = Torigoya::BuildServer::Builder.new(C)

  #
  message, err = builder.save_packages do |placeholder_path, package_profiles|
    update_requred, err = Torigoya::Package::Recoder.save_available_packages_table(C.apt_repository_path, package_profiles)
    next "", err if !err.nil? || update_requred == false

    message, err = Torigoya::Package::Recoder.add_to_apt_repository(C.apt_repository_path, placeholder_path, package_profiles)
    next message, err
  end

  ActiveRecord::Base.connection_pool.with_connection do
    if err.nil?
      l = Log.new(title: "register_to_repository: success",
                  content: message,
                  status: 0,
                  )
      l.save!

    else
      l = Log.new(title: "register_to_repository: failed",
                  content: err.to_s,
                  status: -1,
                  )
      l.save!
    end
  end

  # update proc_table
  if err.nil?
    is_succeeded, p_message = update_proc_profile
    msg = "#{message} / #{p_message}"
    if is_succeeded
      return [msg, nil]
    else
      return [msg, p_message]
    end
  end

  return [message, err]
end


##
def update_proc_profile
  updater = Torigoya::BuildServer::ProcProfileUpdater.new(C)
  is_succeeded, message = updater.host_updated_zip

  ActiveRecord::Base.connection_pool.with_connection do
    if is_succeeded
      l = Log.new(title: "update_proc_profile: success",
                  content: message,
                  status: 0,
                  )
      l.save!

    else
      l = Log.new(title: "update_proc_profile: failed",
                  content: message,
                  status: -1,
                  )
      l.save!
    end
  end

  return is_succeeded, message
end


##
def update_nodes_proc_table_with_error_handling()
  results = update_nodes_proc_table()
  title, status, is_error = if results.any? {|r| r[:is_error] == true}
                              ["there are any error", -1, true]
                            else
                              ["success", 0, false]
                            end

  ActiveRecord::Base.connection_pool.with_connection do
    log = Log.new(title: "update proc_table: #{title}",
                  content: results.to_s,
                  status: status
                  )
    log.save!
  end

  return results, is_error
end


##
def update_nodes_proc_table()
  m = NodeApiAddress.find(1)
  address = m.address

  response = JSON.parse(Net::HTTP.get(URI.parse(address)))
  raise "is_error != false" if response["is_error"] != false

  results = []

  q = Queue.new
  response["nodes"].each{|n| q.push(n)}
  exec_in_workers(q) do |n|
    r = {
      address: n["addr"],
      port: n["port"],
    }

    begin
      s = TorigoyaKit::Session.new(n["addr"], n["port"])
      s.update_proc_table()

      r[:is_error] = false
      results << r

    rescue => e
      r[:is_error] = true
      results << r
    end
  end # exec_in_workers do

  return results
end


##
def update_nodes_packages_with_error_handling()
  results = update_nodes_packages()
  title, status, is_error = if results.any? {|r| r[:is_error] == true}
                              ["there are any error", -1, true]
                            else
                              ["success", 0, false]
                            end

  ActiveRecord::Base.connection_pool.with_connection do
    log = Log.new(title: "update packages: #{title}",
                  content: results.to_s,
                  status: status
                  )
    log.save!
  end

  return results, is_error
end

def update_nodes_packages()
  m = NodeApiAddress.find(1)
  address = m.address

  response = JSON.parse(Net::HTTP.get(URI.parse(address)))
  raise "is_error != false" if response["is_error"] != false

  results = []

  q = Queue.new
  response["nodes"].each{|n| q.push(n)}
  exec_in_workers(q) do |n|
    r = {
      address: n["addr"],
      port: n["port"],
    }

    begin
      s = TorigoyaKit::Session.new(n["addr"], n["port"])
      s.update_packages()

      r[:is_error] = false
      results << r

    rescue => e
      r[:is_error] = true
      results << r
    end
  end # exec_in_workers do

  return results
end


##
def exec_in_workers(queue, &block)
  workers = (0...4).map do
    Thread.new do
      begin
        while n = queue.pop(true)
          block.call(n)
        end
      rescue ThreadError
      end
    end
  end
  workers.map(&:join)
end
