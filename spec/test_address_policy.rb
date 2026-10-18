# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/minecraft_server/address_policy"

class AddressPolicyTest < Minitest::Test
  P = MinecraftServerDirectory::AddressPolicy

  def test_hostname_defaults_to_minecraft_port
    parsed = P.parse("play.example.com")
    assert_equal "play.example.com", parsed.host
    assert_equal 25_565, parsed.port
    assert_equal "play.example.com:25565", parsed.display
  end

  def test_explicit_port_and_ipv6
    parsed = P.parse("[2001:4860:4860::8888]:25566")
    assert_equal "2001:4860:4860::8888", parsed.host
    assert_equal 25_566, parsed.port
  end

  def test_rejects_schemes_and_paths
    assert_raises(P::InvalidAddress) { P.parse("https://example.com") }
    assert_raises(P::InvalidAddress) { P.parse("example.com/path") }
  end

  def test_rejects_bad_ports
    assert_raises(P::InvalidAddress) { P.parse("example.com:0") }
    assert_raises(P::InvalidAddress) { P.parse("example.com:65536") }
    assert_raises(P::InvalidAddress) { P.parse("example.com:abc") }
  end

  def test_blocks_private_reserved_and_multicast
    %w[
      127.0.0.1
      10.0.0.1
      172.16.0.1
      192.168.1.1
      169.254.1.1
      100.64.0.1
      224.0.0.1
      ::1
      fc00::1
      fe80::1
    ].each { |address| assert P.private_or_reserved?(address), "expected #{address} to be blocked" }
  end

  def test_allows_public_addresses
    refute P.private_or_reserved?("8.8.8.8")
    refute P.private_or_reserved?("1.1.1.1")
    refute P.private_or_reserved?("2606:4700:4700::1111")
  end

  def test_validate_uses_resolved_public_ip
    fake = Object.new
    def fake.getaddresses(_host) = ["93.184.216.34"]
    parsed = P.validate!("example.com", resolver: fake)
    assert_equal "93.184.216.34", parsed.connect_host
  end

  def test_validate_rejects_hostname_resolving_to_loopback
    fake = Object.new
    def fake.getaddresses(_host) = ["127.0.0.1"]
    assert_raises(P::BlockedAddress) { P.validate!("evil.example", resolver: fake) }
  end

  def test_validate_rejects_empty_dns
    fake = Object.new
    def fake.getaddresses(_host) = []
    assert_raises(P::InvalidAddress) { P.validate!("missing.example", resolver: fake) }
  end
end