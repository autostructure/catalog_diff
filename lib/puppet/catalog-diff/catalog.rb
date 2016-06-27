require 'puppet/network/http_pool'
require 'uri'
require 'json'

module Puppet::CatalogDiff
  class Catalog
    def self.get_catalog(server, environment, node, facts)
      catalog = ''

      # Clone a passed in object.
      local_facts = facts.clone

      # Ensure name, tracer, and clientcert match node name. Delete the trusted facts.
      # local_facts["name"] = node

      # local_facts["values"]["tracer"] = node
      # local_facts["values"]["clientcert"] = node

      local_facts["values"].delete("trusted")

      # Let's stick to PSON for now. Early version of Puppet accept only PSON.
      facts_pson = PSON.generate(local_facts)

      # Escape facts not once, not thrice, but twice
      facts_pson_encoded = CGI.escape(CGI.escape(facts_pson))

      endpoint = "/puppet/v3/catalog/#{node}?environment=#{environment}"
      data = "environment=production&facts_format=pson&facts=#{facts_pson_encoded}"

      begin
        connection = Puppet::Network::HttpPool.http_instance(server, '8140')
        response = connection.post(endpoint, data, 'Content-Type' => 'application/x-www-form-urlencoded').body

        filtered = JSON.parse(response)

        catalog = Puppet::CatalogDiff::Catalog.new(
          filtered['tags'],
          filtered['name'],
          filtered['version'],
          filtered['code_id'],
          filtered['catalog_uuid'],
          filtered['catalog_format'],
          filtered['environment'],
          filtered['resources'],
          filtered['edges'],
          filtered['classes']
        )
      rescue Exception => e
        raise "Error retrieving catalog from #{server}: #{e.message}"
      end

      catalog
    end

    def to_json
      {
        'tags' => @tags,
        'name' => @name,
        'version' => @version,
        'code_id' => @code_id,
        'catalog_uuid' => @catalog_uuid,
        'catalog_format' => @catalog_format,
        'environment' => @environment,
        'resources' => @resources,
        'edges' => @edges,
        'classes' => @classes
      }.to_json
    end

    def initialize(tags, name, version, code_id, catalog_uuid, catalog_format, environment, resources, edges, classes)
      @tags = tags
      @name = name
      @version = version
      @code_id = code_id
      @catalog_uuid = catalog_uuid
      @catalog_format = catalog_format
      @environment = environment
      @resources = resources
      @edges = edges
      @classes = classes
    end

    def ==(other_item)
      @tags == other_item.tags &&
      @name == other_item.name &&
      @environment == other_item.environment &&
      @resources == other_item.resources &&
      @edges == other_item.edges &&
      @classes == other_item.classes
    end

    def eql?(other_item)
      self == other_item
    end

    def hash
      @tags.hash ^ @name.hash ^ @environment.hash ^ @resources.hash ^ @edges.hash ^ @classes.hash
    end

    attr_reader :tags

    attr_reader :name

    attr_reader :version

    attr_reader :code_id

    attr_reader :catalog_uuid

    attr_reader :catalog_format

    attr_reader :environment

    attr_reader :resources

    attr_reader :edges

    attr_reader :classes
  end
end
