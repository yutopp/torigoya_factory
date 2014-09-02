# Packages factory for torigoya

This package provides "frontend page for packaging" and "apt repository" for Torigoya.

At first, you **must** rename `config.in_docker.yml.template` to `config.in_docker.yml`, and fill incomplete sections.

Next, to set *password*, execute `echo -n "[change this to your password]" | sha512sum` and set the result to `admin_pass_sha512` section in `config.in_docker.yml`.

Finally, execute `./docker.run.sh` to host a factory!

By default, `http://localhost:80/` is an apt repository, and `http://localhost:8080/` is a frontend page.

## Debugging
(host)
```
vagrant up
vagrant ssh
```
(in vm)
```
cd /vagrant/app
sudo bundle exec ruby web-frontend.rb
```

## License
Boost License Version 1.0
