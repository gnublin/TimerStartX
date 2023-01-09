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

  _, milliseconds = milliseconds.divmod(1000 * 60 * 60)
  minutes, milliseconds = milliseconds.divmod(1000 * 60)
  seconds, milliseconds = milliseconds.divmod(1000)
  {
    minutes:,
    seconds:,
    milliseconds: milliseconds.round
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
    redis = Redis.new
    @runs = redis.hgetall('runs')
    competitors_inprogress = redis.lrange('run:inprogress', 0, -1)
    @run_in_progress = @runs.select { |_, status| status == 'started' }.keys.first
    @runs_in = {}
    @all_competitors = hm_getall(redis, 'competitors')
    unless @run_in_progress.nil?
      competitors_inprogress.each_with_index do |competitor, idx|
        time_competitor = JSON.parse(redis.hmget('competitors', competitor).first)[@run_in_progress]['ts_start']
        time_competitor = Time.at(time_competitor.to_i).to_f / 1000
        time_now = Time.now.to_f.truncate(3)
        @runs_in[idx] = {
          ts: get_duration_hrs_and_mins((time_now - time_competitor) * 1000),
          name: competitor
        }
      end
    end
    redis.close
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
      competitors_in_run = redis.lrange(params[:run], 0, -1).map { |a| a.split(':')[0] }
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

  get '/status_run' do
    redis = Redis.new
    all_status = redis.hgetall('runs')
    already_started = all_status.select{|_, a| a == 'started'}
    redis.hset('runs', params[:run], params[:status]) if params[:status] != 'started' || already_started.empty?
    redis.close
    redirect "/runs?run=#{params[:run]}"
  end

  post '/create_run' do
    redis = Redis.new
    redis.hset('runs', "run-#{params[:run_number]}", 'opened')
    redis.close
    redirect '/runs'
  end

  post '/delete_run' do
    redis = Redis.new
    redis.hdel('runs', params[:run_number])
    redis.del(params[:run_number])
    redis.hgetall('competitors').each do |competitor, infos|
      competitor_infos = JSON.parse(infos)
      competitor_infos = competitor_infos.except(params[:run_number])
      redis.hmset('competitors', competitor, competitor_infos.to_json)
    end
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
    redis = Redis.new
    started_run = redis.hgetall('runs').select { |_, status| status == 'started' }
    if started_run.empty?
      puts 'emtpy'
    else
      run_id = started_run.keys.first
    end
    run_len = redis.lrange(run_id, 0, -1).size
    competitor_inprogress = redis.lrange('run:inprogress', 0, -1)
    competitor_inprogress_len = competitor_inprogress.size
    if params[:ts_start] && run_len.positive? && competitor_inprogress_len < 2
      competitor = redis.rpop(run_id)
      competitor_infos = JSON.parse(redis.hget('competitors', competitor))
      competitor_infos[run_id] = { ts_start: params[:ts_start] }
      redis.hmset('competitors', competitor, competitor_infos.to_json)
      redis.rpush('run:inprogress', competitor)
    end
    if params[:ts_stop] && competitor_inprogress_len.positive?
      competitor = redis.lpop('run:inprogress')
      competitor_infos = JSON.parse(redis.hget('competitors', competitor))
      competitor_infos[run_id].merge!({ ts_stop: params[:ts_stop] })
      competitor_infos[run_id].merge!({ ts_time: (params[:ts_stop].to_i - competitor_infos[run_id]['ts_start'].to_i) })
      redis.hmset('competitors', competitor, competitor_infos.to_json)
    end
    if params[:ts_crashed] && competitor_inprogress_len.positive?
      competitor =
        if competitor_inprogress.index(params[:ts_crashed]) == 0
          redis.lpop('run:inprogress')
        elsif competitor_inprogress.index(params[:ts_crashed]) == 1
          redis.rpop('run:inprogress')
        end
      p competitor
      p redis.hget('competitors', competitor)
      competitor_infos = JSON.parse(redis.hget('competitors', competitor))
      competitor_infos[run_id].merge!({ ts_stop: 'crashed' })
      competitor_infos[run_id].merge!({ ts_time: 'crashed' })
      redis.hmset('competitors', competitor, competitor_infos.to_json)
    end
    connections.each do |out|
      out << "data: #{params}\n\n"
      out.close
    end
    ''
  end
end
