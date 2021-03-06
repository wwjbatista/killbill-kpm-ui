require 'kpm/client'

module KPM
  class NodesInfoController < EngineController

    def index
      @nodes_info = ::KillBillClient::Model::NodesInfo.nodes_info(options_for_klient)

      # For convenience, put pure OSGI bundles at the bottom
      @nodes_info.each do |node_info|
        next if node_info.plugins_info.nil?
        node_info.plugins_info.sort! do |a, b|
          if osgi_bundle?(a) && !osgi_bundle?(b)
            1
          elsif !osgi_bundle?(a) && osgi_bundle?(b)
            -1
          else
            a.plugin_name <=> b.plugin_name
          end
        end
      end

      @logs = ::Killbill::KPM::KPMClient.get_osgi_logs(options_for_klient).reverse

      respond_to do |format|
        format.html
        format.js
      end
    end

    def install_plugin
      command_properties = [
          build_node_command_property('forceDownload', params[:force_download] == '1')
      ]
      trigger_node_plugin_command('INSTALL_PLUGIN', command_properties)

      redirect_to :action => :index
    end

    def install_plugin_from_fs
      ::Killbill::KPM::KPMClient.install_plugin(params.require(:key),
                                                params.require(:version),
                                                params.require(:type),
                                                params.require(:plugin).original_filename,
                                                params.require(:plugin).read,
                                                options_for_klient)

      redirect_to :action => :index
    end

    def uninstall_plugin
      trigger_node_plugin_command('UNINSTALL_PLUGIN')
      head :ok
    end

    def start_plugin
      trigger_node_plugin_command('START_PLUGIN')
      head :ok
    end

    def stop_plugin
      trigger_node_plugin_command('STOP_PLUGIN')
      head :ok
    end

    def restart_plugin
      trigger_node_plugin_command('RESTART_PLUGIN')
      head :ok
    end

    private

    def trigger_node_plugin_command(command_type, command_properties=[])
      command_properties << build_node_command_property('pluginKey', params[:plugin_key])
      command_properties << build_node_command_property('pluginName', params[:plugin_name])
      command_properties << build_node_command_property('pluginVersion', params[:plugin_version])

      trigger_node_command(command_type, command_properties)
    end

    def trigger_node_command(command_type, command_properties=[])
      node_command = ::KillBillClient::Model::NodeCommandAttributes.new
      node_command.system_command_type = true
      node_command.node_command_type = command_type
      node_command.node_command_properties = command_properties

      # TODO Can we actually use node_name?
      local_node_only = false

      ::KillBillClient::Model::NodesInfo.trigger_node_command(node_command,
                                                              local_node_only,
                                                              options_for_klient[:username],
                                                              params[:reason],
                                                              params[:comment],
                                                              options_for_klient)
    end

    def build_node_command_property(key, value)
      property = ::KillBillClient::Model::NodeCommandPropertyAttributes.new
      property.key = key
      property.value = value
      property
    end

    def osgi_bundle?(plugin_info)
      plugin_info.version.blank? || plugin_info.plugin_name.starts_with?('org.apache.felix.') || plugin_info.plugin_name.starts_with?('org.kill-bill.billing.killbill-platform-')
    end
  end
end
