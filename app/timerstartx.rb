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
    @portals_status = redis.hgetall('portals')
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
    slim :view
  end

  get '/runs' do
    redis = Redis.new
    if params[:run]
      @run = redis.lrange(params[:run], 0, -1).reverse
      competitors_in_run = redis.lrange(params[:run], 0, -1).map { |a| a.split(':')[0] }
      @competitors = @all_competitors.reject { |k, _| competitors_in_run.include? k }
    end
    redis.close
    slim :runs
  end

  post '/modify_run' do
    redis = Redis.new
    redis.lrem(params[:run].to_s, -1, params[:competitor].to_s) if params[:action] == 'remove_competitor'
    redis.lpush(params[:run].to_s, params[:competitor].to_s) if params[:action] == 'add_competitor'
    redis.close
    redirect "/runs?run=#{params[:run]}"
  end

  get '/status_run' do
    redis = Redis.new
    all_status = redis.hgetall('runs')
    already_started = all_status.select { |_, a| a == 'started' }
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
    slim :competitors
  end

  get '/competitor_runs' do
    redirect '/competitors' if params[:competitor].nil?
    redis = Redis.new
    @competitor = JSON.parse(redis.hget('competitors', params[:competitor]))
    redis.close
    slim :competitor_runs
  end

  post '/competitor_modify_run' do
    competitor = params['name']
    competitor_run = {}
    competitor_run['ts_start'] = params['ts_start'] if params['ts_start']
    if params['ts_stop']
      competitor_run['ts_stop'] = params['ts_stop'] == 'crashed' ? params['ts_stop'] : params['ts_stop'].to_i
    end
    if params['ts_time']
      competitor_run['ts_time'] = params['ts_time'] == 'crashed' ? params['ts_time'] : params['ts_time'].to_i
    end
    redis = Redis.new
    competitor_infos = JSON.parse(redis.hget('competitors', competitor))
    competitor_infos[params['run_name']] = competitor_run
    redis.hmset('competitors', competitor, competitor_infos.to_json)
    redis.close
    redirect "/competitor_runs?competitor=#{competitor}"
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

  post '/competitor_start' do
    return if @portals_status['start'] == 'closed' && params['mode'] == 'auto'

    redis = Redis.new
    run_len = redis.lrange(@run_in_progress, 0, -1).size
    competitor_inprogress = redis.lrange('run:inprogress', 0, -1)
    competitor_inprogress_len = competitor_inprogress.size
    if params[:ts] && run_len.positive? && competitor_inprogress_len < 2
      competitor = redis.rpop(@run_in_progress)
      competitor_infos = JSON.parse(redis.hget('competitors', competitor))
      competitor_infos[@run_in_progress] = { ts_start: params[:ts] }
      redis.hmset('competitors', competitor, competitor_infos.to_json)
      redis.rpush('run:inprogress', competitor)
    end
    redis.hset('portals', 'start', 'closed') if params['mode'] == 'auto'
    redis.close
    connections.each do |out|
      out << "data: #{params}\n\n"
      out.close
    end
    ''
  end

  post '/competitor_stop' do
    return if @portals_status['finish'] == 'closed' && params['mode'] == 'auto'

    redis = Redis.new
    competitor_inprogress = redis.lrange('run:inprogress', 0, -1)
    competitor_inprogress_len = competitor_inprogress.size
    if params[:ts] && competitor_inprogress_len.positive?
      competitor = redis.lpop('run:inprogress')
      competitor_infos = JSON.parse(redis.hget('competitors', competitor))
      competitor_infos[@run_in_progress].merge!({ ts_stop: params[:ts] })
      competitor_infos[@run_in_progress].merge!(
        { ts_time: (params[:ts].to_i - competitor_infos[@run_in_progress]['ts_start'].to_i) }
      )
      redis.hmset('competitors', competitor, competitor_infos.to_json)
    end
    redis.hset('portals', 'finish', 'closed') if params['mode'] == 'auto'
    redis.close
    connections.each do |out|
      out << "data: #{params}\n\n"
      out.close
    end
    ''
  end

  post '/competitor_crash' do
    redis = Redis.new
    competitor_inprogress = redis.lrange('run:inprogress', 0, -1)
    competitor_inprogress_len = competitor_inprogress.size
    if params[:ts] && competitor_inprogress_len.positive?
      case competitor_inprogress.index(params[:ts])
      when 0
        competitor = redis.lpop('run:inprogress')
      when 1
        competitor = redis.rpop('run:inprogress')
      end

      competitor_infos = JSON.parse(redis.hget('competitors', competitor))
      competitor_infos[@run_in_progress].merge!({ ts_stop: 'crashed' })
      competitor_infos[@run_in_progress].merge!({ ts_time: 'crashed' })
      redis.hmset('competitors', competitor, competitor_infos.to_json)
    end
    redis.close
    connections.each do |out|
      out << "data: #{params}\n\n"
      out.close
    end
    ''
  end

  get '/push' do
    connections.each do |out|
      out << "data: #{params}\n\n"
      out.close
    end
    ''
  end

  post '/portal_update_status' do
    redis = Redis.new
    redis.hset('portals', params[:portal_name], params[:portal_status])
    redis.close
    redirect '/'
  end

end
