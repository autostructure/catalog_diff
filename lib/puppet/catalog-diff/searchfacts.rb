require 'puppet/network/http_pool'
require 'uri'
require 'json'

module Puppet::CatalogDiff
  class SearchFacts
    def initialize(facts)
      @facts = Hash[facts.split(',').map { |f| f.split('=') }]
    end

    def find_nodes(options = {})
      # Pull all nodes from the yaml cache
      # Then validate they are active nodes against the rest of puppetdb api
      old_server = options[:old_server].split('/')[0]
      old_env = options[:old_server].split('/')[1]
      active_nodes = if options[:use_puppetdb]
                       find_nodes_puppetdb(old_env)
                     else
                       find_nodes_rest(old_server)
                     end
      if active_nodes.empty?
        raise 'No active nodes were returned from your fact search'
      end
      if options[:filter_local]
        yaml_cache = find_nodes_local
        yaml_cache.select { |node| active_nodes.include?(node) }
      else
        active_nodes
      end
    end

    def find_nodes_local
      Puppet[:clientyamldir] = Puppet[:yamldir]
      if Puppet::Node.respond_to? :terminus_class
        Puppet::Node.terminus_class = :yaml
        nodes = Puppet::Node.search('*')
      else
        Puppet::Node.indirection.terminus_class = :yaml
        nodes = Puppet::Node.indirection.search('*')
      end
      unless filtered = nodes.select { |n|
                          @facts.select { |f, v| n[f] == v }.size == @facts.size
                        }.map { |n| n.name }
        raise 'No matching nodes found using yaml terminus'
      end
      filtered
    end

    def find_nodes_rest(server)
      # query = @facts.map { |k, v| "facts.#{k}=#{v}" }.join('&')
      query = '%5Bcertname%5D%7Bdeactivated+is+null%7D'
      endpoint = "/pdb/query/v4?query=nodes#{query}"

      begin
        connection = Puppet::Network::HttpPool.http_instance(server, '8081')
        facts_object = connection.request_get(endpoint, 'Accept' => 'application/json').body
      rescue Exception => e
        raise "Error retrieving facts from #{server}: #{e.message}"
      end

      begin
        filtered = PSON.load(facts_object)
      rescue Exception => e
        raise "Received invalid data from facts endpoint on filtered: #{filtered}, server: #{server}, query: #{query}, facts_object: #{facts_object}, emessage: #{e.message}"
      end
      names = filtered.map { |node| node['certname'] }
      Puppet.debug("Names has: #{names}")
      names
    end

    def find_nodes_puppetdb(env)
      require 'puppet/util/puppetdb'
      server_url = Puppet::Util::Puppetdb.config.server_urls[0]
      port = server_url.port
      use_ssl = port != 8080
      connection = Puppet::Network::HttpPool.http_instance(server_url.host, port, use_ssl)
      base_query = ['and', ['=', ['node', 'active'], true]]
      base_query.concat([['=', 'catalog_environment', env]]) if env
      real_facts = @facts.reject { |_k, v| v.nil? }
      query = base_query.concat(real_facts.map { |k, v| ['=', ['fact', k], v] })
      classes = Hash[@facts.select { |_k, v| v.nil? }].keys
      classes.each do |c|
        capit = c.split('::').map { |n| n.capitalize }.join('::')
        query = query.concat(
          [['in', 'certname',
            ['extract', 'certname',
             ['select-resources',
              ['and',
               ['=', 'type', 'Class'],
               ['=', 'title', capit]]]]]],
        )
      end
      json_query = URI.escape(query.to_json)
      unless filtered = PSON.load(connection.request_get("/pdb/query/v4/nodes?query=#{json_query}", 'Accept' => 'application/json').body)
        raise 'Error parsing json output of puppet search'
      end
      names = filtered.map { |node| node['certname'] }
      names
    end
  end
end
