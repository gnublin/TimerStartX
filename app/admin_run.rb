# MIT License
# Copyright (c) 2022 Gauthier FRANCOIS
# frozen_string_literal: true

# Run controller
module AdminRun
  def self.runs(params, all_competitors)
    redis = Redis.new
    return unless params[:run]

    run = redis.lrange(params[:run], 0, -1).reverse
    competitors_in_run = redis.lrange(params[:run], 0, -1).map { |a| a.split(':')[0] }
    redis.close
    competitors = all_competitors.reject { |k, _| competitors_in_run.include? k }
    [run, competitors]
  end

  def self.modify(params)
    redis = Redis.new
    redis.lrem(params[:run].to_s, -1, params[:competitor].to_s) if params[:action] == 'remove_competitor'
    redis.lpush(params[:run].to_s, params[:competitor].to_s) if params[:action] == 'add_competitor'
    redis.close
  end

  def self.status(params)
    redis = Redis.new
    all_status = redis.hgetall('runs')
    already_started = all_status.select { |_, a| a == 'started' }
    redis.hset('runs', params[:run], params[:status]) if params[:status] != 'started' || already_started.empty?
    redis.close
  end

  def self.create(params)
    redis = Redis.new
    redis.hset('runs', "run-#{params[:run_number]}", 'opened')
    redis.close
  end

  def self.delete(params)
    redis = Redis.new
    redis.hdel('runs', params[:run_number])
    redis.del(params[:run_number])
    redis.hgetall('competitors').each do |competitor, infos|
      competitor_infos = JSON.parse(infos)
      competitor_infos = competitor_infos.except(params[:run_number])
      redis.hmset('competitors', competitor, competitor_infos.to_json)
    end
    redis.close
  end
end
