require 'json'
require 'net/https'
require 'rubygems'
require 'uri'
require '/opt/solr/solrmonitor/auth_helper'

module Solr

  module RestClient

    include Solr::AuthHelper

      def get_no_auth(host_name, port, uri)
        http = Net::HTTP.new(host_name, port)
        http.open_timeout = 50 #timeout
        http.use_ssl = false


        resp = nil

        http.start do |http|
          req = Net::HTTP::Get.new(uri)
          resp, data = http.request(req)
        end

        if resp != nil then
          response_body = resp.body()
          puts "Responsei is #{response_body}"
          resp_obj = JSON.parse(response_body)
          if resp_obj["responseHeader"]["status"] == 0
            return resp_obj
          else
            puts "Solr API returned an error #{resp.body()}"
            exit 1
          end
        end

        raise StandardError, "empty response from http://#{host_name}:#{port}#{uri}"
      end


      def get(host_name, port, uri)
          username = nil
          password = nil

          if auth_enabled?
              admincreds = get_solr_admin_credentials()
              username = admincreds['username']
              password = admincreds['password']
          end

          return get_auth(host_name, port, uri, username, password)
      end

      def get_auth(host_name, port, uri, username, password)

        http = Net::HTTP.new(host_name, port)
        http.open_timeout = 50 #timeout
        http.use_ssl = false


        resp = nil

        http.start do |http|
          req = Net::HTTP::Get.new(uri)
          unless username.nil? || password.nil?
            req.basic_auth(username, password)
          end

          resp, data = http.request(req)
        end

        if resp != nil then
          response_body = resp.body()
          puts "Responsei is #{response_body}"
          resp_obj = JSON.parse(response_body)
          if resp_obj["responseHeader"]["status"] == 0
            return resp_obj
          else
            puts "Solr API returned an error #{resp.body()}"
            exit 1
          end
        end

        raise StandardError, "empty response from http://#{host_name}:#{port}#{uri}"

      end

      def post(host_name, port, uri, payload)
        username = nil
        password = nil
        if auth_enabled?
          admincreds = get_solr_admin_credentials()
          username = admincreds[:username]
          password = admincreds[:password]
        end
        return post_auth(host_name, port, uri, payload, username,password)
      end

      def post_no_auth(host_name, port, uri, payload, username = nil, password = nil)

          http = Net::HTTP.new(host_name, port)
          http.use_ssl = false

          resp = nil

          http.start do |http|
            req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
            req.body = payload
            unless username.nil? || password.nil?
              req.basic_auth(username, password)
            end
            puts req.body
            resp, data = http.request(req)
          end

          if resp != nil then
            if resp.code == "200"
              response_body = resp.body()
              resp_obj = JSON.parse(response_body)
              return resp_obj
            else
              puts "Solr API returned an error #{resp.body()}"
              exit 1
            end
          end

          raise StandardError, "empty response from http://#{host_name}:#{port}#{uri}"

        end



      def post_auth(host_name, port, uri, payload, username = nil, password = nil)

        http = Net::HTTP.new(host_name, port)
        http.use_ssl = false

        resp = nil

        http.start do |http|
          req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
          req.body = payload
          unless username.nil? || password.nil?
            req.basic_auth(username, password)
          end
          puts req.body
          resp, data = http.request(req)
        end

        if resp != nil then
          if resp.code == "200"
            response_body = resp.body()
            resp_obj = JSON.parse(response_body)
            return resp_obj
          else
            puts "Solr API returned an error #{resp.body()}"
            exit 1
          end
        end

        raise StandardError, "empty response from http://#{host_name}:#{port}#{uri}"

      end

  end

end




