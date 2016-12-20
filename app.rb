require 'sinatra'

use Rack::Session::Pool

get '/set' do
  obj = { param: 'value' }
  session[:key] = obj
  'set!'
end

get '/get' do
  session[:key][:param]
end