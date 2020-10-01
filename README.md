### HLS Downloader

Download HLS streams.

#### Gem usage

```ruby
require 'hls-download'

hls_stream = HLSDownload::HLS.new 'https://hls.cdn/mystream/manifest.m3u8'
hls_stream.download! output_dir: '/var/www/hls/mystream'
```

#### Docker

https://hub.docker.com/r/vualto/hls-download
