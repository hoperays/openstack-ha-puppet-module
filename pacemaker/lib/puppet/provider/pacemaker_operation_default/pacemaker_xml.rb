require_relative '../pacemaker_xml'

Puppet::Type.type(:pacemaker_operation_default).provide(:xml, parent: Puppet::Provider::PacemakerXML) do
  desc 'Specific operation_default for a rather specific type since I currently have no plan to
  abstract corosync/pacemaker vs. keepalived. This op_defaults will check the state
  of Corosync cluster configuration properties.'

  commands cibadmin: 'cibadmin'
  commands crm_attribute: 'crm_attribute'
  commands crm_node: 'crm_node'
  commands crm_resource: 'crm_resource'
  commands crm_attribute: 'crm_attribute'

  attr_accessor :property_hash
  attr_accessor :resource

  def self.instances
    debug 'Call: self.instances'
    wait_for_online 'pacemaker_operation_default'
    proxy_instance = new
    instances = []
    proxy_instance.operation_defaults.map do |title, data|
      parameters = {}
      debug "Prefetch: #{title}"
      parameters[:ensure] = :present
      parameters[:value] = data['value']
      parameters[:name] = title
      instance = new(parameters)
      instance.cib = proxy_instance.cib
      instances << instance
    end
    instances
  end

  def self.prefetch(catalog_instances)
    debug 'Call: self.prefetch'
    return unless pacemaker_options[:prefetch]
    discovered_instances = instances
    discovered_instances.each do |instance|
      next unless catalog_instances.key? instance.name
      catalog_instances[instance.name].provider = instance
    end
  end

  # @return [true,false]
  def exists?
    debug 'Call: exists?'
    wait_for_online 'pacemaker_operation_default'
    return property_hash[:ensure] == :present if property_hash[:ensure]
    out = operation_default_defined? resource[:name]
    debug "Return: #{out}"
    out
  end

  def create
    debug 'Call: create'
    self.value = resource[:value]
  end

  def destroy
    debug 'Call: destroy'
    operation_default_delete resource[:name]
  end

  def value
    debug 'Call: value'
    return property_hash[:value] if property_hash[:value]
    out = operation_default_value resource[:name]
    debug "Return: #{out}"
    out
  end

  def value=(should)
    debug "Call: value=#{should}"
    operation_default_set resource[:name], should
  end
end
