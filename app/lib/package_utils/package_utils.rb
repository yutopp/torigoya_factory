require 'yaml'
require 'time'

module Torigoya
  module Package

    #
    class Util
      def self.package_name_regex
        /^torigoya-([a-zA-Z0-9+]+)(-|_)(([a-zA-Z0-9]+\.?)+)(-1)?_.*\.deb$/
      end

      # return
      # [name, raw_version]
      def self.parse_package_name( package_name )
        reg = package_name.scan( self.package_name_regex )
        if reg[0].nil?
          raise "#{package_name} is invalid..."
        end

        return reg[0].values_at( 0, 2 )
      end
    end


    #
    class Tag
      def initialize( package_name )
        #
        @package_name = package_name
        @name, version = Util.parse_package_name( package_name )
        @version = version.gsub( /^(999.)(.*)/, "trunk" ).gsub( /^(888.)(.*)/, "dev" ).gsub( /^(777.)(.*)/, "stable" )
        @display_version = version.gsub( /^(999.)/, "HEAD-" ).gsub( /^(888.)/, "DEV-" ).gsub( /^(777.)/, "STABLE-" )
      end
      attr_reader :package_name, :name, :version, :display_version
    end


    #
    class AvailableProfile
      def initialize( package_name, built_date )
        @package_name = package_name
        @built_date = built_date
      end
      attr_reader :package_name, :built_date

      def to_yaml
        return YAML.dump( {
                            'package_name' => @package_name,
                            'built_date' => @built_date
                          } )
      end

      def self.from_yaml( yaml )
        obj = YAML.load( yaml )
        return self.new( obj['package_name'], obj['built_date'].instance_of?( String ) ? Time.parse( obj['built_date'] ) : obj['built_date'] )
      end

      def self.load_from_yaml( yaml_filename )
        obj = YAML.load_file( yaml_filename )
        return self.new( obj['package_name'], obj['built_date'].instance_of?( String ) ? Time.parse( obj['built_date'] ) : obj['built_date'] )
      end
    end


    #
    class ProfileHolder
      def initialize( holder_path )
        @holder_path = holder_path
      end

      def update_package( package_name, built_date )
        profile_name = self.class.make_profile_name( package_name )
        profile_path = "#{@holder_path}/#{profile_name}"
        a_profile = AvailableProfile.new( package_name, built_date )

        if File.exists?( profile_path )
          # compare date
          current_profile = AvailableProfile.load_from_yaml( profile_path )
          if a_profile.built_date > current_profile.built_date
            # update information
            self.class.save_profile( profile_path, a_profile )
          end
        else
          # save immediately
          self.class.save_profile( profile_path, a_profile )
        end

        return profile_path
      end

      def delete_package( package_name )
        profile_name = self.class.make_profile_name( package_name )
        profile_path = "#{@holder_path}/#{profile_name}"

        if File.exists?( profile_path )
          system( "rm -vf #{profile_path}" )
        end

        return profile_path
      end

      def list_profiles()
        profs = []
        Dir.chdir( @holder_path ) do
          Dir.glob( '*.yml' ) do |filename|
            profs << AvailableProfile.load_from_yaml( filename )
          end
        end
        return profs
      end

      def list_tag_and_date()
        profs = list_profiles()
        return profs.map{|e| { tags: Tag.new( e.package_name ), built_date: e.built_date } }
      end

      def self.save_profile( path, available_profile )
        File.open( path, "w" ) do |f|
          f.write( available_profile.to_yaml )
        end
      end

      def self.make_profile_name( package_name )
        tag = Tag.new( package_name )
        return "#{tag.name}-#{tag.version}.yml"
      end
    end

  end # module Packages
end # module Torigoya
