# frozen_string_literal: true

module ::MinecraftServerDirectory
  class Server < ::ActiveRecord::Base
    self.table_name = "minecraft_servers"

    STATUSES = %w[pending approved rejected hidden].freeze
    LISTED_STATUSES = %w[approved].freeze

    belongs_to :user

    validates :user_id, presence: true
    validates :name, presence: true, length: { maximum: 80 }
    validates :address, presence: true, length: { maximum: 320 }
    validates :host, presence: true, length: { maximum: 253 }
    validates :port, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 65_535 }
    validates :description, length: { maximum: 1000 }
    validates :status, inclusion: { in: STATUSES }
    validates :host, uniqueness: { scope: :port, case_sensitive: false }

    scope :listed, -> { where(listed: true, status: "approved") }
    scope :due_for_probe, ->(before_time) do
      where(status: "approved").where("checked_at IS NULL OR checked_at < ?", before_time)
    end

    def display_address
      address.presence || "#{host}:#{port}"
    end

    def approved?
      status == "approved"
    end

    def public?
      approved? && listed?
    end

    def can_edit?(acting_user)
      return false if acting_user.blank?
      return true if acting_user.admin?
      user_id == acting_user.id && !%w[hidden rejected].include?(status)
    end

    def probe_result!(result)
      now = result.checked_at || Time.zone.now
      update!(
        online: result.online,
        version_name: result.version_name,
        players_online: result.players_online,
        players_max: result.players_max,
        motd: result.motd,
        favicon: result.favicon,
        latency_ms: result.latency_ms,
        checked_at: now,
        last_error: nil,
      )
    end

    def probe_failure!(error)
      update!(online: false, checked_at: Time.zone.now, last_error: error.to_s.first(500))
    end
  end
end