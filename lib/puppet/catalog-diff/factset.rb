require 'puppet/network/http_pool'
require 'json'
require 'net/http'

module Puppet::CatalogDiff
  # A list of all facts taken from Puppet Enterprise
  class FactSet
    # The get_factsets retrieves all of the factsets on a puppet master
    #
    # @param pe_hostname [String] The hostname of the puppet enterprise server to pull the factsets from
    # @return [Array<FactSets] a list of the factsets contained in enterprise's puppet database
    def self.get_factsets(pe_hostname)
      factsets = []
      endpoint = '/pdb/query/v4/factsets'

      begin
        connection = Puppet::Network::HttpPool.http_instance(pe_hostname, '8081')
        response = connection.request_get(endpoint, 'Accept' => 'application/json').body
        filtered = PSON.load(response)

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
        # rescue Exception => e
        #   raise "Error retrieving factset from #{server}: #{e.message}"
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
      facts['data'].each do |fact|
        fact_name = fact['name']
        fact_value = fact['value']

        facts_hash[fact_name] = fact_value
      end
      timestamp_new = DateTime.now

      expiration = DateTime.iso8601(timestamp_new.iso8601(9)) + 1

      facts_schema = {
        'name' => certname,
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
