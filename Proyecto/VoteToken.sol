// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;




import "@openzeppelin/contracts/token/ERC20/ERC20.sol";




contract VoteToken is ERC20{
    address public admin;




    constructor(address contrato, string memory nombre, string memory simbolo) ERC20(nombre,simbolo){
        admin=contrato; //el admin es el contrato
    }
   
    modifier onlyAdmin() {
        require(msg.sender==admin, "Solo el administrador puede hacer esto");
        _;
    }




    //creacion de tokens
    function createToken(address destinatario, uint256 cantidad) external onlyAdmin{
        _mint(destinatario, cantidad);
    }




    //eliminar tokens
    function burnToken(address cuenta, uint256 cantidad) external onlyAdmin{
        _burn(cuenta,cantidad);
    }
}
