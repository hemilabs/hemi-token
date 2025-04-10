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
    uint256 internal constant YEAR = 365.25 days;
    uint256 internal constant MAX_BPS = 10000;

    function setUp() public {
        // Deploy the Hemi contract with the owner address
        hemi = new Hemi(owner, owner, 700);
        vm.createSelectFork(vm.envString("FORK_NODE_URL"), vm.envUint("FORK_BLOCK_NUMBER"));
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
        hemi.enableEmissions(0);

        assertGt(hemi.lastEmission(), 0, "Emissions not enabled");
    }

    function testFirstEmissionAmount() public {
        vm.prank(owner);
        hemi.setupEmissions(l2Tunnel, l2Destination, remoteToken);
        uint256 _firstEmission = 1000e18;
        vm.prank(owner);
        hemi.enableEmissions(_firstEmission);
        uint256 _balanceOfTunnel = hemi.balanceOf(l2Tunnel);

        assertEq(_balanceOfTunnel, _firstEmission, "Emissions not enabled");
    }

    function testCalculateEmission() public {
        vm.prank(owner);
        hemi.setupEmissions(l2Tunnel, l2Destination, remoteToken);

        vm.prank(owner);
        hemi.enableEmissions(0);

        // Fast forward time by 1 year
        vm.warp(block.timestamp + YEAR);

        uint256 emissionAmount = hemi.calculateEmission();
        uint256 expectedEmission = (hemi.totalSupply() * hemi.annualInflationRate()) / MAX_BPS;
        assertEq(emissionAmount, expectedEmission, "Emission amount should be greater than zero");
    }

    function testEmission() public {
        vm.prank(owner);
        hemi.setupEmissions(l2Tunnel, l2Destination, remoteToken);

        vm.prank(owner);
        hemi.enableEmissions(0);

        // Fast forward time by 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 emissionAmount = hemi.calculateEmission();
        assertGt(emissionAmount, 0, "Emission amount should be greater than zero");

        vm.expectEmit(true, true, true, true);
        emit Hemi.EmissionsMinted(emissionAmount, block.timestamp);

        uint256 _totalSupplyBefore = hemi.totalSupply();
        vm.prank(owner);
        hemi.mintEmissions();
        uint256 _totalSupplyAfter = hemi.totalSupply();
        assertEq(
            _totalSupplyAfter,
            _totalSupplyBefore + emissionAmount,
            "Total supply should increase by the emission amount"
        );

        uint256 _balanceOfTunnel = hemi.balanceOf(l2Tunnel);
        assertEq(_balanceOfTunnel, emissionAmount, "Tunnel balance should be equal to the emission amount");

        emissionAmount = hemi.calculateEmission();
        assertEq(emissionAmount, 0, "Emission amount should be greater than zero");
    }

    function testRevertIfEmissionsAlreadyEnabled() public {
        vm.prank(owner);
        hemi.setupEmissions(l2Tunnel, l2Destination, remoteToken);

        vm.prank(owner);
        hemi.enableEmissions(0);

        vm.expectRevert(Hemi.EmissionsAlreadyEnabled.selector);
        vm.prank(owner);
        hemi.enableEmissions(0);
    }

    function testRevertIfEmissionNotSetup() public {
        vm.expectRevert(Hemi.EmissionNotSetup.selector);
        vm.prank(owner);
        hemi.enableEmissions(0);
    }

    function testRevertIfMintagePeriodNotElapsed() public {
        vm.prank(owner);
        hemi.setupEmissions(l2Tunnel, l2Destination, remoteToken);

        vm.prank(owner);
        hemi.enableEmissions(0);

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

    function testRevertIfInvalidAnnualInflationRate() public {
        uint256 _currentInflationRate = hemi.annualInflationRate();
        vm.expectRevert(Hemi.InvalidInflationRate.selector);
        vm.prank(owner);
        hemi.updateInflationRate(_currentInflationRate + 1);
    }

    function testDisableAllowInflationCut() public {
        vm.prank(owner);
        hemi.disableInflationCut();
        vm.expectRevert(Hemi.InflationCutNotAllowed.selector);
        vm.prank(owner);
        hemi.updateInflationRate(10);
    }

    function testInflationRateReduced() public {
        vm.prank(owner);
        hemi.updateInflationRate(10);
        uint256 _currentInflationRate = hemi.annualInflationRate();
        assertEq(_currentInflationRate, 10);
    }
}
