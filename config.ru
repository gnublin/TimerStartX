# MIT License
# Copyright (c) 2022 Gauthier FRANCOIS
# frozen_string_literal: true

require 'bundler/setup'
require './app/timerstartx'

enable :sessions

Bundler.require :default, :development

run TimerStartX
