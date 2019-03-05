require 'puppet/network/http_pool'
require 'uri'
require 'json'

module Puppet::CatalogDiff
  class GetCatalog
    def initialize(node_name, fact_set, save_directory, server)
      catalog = retrieve_catalog(node_name, fact_set, server)
      begin
        JSON.parse(catalog)
        save_facts_to_disk(save_directory, node_name, catalog, 'json')
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

    def retrieve_catalog(node_name, fact_set, server)
      _server = server.split('/')[0]
      _env = server.split('/')[1]

      endpoint = "/puppet/v3/catalog/#{node_name}"
      Puppet.debug("getcatalog.rb: Retrieving catalog for #{node_name} from server #{server}")

      begin
        connection = Puppet::Network::HttpPool.http_instance(_server, '8140')
        catalog = connection.request_post(endpoint, fact_set, 'Accept' => 'application/json').body
      rescue Exception => e
        raise "Failed to retrieve facts for #{node_name} from #{server} in environment #{_environment}: #{e.message}"
      end

      Puppet.debug("getcatalog.rb: Found catalog for #{node_name} from server #{server}")
      catalog
    end

    def save_catalog_to_disk(save_directory, node_name, catalog, extention)
      File.open("#{save_directory}/#{node_name}.#{extention}", 'w') do |f|
        f.write(catalog)
      end
    rescue Exception => e
      raise "Failed to save catalog for #{node_name} in #{save_directory}: #{e.message}"
    end
  end
end
