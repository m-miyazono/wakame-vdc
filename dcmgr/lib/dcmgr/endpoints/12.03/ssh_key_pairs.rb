# -*- coding: utf-8 -*-

require 'dcmgr/endpoints/12.03/responses/ssh_key_pair'

Dcmgr::Endpoints::V1203::CoreAPI.namespace '/ssh_key_pairs' do
  get do
    ds = M::SshKeyPair.dataset
    if params[:account_id]
      ds = ds.filter(:account_id=>params[:account_id])
    end

    ds = datetime_range_params_filter(:created, ds)
    ds = datetime_range_params_filter(:deleted, ds)
    
    if params[:service_type]
      validate_service_type(params[:service_type])
      ds = ds.filter(:service_type=>params[:service_type])
    end
    
    if params[:display_name]
      ds = ds.filter(:display_name=>params[:display_name])
    end
    
    collection_respond_with(ds) do |paging_ds|
      R::SshKeyPairCollection.new(paging_ds).generate
    end
  end

  get '/:id' do
    # description "Retrieve details about ssh key pair"
    # params :id required
    # params :format optional [openssh,putty]
    ssh = find_by_uuid(:SshKeyPair, params[:id])
    raise UnknownSshKeyPair, parmas[:id] if ssh.nil?

    respond_with(R::SshKeyPair.new(ssh).generate)
  end

  quota 'ssh_key_pair.count'
  post do
    # description "Create ssh key pair information"
    # params :download_once optional set true if you do not want
    #        to save private key info on database.
    # params :display_name optional
    keydata = nil

    ssh = M::SshKeyPair.entry_new(@account) do |s|
      keydata = M::SshKeyPair.generate_key_pair(s.uuid)
      s.public_key = keydata[:public_key]
      s.finger_print = keydata[:finger_print]

      if params[:download_once] != 'true'
        s.private_key = keydata[:private_key]
      end

      if params[:description]
        s.description = params[:description]
      end

      if params[:service_type]
        validate_service_type(params[:service_type])
        s.service_type = params[:service_type]
      end

      if params[:display_name]
        s.display_name = params[:display_name]
      end
    end

    begin
      ssh.save
    rescue => e
      raise E::DatabaseError, e.message
    end

    respond_with(R::SshKeyPair.new(ssh, keydata[:private_key]).generate)
  end

  delete '/:id' do
    # description "Remove ssh key pair information"
    # params :id required
    ssh = find_by_uuid(:SshKeyPair, params[:id])
    ssh.destroy

    respond_with([ssh.canonical_uuid])
  end

  put '/:id' do
    # description "Update ssh key pair information"
    ssh = find_by_uuid(:SshKeyPair, params[:id])
    ssh.description = params[:description] if params[:description]
    if params[:service_type]
      validate_service_type(params[:service_type])
      ssh.service_type = params[:service_type]
    end
    ssh.display_name = params[:display_name] if params[:display_name]
    ssh.save_changes

    respond_with([ssh.canonical_uuid])
  end
end

