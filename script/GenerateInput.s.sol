// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract GenerateInput is Script {
    uint256 amount = 25 * 1e18; // 25 tokens with 18 decimals
    string[] types = new string[](2);
    uint256 count;
    string[] whitelist = new string[](4);
    string inputPath = "/script/target/input.json";

    function run() public {
        // Define types and whitelist
        types[0] = "address";
        types[1] = "uint";

        whitelist[0] = "0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D";
        whitelist[1] = "0x29E3b139f4393aDda86303fcdAa35F60Bb7092bF";
        whitelist[2] = "0x537C8f3d3E18dF5517a58B3fB9D9143697996802";
        whitelist[3] = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

        count = whitelist.length;

        string memory json = _createJSON();

        // Write to file
        vm.writeFile(string.concat(vm.projectRoot(), inputPath), json);
        console.log("DONE: JSON written to %s", inputPath);
    }

    function _createJSON() internal view returns (string memory) {
        string memory json = "{";
        json = string.concat(json, '"types":', _arrayToJson(types), ",");
        json = string.concat(json, '"count":', vm.toString(count), ",");
        json = string.concat(json, '"values":{');

        for (uint256 i = 0; i < count; i++) {
            json =
                string.concat(json, '"', vm.toString(i), '":{"0":"', whitelist[i], '","1":', vm.toString(amount), "}");
            if (i < count - 1) {
                json = string.concat(json, ",");
            }
        }

        json = string.concat(json, "}}");
        return json;
    }

    function _arrayToJson(string[] memory arr) internal pure returns (string memory) {
        string memory json = "[";
        for (uint256 i = 0; i < arr.length; i++) {
            json = string.concat(json, '"', arr[i], '"');
            if (i < arr.length - 1) {
                json = string.concat(json, ",");
            }
        }
        json = string.concat(json, "]");
        return json;
    }
}
