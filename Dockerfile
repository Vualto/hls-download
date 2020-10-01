FROM ruby:2.5

COPY lib/hls.rb lib/hls.rb
COPY run-script.rb run-script.rb

ENTRYPOINT ["ruby", "run-script.rb"]