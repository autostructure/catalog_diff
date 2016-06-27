require 'puppet/network/http_pool'
require 'json'

module Puppet::CatalogDiff
  class CompileCatalog
    attr_reader :node_name

    def initialize(node_name, save_directory, server)
      @node_name = node_name
      catalog = compile_catalog(node_name, server)
      begin
        # PSON.parse(catalog)
        JSON.parse(catalog)
        # save_catalog_to_disk(save_directory,node_name,catalog,'pson')
        save_catalog_to_disk(save_directory, node_name, catalog, 'json')
      rescue Exception => e
        Puppet.err("Server returned invalid catalog for #{node_name}")
        save_catalog_to_disk(save_directory, node_name, catalog, 'error')
        if catalog =~ %r{.document_type.:.Catalog.}
          raise e.message
        else
          raise catalog
        end
      end
    end

    def compile_catalog(node_name, server)
      server, environment = server.split('/')
      environment ||= lookup_environment(node_name, server)
      # endpoint = "/#{environment}/catalog/#{node_name}"
      endpoint = "/pdb/query/v4/catalogs/#{node_name}"
      Puppet.debug("Connecting to server: #{server}")
      begin
        connection = Puppet::Network::HttpPool.http_instance(server, '8081')
        catalog = connection.request_get(endpoint, 'Accept' => 'application/json').body
      rescue Exception => e
        raise "Failed to retrieve catalog for #{node_name} from #{server} in environment #{environment}: #{e.message}"
      end
      catalog
    end

    def save_catalog_to_disk(save_directory, node_name, catalog, extention)
      File.open("#{save_directory}/#{node_name}.#{extention}", 'w') do |f|
        f.write(catalog)
      end
    rescue Exception => e
      raise "Failed to save catalog for #{node_name} in #{save_directory}: #{e.message}"
    end

    def self.save_catalog_to_disk(save_directory, node_name, catalog, extention)
      File.open("#{save_directory}/#{node_name}.#{extention}", 'w') do |f|
        f.write(catalog)
      end
    rescue Exception => e
      raise "Failed to save catalog for #{node_name} in #{save_directory}: #{e.message}"
    end
  end
end
