# -*- coding: utf-8 -*-
require 'sinatra'

#
set :environment, :production
set :server, :thin
set :bind, '0.0.0.0'    # IMPORTANT
set :port, 8080
set :logging, true
set :dump_errors, true

# ==============================
# ==============================

get '/' do
  'いええええ'
end
