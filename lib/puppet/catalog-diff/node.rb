require 'puppet/network/http_pool'
require 'json'
require 'net/http'

module Puppet::CatalogDiff
  class Node
    def self.get_nodes(server)
      response = Net::HTTP.get URI("http://#{server}:8080/pdb/query/v4/nodes")

      json = JSON.parse(response)
      json.each do |node|
        get_factset(node, server)
      end
    rescue Exception => e
      raise "Error retrieving facts from #{server}: #{e.message}"
    end
  end
end
