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

        whitelist[0] = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
        whitelist[1] = "0x7c6b4bbe207d642d98d5c537142d85209e585087";
        whitelist[2] = "0xe7f1725e7734ce288f8367e1bb143e90bb3f0512";
        whitelist[3] = "0x0000000000000000000000000000000000001337";

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
                string.concat(json, '"', vm.toString(i), '":{"0":"', whitelist[i], '","1":"', vm.toString(amount), '"}');
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
