// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/Escrow.sol";
import "../contracts/VehicleRegistry.sol";
import "../contracts/VehicleSaleCore.sol";


contract DeployProtocol is Script {
  function run() external {
    uint256 deployerKey = vm.envUint("PRIVATE_KEY");

    address protocolTreasury = vm.envAddress("PROTOCOL_TREASURY");
    uint16  protocolBps      = uint16(vm.envUint("PROTOCOL_BPS")); // for example 30 (0.3%)

    vm.startBroadcast(deployerKey);

    Escrow escrow = new Escrow();
    VehicleRegistry registry = new VehicleRegistry("KEY Vehicle Registry", "KEYVEH");
    VehicleSaleCore saleCore = new VehicleSaleCore(address(escrow), protocolTreasury, protocolBps);

    // wire core to escrow
    escrow.setCore(address(saleCore), true);

    vm.stopBroadcast();

    registry;
  }
}