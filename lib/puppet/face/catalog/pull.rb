require 'puppet/face'
require 'thread'
require 'digest'
# require 'puppet/application/master'

Puppet::Face.define(:catalog, '0.0.1') do
  action :pull do
    description 'Pull catalogs from dual puppet masters'
    arguments '/tmp/old_catalogs /tmp/new_catalogs'

    option '--threads' do
      summary 'The number of threads to use'
      default_to { '10' }
    end

    option '--use_puppetdb' do
      summary 'Use puppetdb to do the fact search instead of the rest api'
    end

    option '--filter_local' do
      summary 'Use local YAML node files to filter out queried nodes'
    end

    option '--changed_depth=' do
      summary 'The number of problem files to display sorted by changes'

      default_to { '10' }
    end

    description <<-'EOT'
      This action is used to seed a series of catalogs from two servers
    EOT
    notes <<-'NOTES'
      This will store files in pson format with the in the save directory. i.e.
      <path/to/seed/directory>/<node_name>.pson . This is currently the only format
      that is supported.

    NOTES
    examples <<-'EOT'
      Dump host catalogs:

      $ puppet catalog pull /tmp/old_catalogs /tmp/new_catalogs kernel=Linux --old_server puppet2.puppetlabs.vm --new_server puppet3.puppetlabs.vm
    EOT

    when_invoked do |old_pe_hostname, new_pe_hostname, old_catalogs_directory, new_catalogs_directory, args, options|
      require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'catalog-diff', 'searchfacts.rb'))
      require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'catalog-diff', 'compilecatalog.rb'))
      require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'catalog-diff', 'factset.rb'))
      require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'catalog-diff', 'catalog.rb'))

      thread_count = options[:threads].to_i
      compiled_nodes = []
      failed_nodes = {}
      mutex = Mutex.new

      Puppet.debug("ARGS: #{ARGV}")
      Puppet.debug("args: #{args}")
      Puppet.debug("options: #{options}")
      Puppet.debug("Old PE hostname: #{old_pe_hostname}")
      Puppet.debug("New PE hostname: #{new_pe_hostname}")

      factsets = Puppet::CatalogDiff::FactSet.get_factsets(old_pe_hostname)

      total_nodes = factsets.size

      # Array.new(thread_count) {
      #  Thread.new(nodes, compiled_nodes, options) do |nodes, compiled_nodes, options|
      #    while node_name = mutex.synchronize { nodes.pop }
      factsets.each do |factset|
        begin
          environment = 'production'

          Puppet.debug("environment: #{environment}")
          Puppet.debug("factset.certname: #{factset.certname}")

          catalog_old = Puppet::CatalogDiff::Catalog.get_catalog(old_pe_hostname, environment, factset.certname, factset.to_facts_schema)
          catalog_new = Puppet::CatalogDiff::Catalog.get_catalog(new_pe_hostname, environment, factset.certname, factset.to_facts_schema)

          Puppet::CatalogDiff::CompileCatalog.save_catalog_to_disk(old_catalogs_directory, factset.certname, catalog_old.to_json, 'json')
          Puppet::CatalogDiff::CompileCatalog.save_catalog_to_disk(new_catalogs_directory, factset.certname, catalog_new.to_json, 'json')
        rescue Exception => e
          Puppet.err(e.to_s)
        end
      end

      output = {}
      output[:failed_nodes]         = failed_nodes
      output[:failed_nodes_total]   = failed_nodes.size
      output[:compiled_nodes]       = compiled_nodes.compact
      output[:compiled_nodes_total] = compiled_nodes.compact.size
      output[:total_nodes]          = total_nodes
      output[:total_percentage]     = (failed_nodes.size.to_f / total_nodes.to_f) * 100
      problem_files = {}

      failed_nodes.each do |node_name, error|
        # Extract the filename and the node a key of the same name
        match = /(\S*(\/\S*\.pp|\.erb))/.match(error.to_s)
        if match
          (problem_files[match[1]] ||= []) << node_name
        else
          unique_token = Digest::MD5.hexdigest(error.to_s.gsub(node_name, ''))
          (problem_files["No-path-in-error-#{unique_token}"] ||= []) << node_name
        end
      end

      most_changed = problem_files.sort_by { |_file, nodes| nodes.size }.map do |file, nodes|
        Hash[file => nodes.size]
      end

      output[:failed_to_compile_files] = most_changed.reverse.take(options[:changed_depth].to_i)

      example_errors = output[:failed_to_compile_files].map do |file_hash|
        example_error = file_hash.map { |file_name, _metric|
          example_node = problem_files[file_name].first
          error = failed_nodes[example_node].to_s
          Hash[error => example_node]
        }.first
        example_error
      end
      output[:example_compile_errors] = example_errors
      output
    end
    when_rendering :console do |output|
      require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'catalog-diff', 'formater.rb'))
      format = Puppet::CatalogDiff::Formater.new
      output.map { |key, value|
        if value.is_a?(Array) && key == :failed_to_compile_files
          format.list_file_hash(key, value)
        elsif value.is_a?(Array) && key == :example_compile_errors
          format.list_error_hash(key, value)
        end
      }.join("\n")
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
