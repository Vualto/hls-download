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

  class HLSMediaFile
    attr_accessor :url, :index, :raw

    def initialize(url, index, raw)
      @url = url
      @index = index
      @raw = raw
    end
  end

  class HLS    
    attr_accessor :sub_m3u8, :main_url, :media_files, :logger, :prefix, :raw_url, :iframe_m3u8

    def initialize(url, logger = nil, prefix = nil)
      @raw_url = url
      @logger = logger || new_logger
      @main_url = URI.parse(url)
      @media_files = []
      @sub_m3u8 = []
      @prefix = prefix
      @iframe_m3u8 = []
      parse @main_url
    end

    def download!(opts = {})
      manifest_file = main_url.path.split('/').last
      base_url = main_url.to_s.gsub("/#{manifest_file}", '')
      @output_dir = opts[:output_dir] || 'out'
      FileUtils.mkdir_p @output_dir

      main_manifest_output = File.join(@output_dir, 'manifest.m3u8')
      main_manifest_contents = http_get(main_url)
      
      sub_m3u8.each do | m3u8 |
        output = nil
        if m3u8.prefix
          rel_path = File.join(m3u8.prefix, 'index.m3u8')
          output = File.join(@output_dir, rel_path)
          # rewrite contents
          main_manifest_contents.gsub!(m3u8.raw_url, rel_path)
        else
          output = m3u8.main_url.to_s.gsub(base_url, @output_dir)
        end
        manifest_contents = http_get(m3u8.main_url)
        m3u8.media_files.each_with_index do | media_file, i |
          media_output = nil
          if m3u8.prefix
            ext = File.extname(media_file.raw.split('?')[0].split('/').last)
            basename = "#{i+1}#{ext}"
            media_output = File.join(@output_dir, m3u8.prefix, basename)
            # rewrite contents
            manifest_contents.gsub!(media_file.raw, basename)
          else
            media_output = media_file.url.gsub(base_url, @output_dir)
          end
          download_file(URI.parse(media_file.url), media_output)
        end

        write(output, manifest_contents)
      end
      
      write(main_manifest_output, main_manifest_contents)

      # TODO download recursively. i.e. allow downloading only 1 rendition
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
        files.each_with_index do |f, i|
          raw = f
          unless f.include? '://'
            # relative path
            f_url = url.dup
            split_path = f_url.dup.path.split('/')
            split_path[-1] = f
            path = File.join(split_path)
            f_url.path = path.start_with?('/') ? path : "/#{path}"
            f = f_url.to_s
          end
          @media_files << HLSMediaFile.new(f, i, raw)
        end
        
        return
      end
      
      # this is a master playlist
      uris = []
      lines.select { |l| l.include? '.m3u8' }.each do |l|
        is_iframe = false
        if l.start_with? '#'
          is_iframe = l.include?('I-FRAME-STREAM-INF')
          uri_res = nil
          l.split(',').each do | attribute |
            next unless attribute.start_with? 'URI'
            uri_res = attribute.gsub('URI=', '').gsub('"', '')
          end
          if is_iframe
            # TODO add support for iframe playlists
            raise HLSException.new('I-FRAME-STREAM-INF not supported')
            # @iframe_m3u8 << uri_res
          else
            uris << uri_res
          end
        else
          uris << l
        end
      end

      uris.each_with_index do |u, i|
        prefix = nil
        if u.include? '://'
          prefix = "presentation_#{i}"
        else
          # relative path
          s_url = url.dup
          split_path = s_url.dup.path.split('/')
          split_path[-1] = u
          path = File.join(split_path)
          s_url.path = path.start_with?('/') ? path : "/#{path}"
          u = s_url.to_s
        end
        logger.debug "sub playlist found #{u}"
        sub_m3u8 << HLS.new(u, logger, prefix)
      end

      # TODO add support for iframe playlists
      # @iframe_m3u8 = iframe_m3u8.map do |u|
      #   if u.include? '://'
      #   else
      #     # relative path
      #     s_url = url.dup
      #     split_path = s_url.dup.path.split('/')
      #     split_path[-1] = u
      #     path = File.join(split_path)
      #     s_url.path = path.start_with?('/') ? path : "/#{path}"
      #     u = s_url.to_s
      #   end
      # end
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
        write(output, resp.body)
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

    def write(output, contents)
      open(output, "wb") do |file|
        file.write(contents)
      end
    end

  end
end
