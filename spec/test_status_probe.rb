# frozen_string_literal: true

require "json"
require "minitest/autorun"
require_relative "../lib/minecraft_server/status_probe"

class StatusProbeTest < Minitest::Test
  def setup
    @probe = MinecraftServerDirectory::StatusProbe.new("example.com", 25_565, 2)
  end

  def test_varint_encoding_matches_protocol_examples
    assert_equal [0x00].pack("C*"), @probe.send(:write_varint, 0)
    assert_equal [0x7f].pack("C*"), @probe.send(:write_varint, 127)
    assert_equal [0x80, 0x01].pack("C*"), @probe.send(:write_varint, 128)
    assert_equal [0xff, 0x01].pack("C*"), @probe.send(:write_varint, 255)
  end

  def test_varint_decoding
    value, offset = @probe.send(:read_varint_from, [0xac, 0x02].pack("C*"), 0)
    assert_equal 300, value
    assert_equal 2, offset
  end

  def test_flatten_chat_description
    node = { "text" => "Hello ", "extra" => ["world", { "text" => "!" }] }
    assert_equal "Hello world!", @probe.send(:flatten_chat, node)
  end

  def test_parse_status_normalizes_players_and_motd
    json = {
      version: { name: "1.21.4", protocol: 769 },
      players: { online: 7, max: 20 },
      description: { text: "Welcome ", extra: [{ text: "home" }] },
    }.to_json

    result = @probe.send(:parse_status, json, Process.clock_gettime(Process::CLOCK_MONOTONIC))
    assert result.online
    assert_equal "1.21.4", result.version_name
    assert_equal 7, result.players_online
    assert_equal 20, result.players_max
    assert_equal "Welcome home", result.motd
  end

  def test_parse_status_rejects_non_json
    assert_raises(MinecraftServerDirectory::StatusProbe::ProtocolError) do
      @probe.send(:parse_status, "not-json", Process.clock_gettime(Process::CLOCK_MONOTONIC))
    end
  end
end