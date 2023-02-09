# MIT License
# Copyright (c) 2022 Gauthier FRANCOIS
# frozen_string_literal: true

connections = []

post '/portal_update_status' do
  redis = Redis.new
  redis.hset('portals', params[:portal_name], params[:portal_status])
  redis.close
  redirect request.referer
end

get '/events', provides: 'text/event-stream' do
  stream(:keep_open) do |out|
    connections << out
    connections.reject!(&:closed?)
  end
end

get '/push' do
  connections.each do |out|
    out << "data: #{params}\n\n"
    out.close
  end
  ''
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