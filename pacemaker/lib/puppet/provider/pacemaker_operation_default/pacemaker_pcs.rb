require_relative '../pacemaker_pcs'

Puppet::Type.type(:pacemaker_operation_default).provide(:pcs, parent: Puppet::Provider::PacemakerPCS) do
  desc 'Manages default values for pacemaker operation options via pcs'

  commands pcs: 'pcs'

  # disable this provider
  confine(true: false)

  def self.instances
    debug 'Call: self.instances'
    proxy_instance = new
    instances = []
    proxy_instance.pcs_operation_defaults.map do |title, value|
      parameters = {}
      debug "Prefetch: #{title}"
      parameters[:ensure] = :present
      parameters[:value] = value
      parameters[:name] = title
      instance = new(parameters)
      instances << instance
    end
    instances
  end

  def create
    debug 'Call: create'
    self.value = @resource[:value]
  end

  def destroy
    debug 'Call: destroy'
    pcs_operation_default_delete @resource[:name]
  end

  def exists?
    debug 'Call: exists?'
    pcs_operation_default_defined? @resource[:name]
  end

  def value
    debug 'Call: value'
    pcs_operation_default_value @resource[:name]
  end

  def value=(value)
    debug "Call: value=#{value}"
    pcs_operation_default_set @resource[:name], value
  end
end
