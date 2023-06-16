# MIT License
# Copyright (c) 2022 Gauthier FRANCOIS
# frozen_string_literal: true

require 'active_support/all'
require 'redis'
require 'json'
require 'sinatra'
require 'sinatra/base'
require 'sinatra/config_file'
require 'sinatra/namespace'
require 'slim'
require 'puma'

require_relative 'http_api'
require_relative 'admin_competitor'
require_relative 'admin_run'

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
  include AdminRun

  set :root, "#{File.dirname(__FILE__)}/.."
  set :slim, layout: :_layout
  set :public_folder, 'public'

  config_file_name = "#{File.dirname(__FILE__)}/../config/#{environment}.yml"
  raise "config file #{config_file_name} missing" unless File.exist? config_file_name

  config_file config_file_name

  before do
    redis = Redis.new
    @runs = redis.hgetall('runs')
    competitors_inprogress = redis.lrange('run:inprogress', 0, -1)
    @penalty = settings.public_methods.include?(:penalty) ? settings.penalty : { jump: 0, tunnel: 0 }
    @race_distance = settings.public_methods.include?(:race_distance) ? settings.race_distance : 0
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

  helpers do
    def protected!
      session[:admin_menu] = true if authorized?
      return if authorized?

      session[:admin_menu] = false if authorized?
      headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'

      halt 401, "Not authorized\n"
    end

    def authorized?
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
      credentials = [settings.htaccess['logging'], settings.htaccess['password']]
      @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == credentials
    end

    def authenticated?
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? and @auth.basic?
    end
  end

  get '/' do
    slim :view
  end

  get '/runs_rank' do
    slim :view
  end

  get '/rank_by_avg' do
    @competitors_avg = {}
    @all_competitors.each do |nb, infos|
      avg_time = infos.map { |_, t| t['ts_time'] }.reject!(&:nil?)
      avg_time -= ['crashed']
      @competitors_avg[nb] = avg_time.sum(0.0) / avg_time.size unless avg_time.empty?
    end
    @competitors_avg = @competitors_avg.sort_by { |_, v| v }.to_h
    slim :rank_by_avg
  end

  get '/rank_by_min' do
    @competitors_min = {}
    @all_competitors.each do |nb, infos|
      min_time = infos.map { |_, t| t['ts_time'] }.reject!(&:nil?)
      min_time -= ['crashed']
      @competitors_min[nb] = min_time.min unless min_time.empty?
    end
    @competitors_min = @competitors_min.sort_by { |_, v| v}.to_h
    slim :rank_by_min
  end


  get '/disconnect' do
    redirect '/'
  end

  # rubocop:disable Metrics/BlockLength
  namespace '/admin' do
    before do
      protected!
    end
    get '/runs' do
      @run, @competitors = AdminRun.runs(params, @all_competitors)
      slim :runs
    end

    post '/modify_run' do
      AdminRun.modify(params)
      redirect "/admin/runs?run=#{params[:run]}"
    end

    get '/status_run' do
      AdminRun.status(params)
      redirect "/admin/runs?run=#{params[:run]}"
    end

    post '/create_run' do
      AdminRun.create(params)
      redirect '/admin/runs'
    end

    post '/delete_run' do
      AdminRun.delete(params)
      redirect '/admin/runs'
    end

    get '/competitors' do
      slim :competitors
    end

    get '/competitor_runs' do
      redirect '/admin/competitors' if params[:competitor].nil?
      @competitor = AdminCompetitor.runs(params)
      slim :competitor_runs
    end

    post '/competitor_modify_run' do
      AdminCompetitor.modify_run(params)
      redirect "/admin/competitor_runs?competitor=#{params[:name]}"
    end

    post '/delete_competitor' do
      AdminCompetitor.delete(params)
      redirect '/admin/competitors'
    end

    post '/update_competitor' do
      AdminCompetitor.update(params)
      redirect '/admin/competitors'
    end

    post '/create_competitor' do
      session[:message] = AdminCompetitor.create(params, @all_competitors)
      redirect '/admin/competitors'
    end
  end
  # rubocop:enable Metrics/BlockLength

end
