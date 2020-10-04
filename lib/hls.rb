require 'net/http'
require 'uri'
require 'pathname'
require 'fileutils'
require 'logger'

module HLSDownload
  
  MEDIA_FORMAT_EXTENSIONS = [
    '.ts',
    '.aac',
    '.vtt',
    '.webvtt',
    '.m4a',
    '.f4a',
    # add as needed
  ]

  class HLSException < Exception
  end

  class HLS    
    attr_accessor :sub_m3u8, :main_url, :media_files, :logger

    def initialize(url, logger = nil)
      @logger = logger || new_logger
      @main_url = URI.parse(url)
      @media_files = []
      @sub_m3u8 = []
      parse @main_url
    end

    def download!(opts = {})
      manifest_file = main_url.path.split('/').last
      base_url = main_url.to_s.gsub("/#{manifest_file}", '')
      @output_dir = opts[:output_dir] || 'out'
      FileUtils.mkdir_p @output_dir
      
      download_file(main_url, File.join(@output_dir, 'manifest.m3u8'))
      
      sub_m3u8.each do | m3u8 |
        output = m3u8.main_url.to_s.gsub(base_url, @output_dir)
        download_file(m3u8.main_url, output)
        m3u8.media_files.each do | file_url |
          output = file_url.gsub(base_url, @output_dir)
          download_file(URI.parse(file_url), output)
        end
      end

      media_files.each do | file_url |
        output = file_url.gsub(base_url, @output_dir)
        download_file(URI.parse(file_url), output)
      end
    end

    private

    def parse(url)
      man = http_get(url)
      logger.debug "parsing manifest"
      lines = man.split("\n")
      
      unless man.include? '.m3u8'
        # this is a variant playlist
        raise HLSException.new('unsupported media playlist') unless is_media_playlist? man
        logger.debug 'getting media url(s)'
        files = lines.reject { |l| l.start_with? '#' }
        @media_files = files.map do |f|
          unless f.include? '://'
            # relative path
            f_url = url.dup
            split_path = f_url.dup.path.split('/')
            split_path[-1] = f
            path = File.join(split_path)
            f_url.path = path.start_with?('/') ? path : "/#{path}"
            f = f_url.to_s
          end
          f
        end
        
        return
      end
      
      # this is a master playlist
      uris = lines.select { |l| l.include? '.m3u8' }.map do |l|
        if l.start_with? '#'
          uri_res = nil
          l.split(',').each do | attribute |
            next unless attribute.start_with? 'URI'
            uri_res = attribute.gsub('URI=', '').gsub('"', '')
          end
          uri_res
        else
          l
        end
      end

      sub_m3u8_urls = uris.map do |u|
        unless u.include? '://'
          # relative path
          s_url = url.dup
          split_path = s_url.dup.path.split('/')
          split_path[-1] = u
          path = File.join(split_path)
          s_url.path = path.start_with?('/') ? path : "/#{path}"
          u = s_url.to_s
        end
        logger.debug "sub playlist found #{u}"
        sub_m3u8 << HLS.new(u)
      end
    end

    def http_get(url)
      logger.debug "http get #{url.to_s}"
      download_file(url, '/dev/null')
    end

    def download_file(url, output)
      unless output == '/dev/null'
        logger.debug "downloading #{output}"
        dir = Pathname.new(output).dirname.to_s
        unless File.directory?(dir)
          logger.debug "creating dir: #{dir}"
          FileUtils.mkdir_p(dir) 
        end
      end
      resp = nil
      Net::HTTP.start(url.host) do |http|
        resp = http.get("#{url.path}?#{url.query}")
        if ['4', '5'].include? resp.code[0]
          raise HLSException.new("#{url} response status code: #{resp.code}")
        end
        open(output, "wb") do |file|
          file.write(resp.body)
        end
      end
      resp.body
    end

    def is_media_playlist?(man)
      MEDIA_FORMAT_EXTENSIONS.each do |ext|
        return true if man.include? ext
      end
      false
    end

    def new_logger
      l = Logger.new STDOUT
      l.level = Logger::ERROR
      l
    end

  end
end