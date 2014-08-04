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
        # client.update("failed #{name} @yutopp") unless updated
        log = Log.new(title: "packaging: #{status.name}",
                      content: status.logs.map{|l| l.class.to_s + " : " + l.line}.join(''),
                      status: if updated then 0 else -1 end
                      )
        log.save!
        log_id = log.id
      rescue => e
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
