# encoding: utf-8
require 'logger'
require 'yaml'
require 'singleton'


module Torigoya
  module BuildServer
    ########################################
    #
    class MyLogger
      include Singleton

      def initialize
        @logger = Logger.new( STDOUT )
        @logger.level = Logger::DEBUG  # ERROR
      end
      attr_accessor :logger
    end


    ########################################
    #
    class Config
      ########################################
      #
      def self.root_path
        # fixed...
        return "#{File.dirname( File.expand_path( __FILE__ ) )}/.."
      end

      def root_path
        return self.class.root_path
      end

      ########################################
      #
      def logger
        return MyLogger.instance.logger
      end


      ########################################
      #
      def initialize
        rp = self.class.root_path()

        config_path = File.expand_path("config.yml", rp)
        @config = YAML.load_file(config_path)

        puts "Loading: #{config_path}"

        #
        @install_path           = @config['install_path'] % { :_home => rp }
        @workspace_path         = @config['workspace_path'] % { :_home => rp }
        @package_scripts_path   = @config['package_scripts_path'] % { :_home => rp }
        @placeholder_path       = @config['placeholder_path'] % { :_home => rp }
        @apt_repository_path    = @config['apt_repository_path'] % { :_home => rp }
        @target_system          = @config['target_system']
        @target_arch            = @config['target_arch']
        @profile_git_repo       = @config['profile_git_repo']

        @admin_pass_sha512      = @config['admin_pass_sha512']
        if @admin_pass_sha512.nil?
          puts "Run with NO ADMIN mode"
        end
        @session_secret         = @config['session_secret']

        @notification           = @config['use_notification']
        @twitter_client         = nil
        # TODO: fixme
        if @notification == "twitter"
          require 'twitter'

          @twitter_client = Twitter::REST::Client.new do |config|
            config.consumer_key        = @config['twitter_consumer_key']
            config.consumer_secret     = @config['twitter_consumer_secret']
            config.access_token        = @config['twitter_access_token']
            config.access_token_secret = @config['twitter_access_token_secret']
          end
        end
      end
      attr_reader :install_path, :workspace_path, :placeholder_path, :package_scripts_path
      attr_reader :apt_repository_path, :target_system, :target_arch, :profile_git_repo
      attr_reader :admin_pass_sha512, :session_secret
      attr_reader :notification, :twitter_client
    end

  end # module BuildServer
end # module Torigoya
