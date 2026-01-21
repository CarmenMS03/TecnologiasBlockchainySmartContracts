// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "contracts/VoteToken.sol";
import "contracts/IExecutableProposal.sol";

contract QuadraticVoting{

    //ATRIBUTOS
    //hemos dejado los atributos públicos por comodidad para la ejecucion
    uint public _precioToken;
    uint public _maxTokens;
    uint public _numTokens;
    uint public _presupuesto;
    uint public _contadorIDS;
    uint public _estadoVotacion; // (0: cerrada, 1:abierta, 2:estado intermedio para las funciones del patron pull over push)
    uint public _ronda; //para el patron, para que sea posible recuperar tokens de rondas ya cerradas etc
    VoteToken _contratoERC20;
    address public _propietario;
    uint public _numParticipantes; 
    uint public _numPendingProposals;

    struct Propuesta{ 
        uint presupuesto;
        uint numVotos;
        uint numTokens;
        uint posicion_array;//para saber en que posicion, del array de propuestas correspondiente, se encuentra
        uint ronda; //a que ronda pertenece
        address contrato;
        address creador;
        bool aprobada;  // true: aprobada o false: pendiente
        bool cancelada;//para que se pueda reclamar los tokens luego en la funcion y no haga el bucle
        string titulo;
        string descripcion;
    }

    mapping(uint=>mapping(address => uint) )votoPorVotante; //indexado por idVotante cuantos votos ha dado cada participante concreto
   
    mapping (address => bool) public _inscritos; // relaciona a la direccion con si esta activo
    mapping(uint=> Propuesta) public _propuestas; // relaciona el id de una propuesta con su info
    //las propuestas se separan en arrays dependiendo de su estado o tipo
    uint[] public _propuestasAprobadas;
    uint[] public _propuestasSignaling;
    uint[] public _propuestasFinanciacion;
    uint[] public _propuestasCanceladas; //consultar las propuestas canceladas

   
   
    //MODIFICADORES

    //verificar que la función la ejecuta solo el propietario
    modifier onlyOwner() {
        require (_propietario == msg.sender, "No eres el propietario del contrato");
        _;
    }

    //verificar que la función se ejecuta solo con la votación abierta
    modifier estaAbierta() {
        require (_estadoVotacion == 1, "Votacion no abierta");
        _;
    }

    //verificar que la función se ejecuta solo con la votación cerrada
    modifier estaCerrada() {
        require (_estadoVotacion == 0, "Votacion no cerrada");
        _;
    }

    //verificar que la función se ejecuta solo con el estado intermedio para el patron pull over push
    modifier estadoIntermedio() {
        require (_estadoVotacion == 2, "El estado de la votacion no lo permite");
        _;
    }

    //verificar que la direccion esta activa en la votacion
    modifier estaActivo() {
        require (_inscritos[msg.sender] == true, "Direccion no activa");
        _;
    }

    //FUNCIONES
    constructor (uint precioToken, uint maxTokens){
        _precioToken = precioToken;
        _maxTokens = maxTokens;
        _numTokens=0;
        _presupuesto=0;
        _contadorIDS = 0;
        _propietario = msg.sender;
        _estadoVotacion = 0; //cerrada
        _ronda =0; 
        _numParticipantes=0;
        _numPendingProposals=0;
        _contratoERC20 = new VoteToken(address(this),"VoteToken", "VTK"); //creacion del contrato de los tokens
    }
     
    //Apertura de la votacion, solo por parte del propietario cuando la votacion esta cerrada
    function openVoting () public payable onlyOwner() estaCerrada(){
        _estadoVotacion = 1; //se cambia la votación a abierta
        _presupuesto = msg.value; //se debe transferir el presupuesto inicial
        _ronda++; //se incrementa la ronda por cada ronda nueva de la votación (que va desde 1)
        _numPendingProposals = 0; //se reinicia al iniciar una nueva (propuestas pendientes de esta ronda)
    }

    //Inscripcion a la votacion en cualquier momento y transfieren ether para los tokens
    function addParticipant () public payable{
        //se comprueban restricciones 
        require(_inscritos[msg.sender]==false, "Ya estas activo");
        require(msg.value >= _precioToken, "Debes enviar al menos el precio de un token");

        //se crea el numero de tokens correspondiente
        uint tokensComprados = msg.value / _precioToken; //toda division trunca el resultado
        //no hay problema con overflow por la version del compilador
        require(_numTokens + tokensComprados <= _maxTokens, "Supera el maximo de tokens");

        //se crean tokens directamente desde este contrato (que es admin del token)
        _contratoERC20.createToken(msg.sender, tokensComprados);
        _numTokens += tokensComprados; 

        //activar participante en las estructuras
        _inscritos[msg.sender] = true;
        _numParticipantes++;

        //devolver lo que sobra despues para evitar reentrada
        uint resto = msg.value % _precioToken;
        if (resto > 0) {
            (bool success, ) = msg.sender.call{value: resto}("");
            require(success, "Fallo al devolver el cambio");
        }
    }

    //Eliminacion de una direccion de la votacion
    function removeParticipant () public estaActivo(){

        //gestion de estructuras
        _inscritos[msg.sender] = false;
        _numParticipantes--;
    }

    //Añadir una propuesta, solo cuando la direccion esta inscrita y la votacion abierta
    function addProposal (string memory titulo, string memory descripcion, uint presupuesto, address contrato) public estaActivo() estaAbierta() returns (uint){
        
        //comprobar que la propuesta implementa la interfaz
        require(IERC165(contrato).supportsInterface(type(IExecutableProposal).interfaceId),"El contrato no implementa IExecutableProposal");
        
        //se crea un nuevo id para la propuesta
        _contadorIDS++;
        uint id = _contadorIDS;

        //posicion que pasa a ocupar en el array correspondiente
        uint pos = 0;
        if(presupuesto>0){
            _propuestasFinanciacion.push(id);
            pos =  _propuestasFinanciacion.length - 1;
            _numPendingProposals++;
        }
        else{
            _propuestasSignaling.push(id);
            pos =  _propuestasSignaling.length-1;
        }

        _propuestas[id] = Propuesta({
            presupuesto: presupuesto,
            numVotos: 0,
            numTokens: 0,
            posicion_array : pos,
            ronda: _ronda,
            contrato: contrato,
            creador : msg.sender,
            aprobada: false,
            cancelada: false,
            titulo: titulo,
            descripcion: descripcion
        });


        return id;
    }

    //reclamar los tokens de las propuestas que han sido canceladas (bajo demanda siguiendo el patron)
    function reclamarTokensCanceladas(uint id) public estaActivo() {
        Propuesta storage p = _propuestas[id];
        require(p.cancelada, "Propuesta no cancelada");
        require (p.aprobada == false, "Propuesta aprobada");

        uint votos = votoPorVotante[id][msg.sender];
        require(votos > 0, "No tienes votos en esta propuesta");

        uint tokensADevolver = votos * votos;
        votoPorVotante[id][msg.sender] = 0;
        p.numVotos-=votos;
        p.numTokens-=tokensADevolver;

        bool success = _contratoERC20.transfer(msg.sender, tokensADevolver);
        require(success, "Fallo al transferir tokens");

        if(p.numVotos == 0) {
            uint movida =  _propuestasCanceladas[_propuestasCanceladas.length-1];//**************************
            _propuestas[movida].posicion_array = p.posicion_array;
            _propuestasCanceladas[p.posicion_array] = movida;
            _propuestasCanceladas.pop();

            delete _propuestas[id];
        }

    }

    //Cancelar propuesta, solo con la votación abierta por el creador de esta
    function cancelProposal (uint id) public estaAbierta() estaActivo(){

        //se hace una variable en storage para menor cantidad de accesos
        Propuesta storage p = _propuestas[id];

        //comprobar restricciones
        require (p.creador == msg.sender, "Solo puede cancelar una propuesta su creador");
        require(p.aprobada == false, "No se puede cancelar una propuesta aprobada");
        require(p.cancelada == false, "Propuesta ya cancelada");
        
        p.cancelada = true; //se marca como cancelada y se evita el bucle
        
        //en el array de las propuesatas se elimina
        if(p.presupuesto>0){
            uint movida =  _propuestasFinanciacion[_propuestasFinanciacion.length-1];
            _propuestas[movida].posicion_array = p.posicion_array;
            _propuestasFinanciacion[p.posicion_array] = movida;
            _propuestasFinanciacion.pop();
            _numPendingProposals--;

        }
        else{
            uint movida =  _propuestasSignaling[_propuestasSignaling.length-1];
            _propuestas[movida].posicion_array = p.posicion_array;
            _propuestasSignaling[p.posicion_array] = movida;
            _propuestasSignaling.pop();
        }

        
        //se añade a canceladas y no se borra del mapa
        _propuestasCanceladas.push(id); 
        p.posicion_array = _propuestasCanceladas.length - 1; //*******************************
    }

    //Compra de tokens para una direccion inscrita
    function buyTokens () public payable estaActivo(){

       require(msg.value >= _precioToken, "Al menos el precio de un token");

        uint tokensComprados = msg.value / _precioToken; //toda division trunca el resultado
        require(_numTokens + tokensComprados <= _maxTokens, "Supera el maximo de tokens");

        _numTokens += tokensComprados;
        _contratoERC20.createToken(msg.sender, tokensComprados);
        

        //devolver resto
        uint resto = msg.value % _precioToken;
        if (resto > 0) {
            (bool success, ) = msg.sender.call{value: resto}("");
            require(success, "Fallo al devolver el cambio");
        }
    }
   
    //Venta de tokens para una direccion inscrita
    function sellTokens (uint devolver) public estaActivo(){
        uint numtokens = _contratoERC20.balanceOf(msg.sender);
        require(devolver <= numtokens, "No tienes suficientes tokens");

        //calcular cantidad y quemarlos
        uint cantidad = devolver * _precioToken;
        _contratoERC20.burnToken(msg.sender, numtokens); //actualiza balance para que no haya reentrada
        _numTokens -= devolver;
        //enviar cantidad
        (bool success, ) = msg.sender.call{value: cantidad}("");
        require(success, "Error al enviar la cantidad");

    }

    //Direccion del contrato de los tokens para participantes
    function getERC20 () view public estaActivo() returns (address){
        return address(_contratoERC20);
    }

    //Array con ids de las propuestas pendientes, solo con la votacion abierta
    function getPendingProposals () view public estaAbierta() returns (uint[] memory){
       return _propuestasFinanciacion;
    }

    //Array con ids de las propuestas en aprobadas, solo con la votacion abierta
    function getApprovedProposals () view public estaAbierta() returns (uint[] memory){
        return _propuestasAprobadas;
    }

    //Array con ids de las propuestas en signaling, solo con la votacion abierta
    function getSignalingProposals () view public estaAbierta() returns (uint[] memory){
        return _propuestasSignaling;
    }

    //Array con ids de las propuestas canceladas
    function getCanceledProposals () view public estaAbierta() returns (uint[] memory){
        return _propuestasCanceladas;
    }

    //Obtener información de una propuesta
    function getProposalInfo (uint id)  view public estaAbierta() returns ( Propuesta memory){
        Propuesta memory info = _propuestas[id];
        return info;
    }

    //Realiza el voto de quien ejecuta la funcion, debe estar inscrito y la votacion abierta
    function stake (uint id, uint nuevosVotos) public estaActivo() estaAbierta(){
        require(nuevosVotos > 0, "Al menos un voto");

        Propuesta storage p = _propuestas[id];
        require(!p.aprobada, "Propuesta ya aprobada");
        require(!p.cancelada, "Propuesta cancelada");

        //debe pertenecer a esta ronda para poder votarla
        require(p.ronda == _ronda, "La propuesta no pertence a esta ronda");

        //se comprueban los votos a esta propuesta por parte del participante
        uint votosPrevios = votoPorVotante[id][msg.sender];
        uint totalVotos = votosPrevios + nuevosVotos;

        //cálculo cuadrático del coste adicional
        uint costeAntes = votosPrevios * votosPrevios;
        uint costeDespues = totalVotos * totalVotos;
        uint costeExtra = costeDespues - costeAntes; //tokens necesarios para realizar los votos

        //verificar allowance (el approve lo hizo el usuario antes de llamar a esta funcion)
        require(_contratoERC20.allowance(msg.sender, address(this)) >= costeExtra, "Aprobacion insuficiente");

        bool success = _contratoERC20.transferFrom(msg.sender, address(this), costeExtra);
        require(success, "Fallo al transferir tokens");

        //registrar los votos y sumar al total de la propuesta
        p.numTokens += costeExtra;
        p.numVotos += nuevosVotos;
        votoPorVotante[id][msg.sender] += nuevosVotos;

        //comprobar si se puede aprobar la propuesta
        if(p.presupuesto>0){ //solo las de financiacion se aprueban aqui, las signailing al finalizar
            _checkAndExecuteProposal(id);
        }
    }

    //Retirar los votos del participante de cierta propuesta
    function withdrawFromProposal (uint id, uint cantidad) public estaActivo() estaAbierta() {

        Propuesta storage p = _propuestas[id];
        //solo puede retirar votos de una propuesta no aprobada y sus propios votos
        require(!p.aprobada, "Propuesta ya aprobada");
        uint votos = votoPorVotante[id][msg.sender];
        require(votos >= cantidad, "No tienes votos suficientes en esta propuesta");

        //debe pertenecer a esta ronda para poder retirar votos
        require(p.ronda == _ronda, "La propuesta no pertence a esta ronda");

        //cantidad a devolver siguiendo la logica cuadratica
        uint votosRestantes = votos - cantidad;
        uint tokensADevolver = (votos * votos) - (votosRestantes * votosRestantes);

        //actualizar estado
        votoPorVotante[id][msg.sender] -= cantidad;
        p.numVotos -= cantidad;
        p.numTokens -= tokensADevolver;

        //devolver tokens  
        bool success = _contratoERC20.transfer(msg.sender , tokensADevolver);
        require(success, "Fallo al transferir tokens");
    }


    //se usa para calcular el umbral para que una propuesta se acepte
    function _calcularUmbral(uint id) internal view returns (uint) {

        if (_presupuesto == 0) return type(uint).max; // para evitar división por 0
    
        Propuesta storage p = _propuestas[id];
    
        uint umbral = ((2e17*_presupuesto + p.presupuesto * 1e18)* _numParticipantes / _presupuesto)  / 1e18 + _numPendingProposals;
        return umbral;
    }


    //Comprueba que la propuesta se debe aceptar y ejecuta executeProposal
    function _checkAndExecuteProposal (uint id) internal {
        Propuesta storage p = _propuestas[id];
        //se calcula el umbral con la formula dada en el enunciado
        uint umbral = _calcularUmbral(id); 

        //se comrpueba si se puede aprobar
        if (p.numVotos > umbral && p.presupuesto<=_presupuesto) {
            p.aprobada = true;
            _propuestasAprobadas.push(id);
            uint movida =  _propuestasFinanciacion[_propuestasFinanciacion.length-1];
            _propuestas[movida].posicion_array = p.posicion_array;
            _propuestasFinanciacion[p.posicion_array] = movida;
            _propuestasFinanciacion.pop();
            _presupuesto += p.numTokens*_precioToken;
            _presupuesto -= p.presupuesto;
            _numPendingProposals--;

            //quemar los tokens
            _contratoERC20.burnToken(address(this), p.numTokens);
            _numTokens -= p.numTokens;
            //llamar a la funcion de ejecutar
            (bool success, ) = p.contrato.call{value: p.presupuesto, gas: 100000}(
                abi.encodeWithSignature("executeProposal(uint256,uint256,uint256)", id, p.numVotos, p.numTokens)
            );

            require(success, "Fallo al ejecutar la propuesta");

        }

    }

    //Cierre de la votación solo por el propietario--> PARTE OPCIONAL
    function closeVoting () public onlyOwner() estaAbierta() {
        _estadoVotacion = 2; //se pone en estado intermedio para que puedan ejecutar las funciones
    }

    //Patron pull over push

    function reiniciarVotacion() public onlyOwner() estadoIntermedio(){
        if (_presupuesto > 0) {
            uint restante = _presupuesto;
            _presupuesto = 0; //antes para evitar reentrada
            (bool success, ) = _propietario.call{value: restante}("");
            require(success, "Error al devolver Ether");
        }
        _estadoVotacion = 0;//pasa a estar cerrado
        _numPendingProposals = 0;
        delete _propuestasAprobadas;
        delete _propuestasFinanciacion;
        delete _propuestasSignaling;
    }

    //reclamar los tokens cuando ha terminado la votacion (bajo demanda siguiendo el patron)
    function reclamarTokens(uint id) public estaActivo(){
        Propuesta storage p = _propuestas[id];
        require(!p.aprobada  , "Propuesta aprobada");

        uint votos = votoPorVotante[id][msg.sender];
        require(votos > 0, "No tienes votos en esta propuesta");

        require(p.ronda < _ronda || (p.ronda == _ronda && _estadoVotacion ==2), "Propuesta de ronda no valida");

        uint tokensADevolver = votos * votos;
        votoPorVotante[id][msg.sender] = 0; //antes para evitar reentrada
        p.numVotos-=votos;
        p.numTokens-=tokensADevolver;

        bool success = _contratoERC20.transfer(msg.sender, tokensADevolver);
        require(success, "Fallo al transferir tokens");
        if(p.numVotos == 0) delete _propuestas[id];
    }

    //ejecutar las propuestas signaling bajo demanda
    function ejecutarPropuestaSignaling(uint id) public {
        Propuesta storage p = _propuestas[id];
        require(!p.aprobada, "Propuesta ya aprobada");
        require(p.presupuesto == 0, "No es signaling");
        require(p.creador == msg.sender, "Solo el creador puede ejecutarla");
        require(p.ronda < _ronda || (p.ronda == _ronda && _estadoVotacion ==2), "Propuesta de ronda no valida");

        p.aprobada = true;
        
        //quemar los tokens
        _contratoERC20.burnToken(address(this), p.numTokens);
        _numTokens -= p.numTokens;
        (bool success, ) = p.contrato.call{gas: 100000}(
            abi.encodeWithSignature("executeProposal(uint256,uint256,uint256)", id, p.numVotos, p.numTokens)
        );

        require(success, "Fallo al ejecutar signaling");
    }

}
