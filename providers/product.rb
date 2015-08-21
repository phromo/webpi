#
# Author:: Seth Chisamore (<schisamo@chef.io>)
# Cookbook Name:: webpi
# Provider:: product
#
# Copyright:: 2011, Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/mixin/shell_out'

include Chef::Mixin::ShellOut
include Windows::Helper

action :install do
  check_installed

  unless @install_list.empty?
    cmd = "\"#{webpicmd}\" /Install"
    cmd << " /products:#{@install_list} /suppressreboot"
    cmd << " /accepteula" if @new_resource.accept_eula
    cmd << " /XML:#{node['webpi']['xmlpath']}" if node['webpi']['xmlpath']
    cmd << " /Log:#{node['webpi']['log']}"
    out = shell_out!(cmd, {:returns => [0,42,3010]})
    @new_resource.updated_by_last_action(true)
    Chef::Log.info("#{@new_resource} added new product '#{@install_list}'")
    if out.exitstatus == 3010
      # reboot required
      # see https://github.com/chef/chef/blob/master/lib/chef/provider/reboot.rb
      #     http://stackoverflow.com/questions/30535470/how-can-i-call-a-chef-resource-from-an-hwrp
      Chef::Log.warn "Rebooting system immediately, requested by '#{@new_resource.name}'"
      node.run_context.request_reboot(
          :delay_mins => 0,
          :reason => "WebPI installer requested reboot",
          :timestamp => Time.now,
          :requested_by => @new_resource.name
      )
      throw :end_client_run_early
    end
  else
    Chef::Log.debug("#{@new_resource} product already exists - nothing to do")
  end
end

private

#Method checks webpi to see what's installed.
#Then loops through each product, and if it's missing, adds it to a list to be installed
def check_installed
    @install_array = Array.new
    cmd = "\"#{webpicmd}\" /List /ListOption:Installed"
    cmd << " /XML:#{node['webpi']['xmlpath']}" if node['webpi']['xmlpath']
    cmd_out = shell_out(cmd, {:returns => [0,42]})
    unless cmd_out.stderr.empty?
      Chef::Log.Info(cmd_out.stderr)
      @install_array = @new_resource.product_id
    else
      @new_resource.product_id.split(",").each do |p|
        #Example output
        #HTTPErrors           IIS: HTTP Errors
        #Example output returned via grep
        #\r    \rHTTPErrors           IIS: HTTP Errors\r\ns
        if cmd_out.stdout.lines.grep(/^\s{6}#{p}\s.*$/i).empty?
          @install_array << p
        end
      end
    end
    @install_list = @install_array.join(",")
end

def webpicmd
  @webpicmd ||= begin
    node['webpi']['bin']
  end
end
