# frozen_string_literal: true

require "ipaddr"
require "resolv"

module ::MinecraftServer
  # Validates the host/port a user wants probed. This is deliberately separate
  # from the socket code: the address rules are the security boundary, so they
  # need to be testable without making a network request.
  module AddressPolicy
    DEFAULT_PORT = 25_565
    MIN_PORT = 1
    MAX_PORT = 65_535
    MAX_HOST_LENGTH = 253
    MAX_ADDRESS_LENGTH = 320
    HOST_LABEL = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/i

    class Error < StandardError
    end

    class InvalidAddress < Error
    end

    class BlockedAddress < Error
    end

    Parsed = Struct.new(:host, :port, :display, :connect_host, keyword_init: true)

    module_function

    def parse(value)
      raw = value.to_s.strip
      raise InvalidAddress, "address is blank" if raw.empty?
      raise InvalidAddress, "address is too long" if raw.length > MAX_ADDRESS_LENGTH
      raise InvalidAddress, "only a bare host or host:port is accepted" if raw.include?("://")

      parse_host_port(raw)
    end

    def validate!(value, resolver: Resolv)
      parsed = parse(value)
      host = parsed.host

      if ip_literal?(host)
        ensure_public_ip!(host)
        parsed.connect_host = host
      else
        addresses = resolver.getaddresses(host)
        raise InvalidAddress, "host did not resolve" if addresses.empty?
        addresses.each { |address| ensure_public_ip!(address) }
        parsed.connect_host = addresses.first
      end

      parsed
    rescue Resolv::ResolvError, Resolv::ResolvTimeout => e
      raise InvalidAddress, "host did not resolve: #{e.message}"
    end

    def private_or_reserved?(address)
      ip = IPAddr.new(address.to_s)
      return true if ip.loopback? || ip.private? || ip.link_local?
      return true if ip.to_i.zero?

      if ip.ipv4?
        ranges = %w[
          0.0.0.0/8
          100.64.0.0/10
          169.254.0.0/16
          192.0.0.0/24
          192.0.2.0/24
          198.18.0.0/15
          198.51.100.0/24
          203.0.113.0/24
          224.0.0.0/4
          240.0.0.0/4
        ]
        ranges.any? { |range| IPAddr.new(range).include?(ip) }
      else
        ranges = %w[
          ::/128
          ::1/128
          ::ffff:0:0/96
          2001:db8::/32
          fc00::/7
          fe80::/10
          ff00::/8
        ]
        ranges.any? { |range| IPAddr.new(range).include?(ip) }
      end
    rescue IPAddr::InvalidAddressError
      true
    end

    def ensure_public_ip!(address)
      raise BlockedAddress, "private or reserved address" if private_or_reserved?(address)
      true
    end

    def ip_literal?(host)
      IPAddr.new(host)
      true
    rescue IPAddr::InvalidAddressError
      false
    end

    def parse_host_port(raw)
      if raw.start_with?("[")
        match = raw.match(/\A\[([^\]]+)\](?::(\d{1,5}))?\z/)
        raise InvalidAddress, "invalid IPv6 address" unless match
        host = match[1]
        port = match[2] || DEFAULT_PORT
      elsif raw.count(":") > 1
        host = raw
        port = DEFAULT_PORT
      else
        host, port = raw.split(":", 2)
        port ||= DEFAULT_PORT
      end

      build(host, port)
    end

    def build(host, port)
      normalized_host = host.to_s.strip.downcase.sub(/\.\z/, "")
      raise InvalidAddress, "host is blank" if normalized_host.empty?
      raise InvalidAddress, "host is too long" if normalized_host.length > MAX_HOST_LENGTH
      raise InvalidAddress, "invalid port" unless port.to_s.match?(/\A\d+\z/)
      numeric_port = port.to_i
      raise InvalidAddress, "port out of range" unless numeric_port.between?(MIN_PORT, MAX_PORT)

      unless ip_literal?(normalized_host) || normalized_host.split(".").all? { |label| label.match?(HOST_LABEL) }
        raise InvalidAddress, "invalid hostname"
      end

      display_host = ip_literal?(normalized_host) && normalized_host.include?(":") ? "[#{normalized_host}]" : normalized_host
      Parsed.new(host: normalized_host, port: numeric_port, display: "#{display_host}:#{numeric_port}")
    end
  end
end