// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IExecutableProposal is IERC165 {
    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable;
 }
