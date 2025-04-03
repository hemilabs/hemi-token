// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Hemi.sol";

contract HemiTest is Test {
    Hemi public hemi;
    address public owner = address(0x123);
    address public l2Destination = address(0x789);
    address public l2Tunnel = address(0x5eaa10F99e7e6D177eF9F74E519E319aa49f191e);
    address public remoteToken = address(0x234);

    function setUp() public {
        // Deploy the Hemi contract with the owner address
        hemi = new Hemi(owner, owner);
        vm.createSelectFork(vm.envString("FORK_NODE_URL"));
    }

    function testSetupEmissions() public {
        vm.prank(owner); // Simulate the owner calling the function
        hemi.setupEmissions(l2Tunnel, l2Destination, remoteToken);

        assertEq(hemi.l2Tunnel(), l2Tunnel, "L2 Tunnel address mismatch");
        assertEq(hemi.l2Destination(), l2Destination, "L2 Destination address mismatch");
    }

    function testEnableEmissions() public {
        vm.prank(owner);
        hemi.setupEmissions(l2Tunnel, l2Destination, remoteToken);

        vm.prank(owner);
        hemi.enableEmissions();

        assertGt(hemi.lastEmission(), 0, "Emissions not enabled");
    }

    function testCalculateEmission() public {
        vm.prank(owner);
        hemi.setupEmissions(l2Tunnel, l2Destination, remoteToken);

        vm.prank(owner);
        hemi.enableEmissions();

        // Fast forward time by 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 emissionAmount = hemi.calculateEmission();
        uint256 expectedEmission = (hemi.totalSupply() * hemi.ANNUAL_INFLATION_RATE() * 365 days) / (365 days * 10000);
        assertEq(emissionAmount, expectedEmission, "Emission amount should be greater than zero");
    }

    function testEmission() public {
        vm.prank(owner);
        hemi.setupEmissions(l2Tunnel, l2Destination, remoteToken);

        vm.prank(owner);
        hemi.enableEmissions();

        // Fast forward time by 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 emissionAmount = hemi.calculateEmission();
        assertGt(emissionAmount, 0, "Emission amount should be greater than zero");

        vm.expectEmit(true, true, true, true);
        emit Hemi.EmissionsMinted(emissionAmount, block.timestamp);

        vm.prank(owner);
        hemi.mintEmissions();
    }

    function testRevertIfEmissionsAlreadyEnabled() public {
        vm.prank(owner);
        hemi.setupEmissions(l2Tunnel, l2Destination, remoteToken);

        vm.prank(owner);
        hemi.enableEmissions();

        vm.expectRevert(Hemi.EmissionsAlreadyEnabled.selector);
        vm.prank(owner);
        hemi.enableEmissions();
    }

    function testRevertIfEmissionNotSetup() public {
        vm.expectRevert(Hemi.EmissionNotSetup.selector);
        vm.prank(owner);
        hemi.enableEmissions();
    }

    function testRevertIfMintagePeriodNotElapsed() public {
        vm.prank(owner);
        hemi.setupEmissions(l2Tunnel, l2Destination, remoteToken);

        vm.prank(owner);
        hemi.enableEmissions();

        // Fast forward time by less than 30 days
        vm.warp(block.timestamp + 15 days);

        vm.expectRevert(Hemi.MintagePeriodNotElapsed.selector);
        vm.prank(owner);
        hemi.mintEmissions();
    }

    function testRevertIfNullAddressInSetup() public {
        vm.expectRevert(Hemi.NullAddress.selector);
        vm.prank(owner);
        hemi.setupEmissions(address(0), l2Destination, remoteToken);

        vm.expectRevert(Hemi.NullAddress.selector);
        vm.prank(owner);
        hemi.setupEmissions(l2Tunnel, address(0), remoteToken);
    }
}