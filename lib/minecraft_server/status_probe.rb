# frozen_string_literal: true

require "json"
require "socket"
require "timeout"

module ::MinecraftServerDirectory
  # Minimal Minecraft Java Edition Server List Ping (SLP) implementation.
  #
  # The protocol is length-prefixed: [VarInt length][packet id][fields]. We only
  # need the status handshake and status request, then decode the JSON response.
  # A fixed body cap prevents a malicious server from making the forum allocate
  # an unbounded response.
  class StatusProbe
    PROTOCOL_VERSION = 767
    MAX_PACKET_BYTES = 1024 * 1024
    MAX_ICON_BYTES = 256 * 1024

    class Error < StandardError
    end

    class TimeoutError < Error
    end

    class ProtocolError < Error
    end

    Result = Struct.new(
      :online,
      :version_name,
      :protocol,
      :players_online,
      :players_max,
      :motd,
      :favicon,
      :latency_ms,
      :checked_at,
      keyword_init: true,
    )

    def self.query(host, port:, timeout: 5, connect_host: nil)
      new(host, port, timeout, connect_host: connect_host).query
    end

    def initialize(host, port, timeout, connect_host: nil)
      @host = host
      @connect_host = connect_host
      @port = port.to_i
      @timeout = [[timeout.to_i, 2].max, 15].min
    end

    def query
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      socket = nil

      Timeout.timeout(@timeout, TimeoutError) do
        socket = Socket.tcp(@connect_host || @host, @port, connect_timeout: @timeout)
        socket.write(packet(0x00, handshake_payload))
        socket.write(packet(0x00, ""))
        length = read_varint(socket)
        raise ProtocolError, "packet too large" if length <= 0 || length > MAX_PACKET_BYTES

        body = read_exact(socket, length)
        packet_id, offset = read_varint_from(body, 0)
        raise ProtocolError, "unexpected packet id" unless packet_id == 0x00

        json_length, offset = read_varint_from(body, offset)
        raise ProtocolError, "invalid status length" if json_length <= 0 || offset + json_length > body.bytesize

        json = body.byteslice(offset, json_length).force_encoding(Encoding::UTF_8)
        parse_status(json, started)
      end
    rescue Timeout::Error, Errno::ETIMEDOUT, TimeoutError
      raise TimeoutError, "probe timed out"
    rescue SystemCallError, SocketError => e
      raise Error, e.message
    ensure
      socket&.close
    end

    private

    def handshake_payload
      payload = +""
      payload << write_varint(PROTOCOL_VERSION)
      payload << write_string(@host)
      payload << [@port].pack("n")
      payload << write_varint(1)
      payload
    end

    def parse_status(json, started)
      data = JSON.parse(json)
      raise ProtocolError, "status is not an object" unless data.is_a?(Hash)

      players = data["players"].is_a?(Hash) ? data["players"] : {}
      version = data["version"].is_a?(Hash) ? data["version"] : {}
      description = data["description"]
      motd = description.is_a?(String) ? description : flatten_chat(description)
      favicon = data["favicon"].to_s
      favicon = nil if favicon.bytesize > MAX_ICON_BYTES

      version_name = version["name"].to_s.strip
      version_name = nil if version_name.empty?
      favicon = nil if favicon.empty?
      motd = motd.to_s.strip[0, 300].to_s

      Result.new(
        online: true,
        version_name: version_name,
        protocol: version["protocol"].to_i,
        players_online: [players["online"].to_i, 0].max,
        players_max: [players["max"].to_i, 0].max,
        motd: motd.empty? ? nil : motd,
        favicon: favicon,
        latency_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round,
        checked_at: Time.now.utc,
      )
    rescue JSON::ParserError
      raise ProtocolError, "status is not valid JSON"
    end

    def flatten_chat(node)
      return "" if node.nil?
      return node.to_s if node.is_a?(String)
      return node.map { |child| flatten_chat(child) }.join if node.is_a?(Array)
      return "" unless node.is_a?(Hash)

      text = node["text"].to_s
      text + flatten_chat(node["extra"])
    end

    def packet(id, payload)
      body = write_varint(id) + payload
      write_varint(body.bytesize) + body
    end

    def write_string(value)
      bytes = value.to_s.encode(Encoding::UTF_8)
      write_varint(bytes.bytesize) + bytes
    end

    def write_varint(value)
      value = value.to_i
      out = +""
      loop do
        byte = value & 0x7f
        value >>= 7
        if value.zero?
          out << byte.chr
          break
        end
        out << (byte | 0x80).chr
      end
      out
    end

    def read_varint(io)
      value = 0
      5.times do |index|
        byte = io.read(1)
        raise ProtocolError, "connection closed" if byte.nil? || byte.empty?
        current = byte.ord
        value |= (current & 0x7f) << (7 * index)
        return value if (current & 0x80).zero?
      end
      raise ProtocolError, "varint is too long"
    end

    def read_varint_from(bytes, offset)
      value = 0
      5.times do |index|
        raise ProtocolError, "truncated varint" if offset >= bytes.bytesize
        current = bytes.getbyte(offset)
        offset += 1
        value |= (current & 0x7f) << (7 * index)
        return [value, offset] if (current & 0x80).zero?
      end
      raise ProtocolError, "varint is too long"
    end

    def read_exact(io, length)
      buffer = +""
      while buffer.bytesize < length
        chunk = io.read(length - buffer.bytesize)
        raise ProtocolError, "connection closed" if chunk.nil? || chunk.empty?
        buffer << chunk
      end
      buffer
    end
  end
end