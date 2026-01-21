// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "contracts/IExecutableProposal.sol";

contract PropuestaEjemplo is IExecutableProposal {
    event PropuestaEjecutada(uint proposalId, uint numVotes, uint numTokens);
    
    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable override {
        emit PropuestaEjecutada(proposalId, numVotes, numTokens);
    }
     // Implementación de la función de la interfaz IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IExecutableProposal).interfaceId;
    }
}