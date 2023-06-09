# MIT License
# Copyright (c) 2022 Gauthier FRANCOIS
# frozen_string_literal: true

# Run controller
module AdminCompetitor
  def self.runs(params)
    redis = Redis.new
    competitor = JSON.parse(redis.hget('competitors', params[:competitor]))
    redis.close
    competitor
  end

  def self.modify_run(params)
    competitor_run = {}
    competitor_run['ts_start'] = params['ts_start'] if params['ts_start']
    if params['ts_stop']
      competitor_run['ts_stop'] = params['ts_stop'] == 'crashed' ? params['ts_stop'] : params['ts_stop'].to_i
    end
    if params['ts_time']
      competitor_run['ts_time'] = params['ts_time'] == 'crashed' ? params['ts_time'] : params['ts_time'].to_i
    end
    competitor_run['jump'] = params['jump'] if params['jump']
    competitor_run['tune'] = params['tune'] if params['tune']

    redis = Redis.new
    competitor_infos = JSON.parse(redis.hget('competitors', params['name']))
    competitor_infos[params['run_name']] = competitor_run
    redis.hmset('competitors', params['name'], competitor_infos.to_json)
    redis.close
  end

  def self.delete(params)
    redis = Redis.new
    redis.hdel('competitors', params[:number].to_s)
    redis.close
  end

  def self.update(params)
    redis = Redis.new
    competitor_dump = JSON.parse(redis.hmget('competitors', params[:old_number]).first)
    competitor_dump['name'] = params[:name]
    redis.hdel('competitors', params[:old_number].to_s)
    redis.hset('competitors', params[:number], competitor_dump.to_json)
    redis.close
  end

  def self.create(params, all_competitors)
    if !params[:number].empty? && !params[:name].empty?
      if all_competitors.key?(params[:number])
        'already exist'
      else
        redis = Redis.new
        redis.hmset('competitors', params[:number], { name: params[:name] }.to_json)
        redis.close
        'ok'
      end
    else
      'not empty'
    end
  end
end
