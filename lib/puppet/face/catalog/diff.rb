require 'puppet/face'
require 'thread'
require 'json'

begin
  require 'parallel'
  HAS_PARALLEL_GEM = true
rescue LoadError
  HAS_PARALLEL_GEM = false
end

Puppet::Face.define(:catalog, '0.0.1') do
  action :diff do
    summary 'Compare catalogs from different puppet versions.'
    arguments '<old_pe_hostname> <new_pe_hostname>'

    option '--fact_search=' do
      summary 'Fact search used to filter which catalogs are compiled and compared'

      default_to { 'kernel=Linux' }
    end

    option '--old_pe_branch' do
      summary 'Old puppet master branch to compare with'

      default_to { 'production' }
    end

    option '--new_pe_branch' do
      summary 'New puppet master branch to compare with'

      default_to { 'production' }
    end

    option '--output_report=' do
      summary 'Save the final report as json'
    end

    option '--content_diff' do
      summary 'Whether to show a diff for File resource content'
    end

    option '--show_resource_diff' do
      summary 'Display differeces between resources in unified diff format'
    end

    option '--exclude_classes' do
      summary 'Do not print classes in resource diffs'
    end

    option '--filter_local' do
      summary 'Use local YAML node files to filter out queried nodes'
    end

    option '--changed_depth=' do
      summary 'The number of nodes to display sorted by changes'
      default_to { '10' }
    end

    option '--threads=' do
      summary 'The number of connections for the compiles to use'
      default_to { '10' }
    end

    description <<-'EOT'
      Prints the differences between catalogs compiled by different puppet master to help
      during migrating to a new Puppet version.
    EOT
    notes <<-'NOTES'
      The diff tool recognizes catalogs in yaml, marshall, or pson format.

      Validation Process:

       - Grab a catalog from your existing machine running the old version
       - Configure your new Puppet master, copy the facts from your old master
         to the new one
       - Compile the catalog for this host on the new master:

            puppet master --compile fqdn > fqdn.pson

       - Puppet puts a header in some catalogs compiled in this way, remove it if present
       - At this point you should have 2 different catalogs. To compare them run:

            puppet catalog diff <old_pe_hostname> <new_pe_hostname>
       - Alternatively you can process a directory containing matching files
       - i.e. path/to/old/node_name.yaml and path/to/new/node_name.yaml
                   puppet catalog diff <path/to/old> <path/to/new>

      This code only validates the catalogs, it cannot tell you if the behavior of
      the providers that interpret the catalog has changed so testing is still
      recommended, this is just one tool to take away some of the uncertainty

    NOTES
    examples <<-'EOT'
      Compare host catalogs:

      $ puppet catalog diff host-2.6.yaml host-3.0.pson
      $ puppet catalog diff /tmp/old_catalogs_directory /tmp/new_catalogs_keys_directory
    EOT

    when_invoked do |old_pe_hostname, new_pe_hostname, options|
      require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'catalog-diff', 'differ.rb'))
      require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'catalog-diff', 'findcatalogs.rb'))
      Puppet.err('Add --debug for realtime output, add --render-as {json,yaml} for parsed output')

      nodes = {}

      # Create two directories for the catalogs
      old_catalogs_directory = Dir.mktmpdir("#{old_pe_hostname.tr('/', '_')}-")
      new_catalogs_keys_directory = Dir.mktmpdir("#{new_pe_hostname.tr('/', '_')}-")

      pull_output =
        Puppet::Face[:catalog, '0.0.1'].pull(
          old_pe_hostname, new_pe_hostname, old_catalogs_directory, new_catalogs_keys_directory, options[:fact_search],
          changed_depth: options[:changed_depth], threads: options[:threads], filter_local: options[:filter_local]
        )
      # diff_output = Puppet::Face[:catalog, '0.0.1'].diff(old_catalogs_directory, new_catalogs_keys_directory, options)

      # User passed us two directories full of pson
      found_catalogs = Puppet::CatalogDiff::FindCatalogs.new(old_catalogs_directory, new_catalogs_keys_directory).return_catalogs(options)
      new_catalogs_keys = found_catalogs.keys

      if HAS_PARALLEL_GEM
        results = Parallel.map(new_catalogs_keys) do |new_catalog|
          node_name    = File.basename(new_catalog, File.extname(new_catalog))
          old_catalog  = found_catalogs[new_catalog]
          node_summary = Puppet::CatalogDiff::Differ.new(old_catalog, new_catalog).diff(options)
          [node_name, node_summary]
        end
        nodes = Hash[results]
      else
        thread_count = 1
        mutex = Mutex.new

        Array.new(thread_count) {
          Thread.new(nodes, new_catalogs_keys, options) do |nodes, new_catalogs_keys, options|
            while new_catalog = mutex.synchronize { new_catalogs_keys.pop }
              node_name    = File.basename(new_catalog, File.extname(new_catalog))
              old_catalog  = found_catalogs[new_catalog]
              node_summary = Puppet::CatalogDiff::Differ.new(old_catalog, new_catalog).diff(options)
              mutex.synchronize { nodes[node_name] = node_summary }
            end
          end
        }.each(&:join)
      end

      nodes = diff_output

      FileUtils.rm_rf(old_catalogs_directory)
      FileUtils.rm_rf(new_catalogs_keys_directory)

      nodes[:pull_output] = pull_output

      # Save the file as it can take a while to create
      if options[:output_report]
        Puppet.notice("Writing report to disk: #{options[:output_report]}")
        File.open(options[:output_report], 'w') do |f|
          f.write(nodes.to_json)
        end
      end

      # diff_output = nodes

      with_changes = nodes.select { |_node, summary| summary.is_a?(Hash) && !summary[:node_percentage].zero? }
      most_changed = with_changes.sort_by { |_node, summary| summary[:node_percentage] }.map do |node, summary|
        Hash[node => summary[:node_percentage]]
      end

      most_differences = with_changes.sort_by { |_node, summary| summary[:node_differences] }.map do |node, summary|
        Hash[node => summary[:node_differences]]
      end
      total_nodes = nodes.size
      nodes[:total_percentage]   = (nodes.map { |_node, summary| summary.is_a?(Hash) && summary[:node_percentage] || nil }.compact.reduce { |sum, x| sum.to_f + x } / total_nodes)
      nodes[:with_changes]       = with_changes.size
      nodes[:most_changed]       = most_changed.reverse.take((options.key?(:changed_depth) && options[:changed_depth].to_i || 10))
      nodes[:most_differences]   = most_differences.reverse.take((options.key?(:changed_depth) && options[:changed_depth].to_i || 10))
      nodes[:total_nodes]        = total_nodes
      nodes[:date]               = Time.new.iso8601
      nodes
    end

    when_rendering :console do |nodes|
      require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'catalog-diff', 'formater.rb'))

      format = Puppet::CatalogDiff::Formater.new
      nodes.map { |node, summary|
        next if node == :total_percentage || node == :total_nodes || node == :most_changed || node == :with_changes || node == :most_differences || node == :pull_output || node == :date
        format.node_summary_header(node, summary, :node_percentage) + summary.map { |header, value|
                                                                        next if value.nil?
                                                                        if value.is_a?(Hash)
                                                                          value.map do |resource_id, resource|
                                                                            next if resource.nil?
                                                                            if resource.is_a?(Hash) && resource.key?(:type)
                                                                              # If we find an actual resource print it out
                                                                              format.resource_reference(header, resource_id, resource)
                                                                            elsif resource.is_a?(Array)
                                                                              next unless resource.any?
                                                                              # Format string diffs
                                                                              format.string_diff(header, resource_id, resource)
                                                                            else
                                                                              next if resource.nil?
                                                                              # Format hash diffs
                                                                              format.params_diff(header, resource_id, resource)
                                                                            end
                                                                          end
                                                                        elsif value.is_a?(Array)
                                                                          next if value.empty?
                                                                          # Format arrays
                                                                          format.list(header, value)
                                                                        else
                                                                          format.key_pair(header, value)
                                                                        end
                                                                      }.delete_if { |x| x.nil? || x == [] }.join("\n")
      }.join("\n") + "#{format.node_summary_header("#{nodes[:with_changes]} out of #{nodes[:total_nodes]} nodes changed.", nodes, :total_percentage)}\n#{format.list_hash('Nodes with the most changes by percent changed', nodes[:most_changed])}\n\n#{format.list_hash('Nodes with the most changes by differeces', nodes[:most_differences], '')}#{(nodes.key?(:pull_output) && format.render_pull(nodes[:pull_output]))}"
    end
  end
end
