# -*- coding: utf-8 -*-
require 'mechanize'
require 'addressable/uri'

module Github
  module Trending
    def self.get(language = nil, since = nil)
      scraper = Github::Trending::Scraper.new
      scraper.get(language, since)
    end

    def self.languages
      scraper = Github::Trending::Scraper.new
      scraper.list_languages
    end

    class << self
      alias_method :all_languages,  :languages
      alias_method :get_languages,  :languages
      alias_method :list_languages, :languages
    end

    class Scraper
      BASE_HOST = 'https://github.com'
      BASE_URL = "#{BASE_HOST}/trending"

      def initialize
        @agent = Mechanize.new
        @agent.user_agent = "github-trending #{VERSION}"
        proxy = URI.parse(ENV['http_proxy']) if ENV['http_proxy']
        @agent.set_proxy(proxy.host, proxy.port, proxy.user, proxy.password) if proxy
      end

      def get(language = nil, since = nil)
        projects = []
        page = @agent.get(generate_url_for_get(language, since))

        # modify
        page.search('.repo-list').each do |content|
          project = Project.new
          
          project.name = content.at('div h3 a')['href'][0..1000]
          project.lang = content.at("span[itemprop*='programmingLanguage']").inner_text
          project.description = content.at('div.py-1 p').inner_text
          project.star_count = content.at("a[href*=${project.name}/stargazers").inner_text.gsub(',', '').to_i
          project.url = BASE_HOST + '/' + project.name
          
          projects << project
        end
        fail ScrapeException if projects.empty?
        projects
      end

      def list_languages
        languages = []
        page = @agent.get(BASE_URL)
        page.search('div.select-menu-item a').each do |content|
          href = content.attributes['href'].value
          # objective-c++ =>
          language = href.match(/github.com\/trending\?l=(.+)/).to_a[1]
          languages << CGI.unescape(language) if language
        end
        languages
      end

      private

      def generate_url_for_get(language, since)
        language = language.to_s.gsub('_', '-') if language

        if since
          since =
            case since.to_sym
              when :d, :day,   :daily   then 'daily'
              when :w, :week,  :weekly  then 'weekly'
              when :m, :month, :monthly then 'monthly'
              else nil
            end
        end

        uri = Addressable::URI.parse(BASE_URL)
        if language || since
          uri.query_values = { l: language, since: since }.delete_if { |_k, v| v.nil? }
        end
        uri.to_s
      end

      # unused
      def extract_lang_and_star_from_meta(text)
        meta_data = text.split('•').map { |x| x.gsub("\n", '').strip }
        if meta_data.size == 3
          lang = meta_data[0]
          star_count = meta_data[1].gsub(',', '').to_i
          [lang, star_count]
        else
          star_count = meta_data[0].gsub(',', '').to_i
          ['', star_count]
        end
      end
    end
  end
end
