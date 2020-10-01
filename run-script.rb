#!/usr/bin/env ruby

require 'logger'
require_relative 'lib/hls'

def usage_and_exit
  puts '<script> <url> [opts]'
  puts '  opts:'
  puts '   --output-dir : output directory'
  exit(1)
end

master_url = nil
opts = {}

if ARGV[0].start_with? '--'
  arg_opts =  ARGV[0..-2]
  master_url = ARGV[-1]
else
  arg_opts =  ARGV[1..-1]
  master_url = ARGV[0]
end

arg_opts.each_with_index do |arg, i|
  next unless arg.start_with? '--'
  arg_val = nil
  if arg.include? '='
    arg = arg.split('=').first
    arg_val = arg.split('=').last
  else
    arg_val = arg_opts[i+1]
  end

  case arg
  when '--output-dir'
    opts[:output_dir] = arg_val
  else
    puts "option #{arg} not recognized"
    usage_and_exit
  end
end

hls = HLSDownload::HLS.new(master_url)
hls.logger.level = Logger::DEBUG
hls.download! opts