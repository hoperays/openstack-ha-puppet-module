require_relative '../pacemaker_noop'

Puppet::Type.type(:pacemaker_resource).provide(:noop, parent: Puppet::Provider::PacemakerNoop) do
  # disable this provider
  confine(true: false)
end
