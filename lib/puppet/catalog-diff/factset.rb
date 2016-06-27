require 'puppet/network/http_pool'
# require 'uri'
require 'json'
require 'net/http'

module Puppet::CatalogDiff
  class FactSet
    def self.get_factsets(server)
      factsets = []
      endpoint = '/pdb/query/v4/factsets'
      begin
        # response = Net::HTTP.get URI("https://#{server}:8081/pdb/query/v4/factsets")
        connection = Puppet::Network::HttpPool.http_instance(server, '8081')
        response = connection.request_get(endpoint, 'Accept' => 'application/json').body
        # Puppet.debug "response = #{response}"
        #
        filtered = PSON.load(response)
        # json = JSON.parse(response)

        filtered.each do |factset|
          factsets << Puppet::CatalogDiff::FactSet.new(
            factset['timestamp'],
            factset['facts'],
            factset['certname'],
            factset['hash'],
            factset['producer_timestamp'],
            factset['producer'],
            factset['environment'],
          )
        end
      rescue Exception => e
        raise "Error retrieving factset from #{server}: #{e.message}"
      end

      factsets
    end

    def initialize(timestamp, facts, certname, hash, producer_timestamp, producer, environment)
      @timestamp = timestamp
      @facts = facts
      @certname = certname
      @hash = hash
      @producer_timestamp = producer_timestamp
      @producer = producer
      @environment = environment
    end

    def ==(other_item)
      @facts == other_item.facts &&
      @certname == other_item.certname &&
      @environment == other_item.environment
    end

    def eql?(other_item)
      self == other_item
    end

    def to_facts_schema
      # Parse all hashes of the facts data array and create large hash
      #
      facts_hash = {}
      self.facts['data'].each do |fact|
        fact_name = fact['name']
        fact_value = fact['value']

        facts_hash[fact_name] = fact_value
      end
      timestamp_new = DateTime.now
      
      expiration = DateTime.iso8601(timestamp_new.iso8601(9)) + 1

      facts_schema = {
        'name' => self.certname,
        'values' => facts_hash,
        'timestamp' => timestamp_new.iso8601(9),
        'expiration' => expiration.iso8601(9)
      }

    end

    attr_reader :timestamp

    attr_reader :facts

    attr_reader :certname

    attr_reader :hash

    attr_reader :producer_timestamp

    attr_reader :producer

    attr_reader :environment
  end
end
