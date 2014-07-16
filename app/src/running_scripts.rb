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
    @thread = nil
  end
  attr_reader :name, :is_active, :is_updated, :logs

  def finished( is_updated )
    @is_active = false
    @is_updated = is_updated
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
      # client.update("failed #{name} @yutopp") unless updated
      status.finished(updated)
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
end
