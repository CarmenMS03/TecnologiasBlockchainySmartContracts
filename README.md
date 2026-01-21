# ⛓️ TBC - Tecnologías Blockchain y Smart Contracts (UCM)

Este repositorio contiene las prácticas y el proyecto final de la asignatura **Tecnologías Blockchain y Smart Contracts**, perteneciente al Grado en Ingeniería Informática de la **Universidad Complutense de Madrid**.

## 📝 Descripción del Proyecto: Sistema de Gobernanza DAO
El proyecto principal consiste en el diseño e implementación de un sistema de **gobernanza on-chain** para Organizaciones Autónomas Descentralizadas (DAOs) utilizando la tecnología de contratos inteligentes de Ethereum.

El sistema permite la gestión de propuestas y votaciones mediante un mecanismo de **Votación Cuadrática**, donde el coste de los votos adicionales para una misma propuesta crece de forma cuadrática ($coste = votos^2$), permitiendo una distribución más equilibrada del poder de decisión.

## 📁 Características del Sistema
El contrato central `QuadraticVoting` gestiona todo el ciclo de vida de la gobernanza:

* **Gestión de Tokens ERC20:** Implementación de un token personalizado (basado en OpenZeppelin) para representar el peso del voto dentro del sistema.
* **Tipos de Propuestas:** * **Financiación:** Requieren superar un umbral dinámico basado en el presupuesto y participantes para ejecutar una transferencia de Ether a un contrato externo (`IExecutableProposal`).
    * **Signaling:** Utilizadas para medir la opinión de la comunidad sin transferencia de fondos asociada.
* **Umbral Dinámico:** El sistema recalcula el umbral necesario para aprobar cada propuesta en función del presupuesto total disponible, el número de participantes y las propuestas pendientes.
* **Seguridad y Optimización:**
    * Protección contra ataques comunes en Solidity (Reentrancy, DoS).
    * Uso de transferencias seguras mediante `call` de bajo nivel.
    * Limitación de gas (max 100,000) en llamadas a contratos externos maliciosos.
    * (Opcional) Implementación del patrón *Pull-over-Push* para la gestión eficiente de devoluciones de tokens.

## 🛠️ Tecnologías y Herramientas
* **Lenguajes:** Solidity (0.8.x / 0.7.x).
* **Librerías:** OpenZeppelin (ERC20, Capped, Burnable).
* **Entorno de desarrollo:** Remix / Hardhat / Foundry.
* **Blockchain:** Ethereum (EVM compatible).

## ⚖️ Licencia
Este repositorio y su contenido están protegidos por **Copyright © 2026 CarmenMS03**. Todos los derechos reservados.
El material se comparte exclusivamente con fines educativos y de portafolio personal. Los enunciados de los proyectos y materiales docentes son propiedad intelectual de la **Universidad Complutense de Madrid**.

## 👤 Autor
* **CarmenMS03** - [GitHub Profile](https://github.com/CarmenMS03)

---
---

# ⛓️ TBC - Blockchain Technologies and Smart Contracts (UCM)

This repository contains the assignments and the final project for the **Blockchain Technologies and Smart Contracts** course at **Universidad Complutense de Madrid**.

## 📝 Project Overview: DAO Governance System
The core project involves the design and implementation of an **on-chain governance system** for Decentralized Autonomous Organizations (DAOs) using Ethereum smart contracts.

The system manages proposals and voting through a **Quadratic Voting** mechanism, where the cost of additional votes for a single proposal increases quadratically ($cost = votes^2$), ensuring a more balanced distribution of decision-making power.

## 📁 System Features
The central `QuadraticVoting` contract manages the entire governance lifecycle:

* **ERC20 Token Management:** Implementation of a custom token (OpenZeppelin based) to represent voting weight within the system.
* **Proposal Types:**
    * **Funding:** Must clear a dynamic threshold based on budget and participants to trigger an Ether transfer to an external contract (`IExecutableProposal`).
    * **Signaling:** Used to gauge community sentiment without associated fund transfers.
* **Dynamic Threshold:** The system recalculates the approval threshold for each proposal based on total budget, participant count, and pending proposals.
* **Security & Optimization:**
    * Protection against common Solidity attacks (Reentrancy, DoS).
    * Secure Ether transfers using low-level `call`.
    * Gas limits (max 100,000) for external calls to potentially malicious contracts.
    * (Optional) Implementation of the *Pull-over-Push* pattern for efficient token refunds.

## 🛠️ Technologies & Tools
* **Languages:** Solidity (0.8.x / 0.7.x).
* **Libraries:** OpenZeppelin (ERC20, Capped, Burnable).
* **Development Environment:** Remix / Hardhat / Foundry.
* **Blockchain:** Ethereum (EVM compatible).

## ⚖️ License
This repository and its content are protected by **Copyright © 2026 CarmenMS03**. All rights reserved.
This material is shared exclusively for educational and personal portfolio purposes. Project descriptions and teaching materials are the intellectual property of **Universidad Complutense de Madrid**.

## 👤 Author
* **CarmenMS03** - [GitHub Profile](https://github.com/CarmenMS03)
