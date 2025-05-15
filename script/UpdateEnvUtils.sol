// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";

library EnvUtils {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function updateEnvVariable(string memory variableName, address value) internal {
        string memory envPath = ".env";
        string memory addressString = vm.toString(value);
        string memory targetVar = string.concat(variableName, "=");
        
        // Check if file exists
        if (!vm.exists(envPath)) {
            console.log(".env file not found");
            return;
        }
        
        // Read the entire file
        string memory content = vm.readFile(envPath);
        string[] memory lines = splitLines(content);
        
        // Process lines and make updates
        string memory newContent = "";
        bool found = false;
        
        for (uint i = 0; i < lines.length; i++) {
            string memory currentLine = lines[i];
            
            // Check if this is the line we want to replace
            if (startsWith(currentLine, targetVar)) {
                currentLine = string.concat(targetVar, addressString);
                found = true;
            }
            
            // Add line to new content
            if (i > 0) {
                newContent = string.concat(newContent, "\n");
            }
            newContent = string.concat(newContent, currentLine);
        }
        
        // If not found, append it
        if (!found) {
            newContent = string.concat(newContent, "\n", targetVar, addressString);
        }
        
        // Write back to file
        vm.writeFile(envPath, newContent);
        console.log("Updated .env file with new", variableName, ":", addressString);
    }
    
    // Helper function to split a string by newlines
    function splitLines(string memory _content) internal pure returns (string[] memory) {
        bytes memory content = bytes(_content);
        
        // Count the number of lines
        uint lineCount = 1;
        for (uint i = 0; i < content.length; i++) {
            if (content[i] == bytes1("\n")) {
                lineCount++;
            }
        }
        
        // Split the content
        string[] memory lines = new string[](lineCount);
        uint lineStart = 0;
        uint currentLine = 0;
        
        for (uint i = 0; i < content.length; i++) {
            if (content[i] == bytes1("\n") || i == content.length - 1) {
                uint lineEnd = i;
                if (i == content.length - 1 && content[i] != bytes1("\n")) {
                    lineEnd = i + 1;
                }
                
                // Extract line
                bytes memory line = new bytes(lineEnd - lineStart);
                for (uint j = lineStart; j < lineEnd; j++) {
                    line[j - lineStart] = content[j];
                }
                
                lines[currentLine] = string(line);
                currentLine++;
                lineStart = i + 1;
            }
        }
        
        return lines;
    }
    
    // Helper function to check if a string starts with a prefix
    function startsWith(string memory _str, string memory _prefix) internal pure returns (bool) {
        bytes memory str = bytes(_str);
        bytes memory prefix = bytes(_prefix);
        
        if (str.length < prefix.length) {
            return false;
        }
        
        for (uint i = 0; i < prefix.length; i++) {
            if (str[i] != prefix[i]) {
                return false;
            }
        }
        
        return true;
    }
}
