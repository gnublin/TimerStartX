# MIT License
# Copyright (c) 2022 Gauthier FRANCOIS
# frozen_string_literal: true

require 'active_support/all'
require 'redis'
require 'json'
require 'sinatra'
require 'sinatra/base'
require 'slim'
require 'puma'

def get_duration_hrs_and_mins(milliseconds)
  return '' unless milliseconds

  hours, milliseconds   = milliseconds.divmod(1000 * 60 * 60)
  minutes, milliseconds = milliseconds.divmod(1000 * 60)
  seconds, milliseconds = milliseconds.divmod(1000)
  {
    hours:,
    minutes:,
    seconds:,
    milliseconds:
  }
end

def hm_getall(redis, rkey)
  res = {}
  all_result_key = redis.hgetall(rkey).keys
  all_result_key.each do |rk|
    res [rk] = JSON.parse(redis.hget(rkey, rk))
  end
  res
end

# TimerStartX application
class TimerStartX < Sinatra::Application
  set :root, "#{File.dirname(__FILE__)}/.."
  set :slim, layout: :_layout
  set :public_folder, 'public'
  connections = []
  before do
    @log_msg = session[:message] || ''
    session.delete :message
  end

  get '/' do
    k = ((Time.now - 10.minutes.ago) * 1000).to_i
    @timestamp = get_duration_hrs_and_mins(k)
    slim :view
  end

  get '/start' do
    redis = Redis.new
    ts = params[:ts]
    redis.set('run1:test1', 'hello world')
  end

  get '/runs' do
    redis = Redis.new
    @runs = redis.hgetall('runs')
    if params[:run]
      @run = redis.lrange(params[:run], 0, -1).reverse
      competitors_in_run = redis.lrange(params[:run], 0, -1).map{ |a| a.split(':')[0] }
      @all_competitors = hm_getall(redis, 'competitors')
      @competitors = @all_competitors.reject { |k, _| competitors_in_run.include? k }
    end
    redis.close
    slim :runs
  end

  get '/add_to_run' do
    redis = Redis.new
    @run = redis.lpush(params[:run].to_s, params[:competitor].to_s)
    redis.close
    redirect "/runs?run=#{params[:run]}"
  end

  get '/rem_to_run' do
    redis = Redis.new
    @run = redis.lrem(params[:run].to_s, -1, params[:competitor].to_s)
    redis.close
    redirect "/runs?run=#{params[:run]}"
  end

  get '/close_run' do
    redis = Redis.new
    redis.hset('runs', params[:run], params[:status])
    redis.close
    redirect "/runs?run=#{params[:run]}"
  end

  post '/create_run' do
    redis = Redis.new
    redis.hset('runs', "run-#{params[:run_number]}", 'open')
    redis.close
    redirect '/runs'
  end

  post '/delete_run' do
    redis = Redis.new
    redis.hdel('runs', "#{params[:run_number]}")
    redis.del(params[:run_number])
    redis.close
    redirect '/runs'
  end

  get '/competitors' do
    redis = Redis.new
    @competitors = redis.hgetall('competitors')
    redis.close
    slim :competitors
  end

  post '/delete_competitor' do
    redis = Redis.new
    redis.hdel('competitors', params[:number].to_s)
    redis.close
    redirect '/competitors'
  end

  post '/update_competitor' do
    redis = Redis.new
    competitor_dump = JSON.parse(redis.hmget('competitors', params[:old_number]).first)
    competitor_dump['name'] = params[:name]
    redis.hdel('competitors', params[:old_number].to_s)
    redis.hset('competitors', params[:number], competitor_dump.to_json)
    redis.close
    redirect '/competitors'
  end

  post '/create_competitor' do
    if !params[:number].empty? && !params[:name].empty?
      redis = Redis.new
      @competitors = redis.hgetall('competitors')
      if @competitors.key?(params[:number])
        session[:message] = 'already exist'
      else
        redis.hmset('competitors', params[:number], { name: params[:name] }.to_json)
        redis.close
      end
    else
      session[:message] = 'not empty'
    end
    redirect '/competitors'
  end

  get '/events', provides: 'text/event-stream' do
    stream(:keep_open) do |out|
      connections << out
      connections.reject!(&:closed?)
    end
  end

  get '/push' do
    connections.each do |out|
      out << "data: #{params[:msg]}\n\n"
      out.close
    end
    @msg = params[:msg]
    slim :push
  end
end
