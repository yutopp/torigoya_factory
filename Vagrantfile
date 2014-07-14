# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "ubuntu/trusty64"

  # port 12321 is used by torigoya cage server
  config.vm.network "forwarded_port", guest: 80, host: 50080, auto_correct: true
  config.vm.network "forwarded_port", guest: 8080, host: 58080, auto_correct: true

  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", 1024]
    # http://stackoverflow.com/questions/22901859/cannot-make-outbound-http-requests-from-vagrant-vm
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

  # https://coderwall.com/p/qtbi5a
  config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"

  #
  config.vm.provision :shell, :inline => ["apt-get -y update && apt-get -y upgrade",
                                          "apt-get install -y nginx libsqlite3-dev",
                                          "apt-get install -y reprepro",
                                          "apt-get install -y build-essential",
                                          "apt-get install -y ruby ruby-dev",
                                          "apt-get install -y git wget unzip python",
                                          "apt-get install -y cmake subversion clang",
                                          "gem install thin bundler fpm --no-rdoc --no-ri",
                                          "if [ ! -e /usr/local/torigoya ]; then mkdir /usr/local/torigoya; fi",
                                         ].join("; ")
end
