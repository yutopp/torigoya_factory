#!/usr/bin/env ruby
# encoding: utf-8

module Torgoya
  module AptRepository

    class Reprepro
      def initialize( repository_path, codename )
        @repository_path = repository_path
        @codename = codename
      end

      def make_add_command( package_path )
        args = self.class.make_include_part( @codename, package_path )
        return "reprepro -b #{@repository_path} #{args}"
      end

      def make_ls_command()
        args = self.class.make_list_part( @codename )
        return "reprepro -b #{@repository_path} #{args}"
      end

      def make_remove_command( package_name )
        args = self.class.make_remove_part( @codename, package_name )
        return "reprepro -b #{@repository_path} #{args} deleteunreferenced"
      end

      ####################

      def self.make_include_part( codename, package_path )
        return "includedeb #{codename} #{package_path}"
      end

      def self.make_list_part( codename )
        return "list #{codename}"
      end

      def self.make_remove_part( codename, package_name )
        return "remove #{codename} #{package_name}"
      end
    end

  end
end
