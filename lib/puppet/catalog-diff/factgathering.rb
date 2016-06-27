require 'puppet/network/http_pool'
require 'uri'
require 'json'

module Puppet::CatalogDiff
  class FactGathering
    def initialize(node_name, save_directory, server)
      @node_name = node_name
      facts = retrieve_facts(node_name, server)
      begin
        JSON.parse(facts)
        save_facts_to_disk(save_directory, node_name, facts, 'json')
      rescue Exception => e
        Puppet.err("Server returned invalid facts for #{node_name}")
        save_facts_to_disk(save_directory, node_name, facts, 'error')
        if facts =~ %r{.document_type.:.Catalog.}
          raise e.message
        else
          raise facts
        end
      end
    end

    def retrieve_facts(node_name, server)
      _server = server.split('/')[0]
      _env = server.split('/')[1]

      query_unencoded = "query=[\"=\", \"certname\", \"#{node_name}\"]"
      query_encoded = CGI.escape(query_unencoded).to_s
      endpoint = "/pdb/query/v4/facts?#{query_encoded}"
      begin
        connection = Puppet::Network::HttpPool.http_instance(_server, '8081')
        facts = connection.request_get(endpoint, 'Accept' => 'application/json').body
      rescue Exception => e
        raise "Failed to retrieve facts for #{node_name} from #{server} in environment #{_environment}: #{e.message}"
      end
      facts
    end

    def save_facts_to_disk(save_directory, node_name, facts, extention)
      File.open("#{save_directory}/#{node_name}.facts.#{extention}", 'w') do |f|
        f.write(facts)
      end
    rescue Exception => e
      raise "Failed to save facts for #{node_name} in #{save_directory}: #{e.message}"
    end
  end
end
