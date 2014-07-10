require 'test/unit'
require 'tmpdir'
require_relative 'package_utils'


class PackageTest < Test::Unit::TestCase
  def setup
  end

  def teardown
  end

  #
  def test_util
    assert_equal( [ 'llvm', '3.4' ], Torigoya::Package::Util.parse_package_name( "torigoya-llvm-3.4_3.4_amd64.deb" ) )
    assert_equal( ['llvm', '999.2014.4.4.205650'], Torigoya::Package::Util.parse_package_name( "torigoya-llvm_999.2014.4.4.205650_amd64.deb" ) )
    assert_raise( RuntimeError ) do
      Torigoya::Package::Util.parse_package_name( "torigababa64.deb" )
    end
  end

  #
  def test_tag_1
    tag = Torigoya::Package::Tag.new( "torigoya-llvm-3.4_3.4_amd64.deb" )
    assert_equal( "torigoya-llvm-3.4_3.4_amd64.deb", tag.package_name )
    assert_equal( "llvm", tag.name )
    assert_equal( "3.4", tag.version )
    assert_equal( "3.4" , tag.display_version )
  end

  #
  def test_tag_j1
    tag = Torigoya::Package::Tag.new( "torigoya-java9_999.2014.4.8.e912167e7ecf_amd64.deb" )
    assert_equal( "torigoya-java9_999.2014.4.8.e912167e7ecf_amd64.deb", tag.package_name )
    assert_equal( "java9", tag.name )
    assert_equal( "head", tag.version )
    assert_equal( "HEAD-2014.4.8.e912167e7ecf" , tag.display_version )
  end

  #
  def test_tag_21
    tag = Torigoya::Package::Tag.new( "torigoya-llvm_999.2014.4.4.205650_amd64.deb" )
    assert_equal( "torigoya-llvm_999.2014.4.4.205650_amd64.deb", tag.package_name )
    assert_equal( "llvm", tag.name )
    assert_equal( "head", tag.version )
    assert_equal( "HEAD-2014.4.4.205650", tag.display_version )
  end

  def test_tag_22
    tag = Torigoya::Package::Tag.new( "torigoya-llvm_888.2014.4.4.205650_amd64.deb" )
    assert_equal( "torigoya-llvm_888.2014.4.4.205650_amd64.deb", tag.package_name )
    assert_equal( "llvm", tag.name )
    assert_equal( "dev", tag.version )
    assert_equal( "DEV-2014.4.4.205650", tag.display_version )
  end

  def test_tag_23
    tag = Torigoya::Package::Tag.new( "torigoya-llvm_777.2014.4.4.205650_amd64.deb" )
    assert_equal( "torigoya-llvm_777.2014.4.4.205650_amd64.deb" , tag.package_name )
    assert_equal( "llvm", tag.name )
    assert_equal( "stable", tag.version )
    assert_equal( "STABLE-2014.4.4.205650", tag.display_version )
  end

  def test_tag_2
    assert_raise( RuntimeError ) do
      tag = Torigoya::Package::Tag.new( "torigababa64.deb" )
    end
  end

  #
  def test_prof_update_exist
    Dir.mktmpdir do |dir|
      h = Torigoya::Package::ProfileHolder.new( dir )

      p_name = "torigoya-llvm_999.2014.4.4.205650_amd64.deb"
      new_p_time = Time.now()

      begin
        f_path = h.update_package( p_name, new_p_time )

        assert_equal( "#{dir}/llvm-head.yml", f_path )
        assert_equal( true, File.exists?( f_path ) )
      end
    end # Dir
  end

  #
  def test_prof_update
    Dir.mktmpdir do |dir|
      h = Torigoya::Package::ProfileHolder.new( dir )

      p_name = "torigoya-llvm_999.2014.4.4.205650_amd64.deb"
      new_p_time = Time.now()
      updated_p_time = new_p_time + 100

      begin
        f_path = h.update_package( p_name, new_p_time )

        assert_equal( true, File.exists?( f_path ) )
        f_y = Torigoya::Package::AvailableProfile.load_from_yaml( f_path )
        assert_equal( p_name, f_y.package_name )
        assert_equal( new_p_time, f_y.built_date )
      end

      begin
        # Latest File
        f_path = h.update_package( p_name, updated_p_time )

        assert_equal( true, File.exists?( f_path ) )
        f_y = Torigoya::Package::AvailableProfile.load_from_yaml( f_path )
        assert_equal( p_name, f_y.package_name )
        assert_equal( updated_p_time, f_y.built_date )
      end

      begin
        f_path = h.update_package( p_name, new_p_time )

        assert_equal( true, File.exists?( f_path ) )
        f_y = Torigoya::Package::AvailableProfile.load_from_yaml( f_path )
        assert_equal( p_name, f_y.package_name )
        assert_equal( updated_p_time, f_y.built_date )
      end
    end # Dir
  end

  #
  def test_prof_delete
    Dir.mktmpdir do |dir|
      h = Torigoya::Package::ProfileHolder.new( dir )

      p_name = "torigoya-llvm_999.2014.4.4.205650_amd64.deb"
      new_p_time = Time.now()

      begin
        f_path = h.update_package( p_name, new_p_time )

        assert_equal( true, File.exists?( f_path ) )
      end

      begin
        f_path = h.delete_package( p_name )

        assert_equal( false, File.exists?( f_path ) )
      end
    end # Dir
  end

  #
  def test_prof_list
    Dir.mktmpdir do |dir|
      h = Torigoya::Package::ProfileHolder.new( dir )

      build_date = Time.now
      pkgs = [ { name: "torigoya-llvm_999.2014.4.4.205650_amd64.deb", date: build_date },
               { name: "torigoya-llvm-3.4_3.4_amd64.deb", date: build_date }
             ]

      begin
        pkgs.each do |e|
          h.update_package( e[:name], e[:date] )
        end
      end

      begin
        profs = h.list_profiles

        assert_equal( 2, profs.length )
        #assert_equal( pkgs[0][:name], profs[0].package_name )
        assert_equal( pkgs[0][:date], profs[0].built_date )
        #assert_equal( pkgs[1][:name], profs[1].package_name )
        assert_equal( pkgs[1][:date], profs[1].built_date )
      end
    end # Dir
  end
end
