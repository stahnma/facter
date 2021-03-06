#!/usr/bin/env rspec

require 'spec_helper'
require 'facter/util/virtual'

describe Facter::Util::Virtual do

  after do
    Facter.clear
  end
  it "should detect openvz" do
    FileTest.stubs(:directory?).with("/proc/vz").returns(true)
    Dir.stubs(:glob).with("/proc/vz/*").returns(['vzquota'])
    Facter::Util::Virtual.should be_openvz
  end

  it "should not detect openvz when /proc/lve/list is present" do
    FileTest.stubs(:file?).with("/proc/lve/list").returns(true)
    Facter::Util::Virtual.should_not be_openvz
  end

  it "should not detect openvz when /proc/vz/ is empty" do
    FileTest.stubs(:file?).with("/proc/lve/list").returns(false)
    FileTest.stubs(:directory?).with("/proc/vz").returns(true)
    Dir.stubs(:glob).with("/proc/vz/*").returns([])
    Facter::Util::Virtual.should_not be_openvz
  end

  it "should identify openvzhn when /proc/self/status has envID of 0" do
    Facter::Util::Virtual.stubs(:openvz?).returns(true)
    FileTest.stubs(:exists?).with("/proc/self/status").returns(true)
    Facter::Util::Resolution.stubs(:exec).with('grep "envID" /proc/self/status').returns("envID:  0")
    Facter::Util::Virtual.openvz_type().should == "openvzhn"
  end

  it "should identify openvzve when /proc/self/status has envID of 0" do
    Facter::Util::Virtual.stubs(:openvz?).returns(true)
    FileTest.stubs(:exists?).with('/proc/self/status').returns(true)
    Facter::Util::Resolution.stubs(:exec).with('grep "envID" /proc/self/status').returns("envID:  666")
    Facter::Util::Virtual.openvz_type().should == "openvzve"
  end

  it "should not attempt to identify openvz when /proc/self/status has no envID" do
    Facter::Util::Virtual.stubs(:openvz?).returns(true)
    FileTest.stubs(:exists?).with('/proc/self/status').returns(true)
    Facter::Util::Resolution.stubs(:exec).with('grep "envID" /proc/self/status').returns("")
    Facter::Util::Virtual.openvz_type().should be_nil
  end

  it "should identify Solaris zones when non-global zone" do
    Facter::Util::Resolution.stubs(:exec).with("/sbin/zonename").returns("somezone")
    Facter::Util::Virtual.should be_zone
  end

  it "should not identify Solaris zones when global zone" do
    Facter::Util::Resolution.stubs(:exec).with("/sbin/zonename").returns("global")
    Facter::Util::Virtual.should_not be_zone
  end

  it "should not detect vserver if no self status" do
    FileTest.stubs(:exists?).with("/proc/self/status").returns(false)
    Facter::Util::Virtual.should_not be_vserver
  end

  it "should detect vserver when vxid present in process status" do
    FileTest.stubs(:exists?).with("/proc/self/status").returns(true)
    File.stubs(:read).with("/proc/self/status").returns("VxID: 42\n")
    Facter::Util::Virtual.should be_vserver
  end

  it "should detect vserver when s_context present in process status" do
    FileTest.stubs(:exists?).with("/proc/self/status").returns(true)
    File.stubs(:read).with("/proc/self/status").returns("s_context: 42\n")
    Facter::Util::Virtual.should be_vserver
  end

  it "should not detect vserver when vserver flags not present in process status" do
    FileTest.stubs(:exists?).with("/proc/self/status").returns(true)
    File.stubs(:read).with("/proc/self/status").returns("wibble: 42\n")
    Facter::Util::Virtual.should_not be_vserver
  end

  fixture_path = fixtures('virtual', 'proc_self_status')

  test_cases = [
    [File.join(fixture_path, 'vserver_2_1', 'guest'), true, 'vserver 2.1 guest'],
    [File.join(fixture_path, 'vserver_2_1', 'host'),  true, 'vserver 2.1 host'],
    [File.join(fixture_path, 'vserver_2_3', 'guest'), true, 'vserver 2.3 guest'],
    [File.join(fixture_path, 'vserver_2_3', 'host'),  true, 'vserver 2.3 host']
  ]

  test_cases.each do |status_file, expected, description|
    describe "with /proc/self/status from #{description}" do
      it "should detect vserver as #{expected.inspect}" do
        status = File.read(status_file)
        FileTest.stubs(:exists?).with("/proc/self/status").returns(true)
        File.stubs(:read).with("/proc/self/status").returns(status)
        Facter::Util::Virtual.vserver?.should == expected
      end
    end
  end

  it "should identify vserver_host when /proc/virtual exists" do
    Facter::Util::Virtual.expects(:vserver?).returns(true)
    FileTest.stubs(:exists?).with("/proc/virtual").returns(true)
    Facter::Util::Virtual.vserver_type().should == "vserver_host"
  end

  it "should identify vserver_type as vserver when /proc/virtual does not exist" do
    Facter::Util::Virtual.expects(:vserver?).returns(true)
    FileTest.stubs(:exists?).with("/proc/virtual").returns(false)
    Facter::Util::Virtual.vserver_type().should == "vserver"
  end

  it "should detect xen when /proc/sys/xen exists" do
    FileTest.expects(:exists?).with("/proc/sys/xen").returns(true)
    Facter::Util::Virtual.should be_xen
  end

  it "should detect xen when /sys/bus/xen exists" do
    FileTest.expects(:exists?).with("/proc/sys/xen").returns(false)
    FileTest.expects(:exists?).with("/sys/bus/xen").returns(true)
    Facter::Util::Virtual.should be_xen
  end

  it "should detect xen when /proc/xen exists" do
    FileTest.expects(:exists?).with("/proc/sys/xen").returns(false)
    FileTest.expects(:exists?).with("/sys/bus/xen").returns(false)
    FileTest.expects(:exists?).with("/proc/xen").returns(true)
    Facter::Util::Virtual.should be_xen
  end

  it "should not detect xen when no sysfs/proc xen directories exist" do
    FileTest.expects(:exists?).with("/proc/sys/xen").returns(false)
    FileTest.expects(:exists?).with("/sys/bus/xen").returns(false)
    FileTest.expects(:exists?).with("/proc/xen").returns(false)
    Facter::Util::Virtual.should_not be_xen
  end

  it "should detect kvm" do
    FileTest.stubs(:exists?).with("/proc/cpuinfo").returns(true)
    File.stubs(:read).with("/proc/cpuinfo").returns("model name : QEMU Virtual CPU version 0.9.1\n")
    Facter::Util::Virtual.should be_kvm
  end

  it "should detect kvm on FreeBSD" do
    FileTest.stubs(:exists?).with("/proc/cpuinfo").returns(false)
    Facter.fact(:kernel).stubs(:value).returns("FreeBSD")
    Facter::Util::Resolution.stubs(:exec).with("/sbin/sysctl -n hw.model").returns("QEMU Virtual CPU version 0.12.4")
    Facter::Util::Virtual.should be_kvm
  end

  it "should detect kvm on OpenBSD" do
    FileTest.stubs(:exists?).with("/proc/cpuinfo").returns(false)
    Facter.fact(:kernel).stubs(:value).returns("OpenBSD")
    Facter::Util::Resolution.stubs(:exec).with("/sbin/sysctl -n hw.model").returns('QEMU Virtual CPU version (cpu64-rhel6) ("AuthenticAMD" 686-class, 512KB L2 cache)')
    Facter::Util::Virtual.should be_kvm
  end

  it "should identify FreeBSD jail when in jail" do
    Facter.fact(:kernel).stubs(:value).returns("FreeBSD")
    Facter::Util::Resolution.stubs(:exec).with("/sbin/sysctl -n security.jail.jailed").returns("1")
    Facter::Util::Virtual.should be_jail
  end

  it "should not identify GNU/kFreeBSD jail when not in jail" do
    Facter.fact(:kernel).stubs(:value).returns("GNU/kFreeBSD")
    Facter::Util::Resolution.stubs(:exec).with("/bin/sysctl -n security.jail.jailed").returns("0")
    Facter::Util::Virtual.should_not be_jail
  end

  it "should detect hpvm on HP-UX" do
    Facter.fact(:kernel).stubs(:value).returns("HP-UX")
    Facter::Util::Resolution.stubs(:exec).with("/usr/bin/getconf MACHINE_MODEL").returns('ia64 hp server Integrity Virtual Machine')
    Facter::Util::Virtual.should be_hpvm
  end

  it "should not detect hpvm on HP-UX when not in hpvm" do
    Facter.fact(:kernel).stubs(:value).returns("HP-UX")
    Facter::Util::Resolution.stubs(:exec).with("/usr/bin/getconf MACHINE_MODEL").returns('ia64 hp server rx660')
    Facter::Util::Virtual.should_not be_hpvm
  end

  it "should be able to detect virtualbox via sysfs on Linux" do
    # Fake files are always hard to stub. :/
    File.stubs(:read).with("/sys/devices/virtual/dmi/id/product_name").
      returns("VirtualBox")

    Facter::Util::Virtual.should be_virtualbox
  end

  it "should be able to detect virtualbox via sysfs on Linux improperly" do
    # Fake files are always hard to stub. :/
    File.stubs(:read).with("/sys/devices/virtual/dmi/id/product_name").
      returns("HP-Oracle-Sun-VMWare-funky-town")

    Facter::Util::Virtual.should_not be_virtualbox
  end
end
