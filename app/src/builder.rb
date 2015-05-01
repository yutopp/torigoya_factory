#!/usr/bin/env ruby
# encoding: utf-8
require 'fileutils'
require 'thread'
require 'torigoya_kit'
require 'singleton'
require 'shellwords'
require 'bundler'

module Torigoya
  module BuildServer
    class Guard
      include Singleton

      def initialize
        @m = Mutex.new
      end
      attr_reader :m

      def self.sync(&block)
        Guard.instance.m.synchronize &block
      end
    end

    class Builder
      def initialize(config)
        @config = config

        # show messages
        puts ""
        puts "=" * 50
        puts "== config"
        puts "=" * 50
        puts "install_path            : #{@config.install_path}"
        puts "workspace               : #{@config.workspace_path}"
        puts "package_scripts_path    : #{@config.package_scripts_path}"
        puts "placeholder_path        : #{@config.placeholder_path}"
        puts "apt_repository_path     : #{@config.apt_repository_path}"
        puts "platform system         : #{@config.target_system}"
        puts "arch                    : #{@config.target_arch}"
        puts "=" * 50

        raise "#{config.install_path} was not owned..." unless File.stat( @config.install_path ).owned?

        #
        @platform_config = {
          ext:                  "sh"
        }

        #
        @installers = make_packages_list

        #
        Dir.mkdir( @config.placeholder_path ) unless Dir.exists?( @config.placeholder_path )

        #
        @package_list_revision = check_package_list_revision

        #
        @running_tasks_num = 0

        @sema = Mutex.new
      end
      attr_reader :installers, :running_tasks_num, :package_list_revision


      # ==============================
      def platform_package_script_dir
        return File.join(@config.package_scripts_path, "linux")
      end

      def placeholder_path
        return @config.placeholder_path
      end

      def check_package_list_revision
        return `cd #{Shellwords.escape @config.package_scripts_path} && git log --pretty=format:"%H" -1 | cut -c 1-10`
      end

      def pull_package_list
        message = `cd #{Shellwords.escape @config.package_scripts_path} && git pull origin master`
        succeeded = $?.exitstatus == 0

        return succeeded, message

      rescue => e
        return false, e.to_s
      end

      #
      def find_target_indexes_by_name( title )
        indexes = title.chomp.split( ',' ).map{|s| Regexp.new(Regexp.quote(s)) }.inject( Array.new ) do |arr, sel|
          @installers.each_with_index do |name, i|
            arr << i if sel === name
          end
          arr.uniq
        end

        return indexes.length == 1 ? indexes[0] : indexes
      end


      #
      def build_and_install_by_name( title, do_reuse = true, &block )
        indexes = find_target_indexes_by_name( title )
        return build_and_install_by_index( indexes, do_reuse, &block )
      end


      #
      def build_and_install_by_index( index, do_reuse, &block )
        is_updated_something = false

        if index.instance_of?( Array )
          # if index was passed as Array, execute paralell
          threads = []
          index.each do |i|
            threads << Thread.new do
              is_updated_something |= build_and_install( @installers[i], do_reuse )
            end
          end

          threads.each{|t| t.join }

        else
          #
          is_updated_something |= build_and_install( @installers[index], do_reuse, &block )
        end

        return is_updated_something
      end


      #
      def save_packages(&block)
        puts "= globbing #{@config.placeholder_path} ..."

        pkg_profiles = []
        Dir.glob( "#{Shellwords.escape @config.placeholder_path}/*.deb" ) do |full_pkgname|
          pkgname = File.basename full_pkgname
          #system( "cp -v #{pkgname} #{@config.for_copy_nfs_mount_path}/.")
          mtime = File::Stat.new( full_pkgname ).mtime
          pkg_profiles << TorigoyaKit::Package::AvailableProfile.new( pkgname, mtime )

          puts "=> #{pkgname} / #{mtime}"
        end

        message, err = block.call(@config.placeholder_path, pkg_profiles)

        if err == nil && pkg_profiles.length > 0
          # delete temporary
          pkg_profiles.each do |pkg_profile|
            system "cd #{Shellwords.escape @config.placeholder_path} && rm -vf #{pkg_profile.package_name}"
          end
        end

        return message, err
      end


      #
      def delete_temporary_packages!
        puts "= globbing #{@config.placeholder_path} ..."

        Dir.glob( "#{Shellwords.escape @config.placeholder_path}/*.deb" ) do |pkgname|
          system( "rm -v #{pkgname}")
        end
      end



      ########################################
      ########################################
      private

      #
      def proc_factory_dir
        return File.dirname( File.expand_path( __FILE__ ) )
      end



      #
      def make_timestamp
        return Time.new.to_a.values_at( 5, 4, 3, 2, 1, 0 )
      end


      #
      def make_packages_list
        sd = platform_package_script_dir()
        glob_p = "#{Shellwords.escape sd}/**/*.#{@platform_config[:ext]}"
        packages_list = Dir::glob(glob_p)
                        .select {|f| (File.basename f)[0] != '_'}
                        .map {|f| f[sd.length+1..f.length]}

        return packages_list.sort!
      end


      #
      def build_and_install(script_name, do_reuse, &block)
        @sema.synchronize do
          @running_tasks_num = @running_tasks_num + 1
        end

        @config.logger.info "build_and_install #{script_name}"

        year, month, day, hour, min, sec = make_timestamp()

        #
        r_out_pipe, w_out_pipe = IO.pipe
        r_err_pipe, w_err_pipe = IO.pipe

        pid = nil
        Guard.sync do
          Dir.chdir( platform_package_script_dir() ) do
            # execute install script
            @config.logger.info "Execute! => #{script_name}"

            # parameters for the build script
            envs = {
              "PARAM_WORKSPACEPATH" => @config.workspace_path.to_s,
              "PARAM_TARGETSYSTEM" => @config.target_system.to_s,
              "PARAM_TARGETARCH" => @config.target_arch.to_s,
              "PARAM_INSTALLPATH" => @config.install_path.to_s,
              "PARAM_TIMESTAMP_YEAR" => year.to_s,
              "PARAM_TIMESTAMP_MONTH" => month.to_s,
              "PARAM_TIMESTAMP_DAY" => day.to_s,
              "PARAM_TIMESTAMP_HOUR" => hour.to_s,
              "PARAM_TIMESTAMP_MIN" => min.to_s,
              "PARAM_TIMESTAMP_SEC" => sec.to_s,
              "PARAM_PLACEHOLDER_PATH" => @config.placeholder_path.to_s,
              "PARAM_REUSE_BUILDDIR" => (do_reuse == true ? '1' : '0'),
              "PARAM_PACKAGE_PREFIX" => "torigoya-",
            }

            #
            options = {
              :out => w_out_pipe,
              :err => w_err_pipe
            }

            pid = Process.spawn(envs, "bash #{script_name}", options)
            w_out_pipe.close
            w_err_pipe.close

            @config.logger.info "Spawned [#{script_name}] :: #{pid}"
          end # chdir
        end # Guard.sync
        raise "unexpected... : pid is nil" if pid.nil?

        # read stdout
        out_th = Thread.new do
          while data = r_out_pipe.readline
            block.call(:out, data) if block
          end rescue puts "Out pipe finished"
        end
        # read stderr
        err_th = Thread.new do
          while data = r_err_pipe.readline
            block.call(:err, data) if block
          end rescue puts "Err pipe finished"
        end

        @config.logger.info "Wait for [#{script_name}] :: #{pid}"

        # WAIT for completion of build...
        finished_pid, status = Process.waitpid2( pid )

        #
        @config.logger.info "status => #{status}"
        raise "Script execution is failed." unless status.exitstatus == 0
        return true

      rescue => e
        @config.logger.warn "failed... : #{e} /\n#{$@.join("\n")}"
        return false

      ensure
        r_out_pipe.close unless r_out_pipe.nil?
        r_err_pipe.close unless r_err_pipe.nil?

        out_th.join unless out_th.nil?
        err_th.join unless err_th.nil?
      end

    end # class Builder


    class ProcProfileUpdater
      def initialize(config)
        @config = config
      end

      def remove_repo
        if File.exist?('/tmp/proc_profile')
          return system('rm -rf /tmp/proc_profile')
        end
      end

      def host_updated_zip
        pid = Process.fork do
          Dir.chdir('/tmp') do
            dir_name = 'torigoya_proc_profiles-master'

            # update repo
            if File.exist?(dir_name)
              Dir.chdir(dir_name) do
                r = system("git reset --hard origin/master")
                exit 1 unless r

                r = system("git pull origin master")
                exit 2 unless r
              end

            else
              r = system("git clone #{@config.profile_git_repo} #{dir_name}")
              exit 3 unless r
            end

            # generate files
            Dir.chdir(dir_name) do
              table_dir = File.join(@config.apt_repository_path, '/available_package_table')
              Bundler.with_clean_env do
                r = system("./generate.sh -l #{table_dir}")
                exit 4 unless r
              end
            end

            # packing
            r = system("zip -r #{dir_name}.zip #{File.join(dir_name, 'lang.*')} #{File.join(dir_name, 'languages.yml')}")
            exit 5 unless r

            # host
            f_name = File.join(@config.apt_repository_path, "/#{dir_name}.zip")
            r = system("mv #{dir_name}.zip #{f_name}")
            exit 6 unless r
          end
        end # Process.fork
        _, status = Process.waitpid2 pid

        case status.exitstatus
        when 0
          return true, "succeeded"
        when 1
          return false, "Failed to reset proc profile"
        when 2
          return false, "Failed to update proc profile"
        when 3
          return false, "Failed to clone proc profile"
        when 4
          return false, "Failed to generate proc profile"
        when 5
          return false, "Failed to pack proc profile"
        when 6
          return false, "Failed to host proc profile"
        else
          return false, "Unexpected error"
        end
      end

    end # class ProcProfileUpdater

  end # module BuildServer
end # module Torigoya
