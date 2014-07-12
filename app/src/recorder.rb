# encoding: utf-8
require 'torigoya_kit'
require_relative 'apt_repository'


module Torigoya
  module Package
    class Recoder
      CodeName = 'trusty' # for 14.04 LTS

      def self.save_available_packages_table(repository_path, package_profiles)
        package_table_path = "#{repository_path}/available_package_table"

        puts ""
        puts "== saving available package table [#{package_table_path}]"
        unless File.exists?(package_table_path)
          system "mkdir #{package_table_path}"
        end

        if package_profiles.length > 0
          h = TorigoyaKit::Package::ProfileHolder.new(package_table_path)
          package_profiles.each do |package_profile|
            h.update_package(package_profile.package_name, package_profile.built_date)
          end

        else
          # there are no packages
          return false, nil
        end

        return true, nil

      rescue => e
        puts "... FAILED #{e} / #{$@}"
        return nil, e

      ensure
        puts "== finished available package table"
      end


      #
      def self.remove_package_table(repository_path, full_package_name)
        package_table_path = "#{repository_path}/available_package_table"
        h = TorigoyaKit::Package::ProfileHolder.new(package_table_path)

        h.delete_package(full_package_name)
        return nil

      rescue => e
        return "error in remove_package_table: #{e}"
      end


      #
      def self.add_to_apt_repository(repository_path, placeholder_path, package_profiles)
        # using http://mirrorer.alioth.debian.org/reprepro.1.html
        r = Torgoya::AptRepository::Reprepro.new(repository_path, CodeName)
        packages = package_profiles.map {|ppf| "#{placeholder_path}/#{ppf.package_name}"}

        message = ""
        packages.each do |package|
          command = "#{r.make_add_command(package)} 2>&1"       # redirect stderr to stdout
          puts "add to apt repository...", "=> #{command}"
          result = `#{command}`
          status = $?
          puts "reprepro => status(#{status}) result: #{result}"

          unless status.success?
            return "", "failed to add repository(#{status}): #{result}"
          end

          message << result
        end

        return message, nil
      end


      #
      def self.packages_list(repository_path)
        r = Torgoya::AptRepository::Reprepro.new(repository_path, CodeName)
        command = "#{r.make_ls_command()} 2>&1"     # redirect stderr to stdout
        result = `#{command}`
        status = $?
        puts "reprepro => status(#{status}) result: #{result}"

        unless status.success?
          return nil, "failed to ls repository(#{status}): #{result}"
        end

        return result.split("\n").map {|s| s.chomp}, nil
      end


      #
      def self.remove_from_apt_repository(repository_path, package_string)
        if m = /^(.*): (.*) (.*)$/.match(package_string)
          package_name = m[2]
          package_version = m[3]

          puts "Try to remove: #{package_name} / #{package_version}"

          r = Torgoya::AptRepository::Reprepro.new(repository_path, CodeName)
          command = "#{r.make_remove_command(package_name)} 2>&1"   # redirect stderr to stdout
          result = `#{command}`
          status = $?

          unless status.success?
            return "failed to delete repository(#{status}): #{result}"
          end

          # TODO: fix method of construcing full_package_name
          full_package_name = "#{package_name}_#{package_version}_amd64.deb"
          err = self.remove_package_table(repository_path, full_package_name)
          return err

        else
          return "error: #{package_name} was not matched to regexp"
        end
      end

    end # class Recoder
  end # module Package
end # module Torigoya
