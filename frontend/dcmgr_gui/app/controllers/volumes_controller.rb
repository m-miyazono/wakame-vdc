class VolumesController < ApplicationController
  respond_to :json
  include Util
  
  def index
  end
  
  def create
    backup_object_ids = params[:ids]
    display_name = params[:display_name]
    if backup_object_ids
      res = []
      backup_object_ids.each do |backup_object_id|
        data = {
          :backup_object_id => backup_object_id,
          :display_name => display_name
        }
        res << Hijiki::DcmgrResource::Volume.create(data)
      end
      render :json => res
    else
      # Convert to MB
      size = case params[:unit]
             when 'gb'
               params[:size].to_i * 1024
             when 'tb'
               params[:size].to_i * 1024 * 1024
             end
      
      data = {
        :volume_size => size,
        :display_name => display_name
      }
      
      @volume = Hijiki::DcmgrResource::Volume.create(data)

      render :json => @volume
    end
  end
  
  def destroy
    volume_ids = params[:ids]
    res = []
    volume_ids.each do |volume_id|
      res << Hijiki::DcmgrResource::Volume.destroy(volume_id)
    end
    render :json => res
  end
  
  def list
    data = {
      :start => params[:start].to_i - 1,
      :limit => params[:limit]
    }
    volumes = Hijiki::DcmgrResource::Volume.list(data)
    respond_with(volumes[0],:to => [:json])
  end
  
  # GET volumes/vol-24f1af4d.json
  def show
    volume_id = params[:id]
    detail = Hijiki::DcmgrResource::Volume.show(volume_id)
    respond_with(detail,:to => [:json])
  end

  def update
    volume_id = params[:id]
    data = {
      :display_name => params[:display_name]
    }
    volume = Hijiki::DcmgrResource::Volume.update(volume_id,data)
    render :json => volume
  end

  def attach
    instance_id = params[:instance_id]
    volume_ids = params[:volume_ids]
    res = []
    volume_ids.each do |volume_id|
      data = {
        :volume_id => volume_id
      }
      res << Hijiki::DcmgrResource::Volume.attach(volume_id, instance_id)
    end
    render :json => res
  end

  def detach
    volume_ids = params[:ids]
    res = []
    volume_ids.each do |volume_id|
      res << Hijiki::DcmgrResource::Volume.detach(volume_id)
    end
    render :json => res
  end
  
  def total
    all_resource_count = Hijiki::DcmgrResource::Volume.total_resource
    all_resources = Hijiki::DcmgrResource::Volume.find(:all,:params => {:start => 0, :limit => all_resource_count})
    resources = all_resources[0].results
    deleted_resource_count = Hijiki::DcmgrResource::Volume.get_resource_state_count(resources, 'deleted')
    total = all_resource_count - deleted_resource_count
    render :json => total
  end

  def backup
    destination = params[:destination]
    display_name = params[:display_name]
    res = (params[:ids] || []).map do |volume_id|
      Hijiki::DcmgrResource::Volume.backup(volume_id, {:display_name=>display_name, :destination=>destination})
    end
    render :json => res
  end
end
