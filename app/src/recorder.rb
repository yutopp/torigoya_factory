# encoding: utf-8
require_relative 'apt_repository'


module Torigoya
  module Package
    class Recoder
      def self.save_available_packages_table(repository_path, package_profiles)
        package_table_path = "#{repository_path}/available_package_table"

        puts ""
        puts "== saving available package table [#{package_table_path}]"
        unless File.exists?(package_table_path)
          system "mkdir #{package_table_path}"
        end

        if package_profiles.length > 0
          h = Package::ProfileHolder.new(package_table_path)
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
      def self.add_to_apt_repository(repository_path, placeholder_path, package_profiles)
        # using http://mirrorer.alioth.debian.org/reprepro.1.html
        # codename='saucy'
        codename = 'trusty' # for 14.04 LTS

        r = Torgoya::AptRepository::Reprepro.new(repository_path, codename)
        packages = package_profiles.map {|ppf| "#{placeholder_path}/#{ppf.package_name}"}

        packages.each do |package|
          command = r.make_add_command("#{package} 2>&1")   # redirect stderr to stdout
          puts "add to apt repository...", "=> #{command}"
          result = `#{command}`
          status = $?
          unless status != 0
            return "failed to add repository #{result}"
          end
          puts "=> #{result ? "SUCCEEDED" : "FAILED"}"
        end

        return nil
      end

    end # class Recoder
  end # module Package
end # module Torigoya
