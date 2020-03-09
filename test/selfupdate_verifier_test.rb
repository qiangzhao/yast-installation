#!/usr/bin/env rspec
# ------------------------------------------------------------------------------
# Copyright (c) 2020 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require_relative "test_helper"

require "installation/selfupdate_verifier"

describe Installation::SelfupdateVerifier do
  let(:test_file) { File.join(FIXTURES_DIR, "inst-sys", "packages.root") }
  let(:repo_id) { 42 }
  let(:repo) do
    Y2Packager::Repository.new(repo_id: repo_id, repo_alias: "alias",
    name: "name", url: "http://example.com", enabled: true, autorefresh: true)
  end

  # this one is downgraded
  let(:downgraded_pkg) { Y2Packager::Package.new("yast2", repo_id, "4.1.7-1.2") }
  # downgraded non-YaST package
  let(:downgraded_nony2_pkg) { Y2Packager::Package.new("rpm", repo_id, "3.1.2-1.2") }
  # this one is upgraded a bit
  let(:upgraded_pkg) { Y2Packager::Package.new("yast2-installation", repo_id, "4.2.37-1.1") }
  # this one is upgraded too much
  let(:too_new) { Y2Packager::Package.new("yast2-packager", repo_id, "4.3.11-1.3") }

  subject { Installation::SelfupdateVerifier.new(repo_id, test_file) }

  before do
    expect(Y2Packager::Repository).to receive(:find).with(repo_id).and_return(repo)
    expect(repo).to receive(:packages).and_return(
      [downgraded_pkg, upgraded_pkg, too_new, downgraded_nony2_pkg]
    )
  end

  describe "#downgraded_packages" do
    it "returns the downgraded packages" do
      expect(subject.downgraded_packages).to eq([downgraded_pkg])
    end
  end

  describe "#too_new_packages" do
    it "returns the too new packages" do
      expect(subject.too_new_packages).to eq([too_new])
    end
  end

end
