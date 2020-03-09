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

require "yast"
require "installation/instsys_packages"
require "y2packager/repository"

module Installation
  # This class does some self-update repository sanity checks to avoid
  # using a wrong self update repository (specified by user)
  class SelfupdateVerifier
    include Yast::Logger

    # We only check the version of these packages, the reason for a fixed
    # list is that these packages are maintained by us and their version
    # is under our control.
    #
    # We do not care about the other packages, in theory there might be
    # valid reasons for downgrading them. With these YaST packages we can
    # go back to the previous state but but still increase the version number.
    #
    # We can also check the "too new" packages because the YaST package versions
    # are bound to specific SP release (e.g. 4.1.x in SP1, 4.2.x in SP2).
    VERIFIED_PACKAGES = [
      "autoyast2-installation",
      "yast2",
      "yast2-installation",
      "yast2-packager",
      "yast2-pkg-bindings",
      "yast2-registration",
      "yast2-storage-ng",
      "yast2-update"
    ].freeze

    def initialize(repo_id, packages_file = "/.packages.root")
      @instsys_packages = InstsysPackages.read(packages_file).select do |p|
        VERIFIED_PACKAGES.include?(p.name)
      end

      # the selfupdate repo might provide the same package in several versions,
      # find the latest one

      # group the same packages together
      packages = {}

      Y2Packager::Repository.find(repo_id).packages.each do |p|
        next unless VERIFIED_PACKAGES.include?(p.name)

        if packages[p.name]
          packages[p.name] << p
        else
          packages[p.name] = [p]
        end
      end

      # for each package find the highest version
      @selfupdate_packages = packages.values.map do |pkgs|
        pkgs.max { |a, b| Yast::Pkg.CompareVersions(a.version, b.version) }
      end
    end

    # check for downgraded packages, e.g. using the SP1 updates in the SP2 installer
    def downgraded_packages
      filter_self_updates do |inst_sys_pkg, update_pkg|
        # -1 = "update_pkg" is older than "inst_sys_pkg" (0 = the same, 1 = newer)
        Yast::Pkg.CompareVersions(update_pkg.version, inst_sys_pkg.version) == -1
      end
    end

    # Check for too new packages, e.g. using the SP3 updates in the SP2 installer.
    #
    # As we use fixed versioning schema for the YaST packages which is bound to
    # a specific product version (e.g. 4.1.x in SP1, 4.2.x in SP2) and we always
    # bump only the patch version we can also possibly check for "too new" packages.
    def too_new_packages
      filter_self_updates do |inst_sys_pkg, update_pkg|
        inst_major, inst_minor = parse_version(inst_sys_pkg.version)
        update_major, update_minor = parse_version(update_pkg.version)

        # check major/minor version update
        update_major > inst_major || update_minor > inst_minor
      end
    end

  private

    def filter_self_updates(&block)
      selfupdate_packages.select do |s|
        pkg = instsys_package(s.name)
        # if not in inst-sys
        next false unless pkg

        block.call(pkg, s)
      end
    end

    # extract the major and minor version number from version string,
    # it also converts the string versions to integers
    # @return [Array<Integer>] A pair of major and minor version
    def parse_version(version)
      major, minor = /^(\d+)\.(\d+)\./.match(version)[1, 2]
      [major.to_i, minor.to_i]
    end

    def instsys_package(name)
      instsys_packages.find { |p| p.name == name }
    end

    attr_reader :instsys_packages, :selfupdate_packages
  end
end
