# frozen_string_literal: true

module ::MinecraftServerDirectory
  # Domain operations used by controllers and jobs. Keeping them here makes the
  # controller small and lets the same code be exercised from the console.
  module ServerRegistry
    module_function

    def list
      Server.listed.order(online: :desc, players_online: :desc, created_at: :desc)
    end

    def mine(user)
      return Server.none if user.blank?
      Server.where(user_id: user.id).order(created_at: :desc)
    end

    def submit(user:, params:)
      now = Time.zone.now
      address = AddressPolicy.parse(params[:address])
      name = params[:name].to_s.strip
      description = params[:description].to_s.strip

      raise AddressPolicy::InvalidAddress, "name is blank" if name.blank?
      raise AddressPolicy::InvalidAddress, "name is too long" if name.length > 80
      if description.length > SiteSetting.minecraft_server_description_max_length.to_i
        raise AddressPolicy::InvalidAddress, "description is too long"
      end
      raise Discourse::InvalidAccess unless can_submit?(user)

      existing = Server.find_by("LOWER(host) = ? AND port = ?", address.host, address.port)
      if existing && existing.user_id != user.id
        raise AddressPolicy::InvalidAddress, "address is already registered"
      end

      if existing && existing.user_id == user.id && existing.status != "rejected"
        raise AddressPolicy::InvalidAddress, "you already submitted this address"
      end

      if !user.staff? && Server.where(user_id: user.id).where("last_submitted_at > ?", now - SiteSetting.minecraft_server_submission_cooldown_seconds.to_i.seconds).exists?
        raise AddressPolicy::InvalidAddress, "please wait before submitting again"
      end

      if !user.staff? && Server.where(user_id: user.id).count >= SiteSetting.minecraft_server_max_servers_per_user.to_i
        raise AddressPolicy::InvalidAddress, "server limit reached"
      end

      # Resolve only after cheap validations; this is the network boundary that
      # prevents a user from making Discourse probe loopback or RFC1918 hosts.
      AddressPolicy.validate!(address.display)

      status = auto_approve?(user) ? "approved" : "pending"
      record = existing || Server.new(user: user)
      record.assign_attributes(
        name: name,
        address: address.display,
        host: address.host,
        port: address.port,
        description: description,
        status: status,
        listed: status == "approved",
        approved_at: status == "approved" ? now : nil,
        last_submitted_at: now,
        checked_at: nil,
        online: false,
      )
      record.save!
      record
    rescue ActiveRecord::RecordInvalid => e
      raise AddressPolicy::InvalidAddress, e.record.errors.full_messages.first
    end

    def update(user:, server:, params:)
      raise Discourse::InvalidAccess unless server.can_edit?(user)

      address = AddressPolicy.parse(params[:address])
      name = params[:name].to_s.strip
      description = params[:description].to_s.strip

      raise AddressPolicy::InvalidAddress, "name is blank" if name.blank?
      raise AddressPolicy::InvalidAddress, "name is too long" if name.length > 80
      if description.length > SiteSetting.minecraft_server_description_max_length.to_i
        raise AddressPolicy::InvalidAddress, "description is too long"
      end

      AddressPolicy.validate!(address.display)
      duplicate = Server.where("LOWER(host) = ? AND port = ?", address.host, address.port).where.not(id: server.id).exists?
      raise AddressPolicy::InvalidAddress, "address is already registered" if duplicate

      status = if user.staff? || !SiteSetting.minecraft_server_require_approval
        server.status
      else
        "pending"
      end

      server.update!(
        name: name,
        address: address.display,
        host: address.host,
        port: address.port,
        description: description,
        status: status,
        listed: status == "approved",
        checked_at: nil,
      )
      server
    rescue ActiveRecord::RecordInvalid => e
      raise AddressPolicy::InvalidAddress, e.record.errors.full_messages.first
    end

    def approve!(server, actor)
      raise Discourse::InvalidAccess unless actor&.staff?
      server.update!(status: "approved", listed: true, approved_at: Time.zone.now)
      server
    end

    def reject!(server, actor)
      raise Discourse::InvalidAccess unless actor&.staff?
      server.update!(status: "rejected", listed: false)
      server
    end

    def hide!(server, actor)
      raise Discourse::InvalidAccess unless actor&.staff?
      server.update!(status: "hidden", listed: false)
      server
    end

    def refresh!(server, actor)
      raise Discourse::InvalidAccess unless server.can_edit?(actor)
      probe_one(server)
    end

    def probe_one(server)
      address = AddressPolicy.validate!(server.display_address)
      timeout = SiteSetting.minecraft_server_probe_timeout_seconds.to_i
      result = StatusProbe.query(
        address.host,
        port: address.port,
        timeout: timeout,
        connect_host: address.connect_host,
      )
      server.probe_result!(result)
      result
    rescue StandardError => e
      server.probe_failure!(e)
      nil
    end

    def auto_approve?(user)
      return true if user&.staff?
      SiteSetting.minecraft_server_auto_approve &&
        !SiteSetting.minecraft_server_require_approval
    end

    def can_submit?(user)
      return false if user.blank? || !SiteSetting.minecraft_server_allow_user_submissions
      return true if user.staff?
      user.has_trust_level?(SiteSetting.minecraft_server_min_trust_level.to_i)
    end
  end
end