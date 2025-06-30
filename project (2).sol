// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Autonomous Art Evolution Contract
 * @dev A smart contract that creates and evolves digital art autonomously using blockchain data
 */
contract Project is ERC721, Ownable {
    
    struct ArtPiece {
        uint256 id;
        uint256 generation;
        uint256 birthBlock;
        uint256 dna;
        uint256 interactionCount;
        uint256 parentA;
        uint256 parentB;
        bool isGenesis;
    }
    
    // State variables
    mapping(uint256 => ArtPiece) public artPieces;
    uint256 public totalSupply;
    uint256 public currentGeneration;
    uint256 public lastEvolutionBlock;
    uint256 public constant EVOLUTION_INTERVAL = 100; // blocks
    uint256 public constant MAX_GENESIS_PIECES = 10;
    
    // Events
    event ArtCreated(uint256 indexed tokenId, uint256 generation, uint256 dna);
    event EvolutionTriggered(uint256 newGeneration, uint256 blockNumber);
    event ArtInteraction(uint256 indexed tokenId, address user);
    
    constructor() ERC721("AutonomousArt", "AART") Ownable(msg.sender) {
        currentGeneration = 0;
        lastEvolutionBlock = block.number;
        _createGenesisPieces();
    }
    
    /**
     * @dev Core Function 1: Generate Art DNA from blockchain data
     * @param blockHash The block hash to use for randomness
     * @param additionalSeed Additional seed for uniqueness
     * @return Generated DNA value
     */
    function generateArtDNA(bytes32 blockHash, uint256 additionalSeed) public pure returns (uint256) {
        // Combine block hash with additional parameters to create unique DNA
        uint256 dna = uint256(keccak256(abi.encodePacked(
            blockHash,
            additionalSeed,
            block.timestamp,
            block.difficulty
        )));
        
        // Ensure DNA is within valid range for art properties
        return dna % (10**18);
    }
    
    /**
     * @dev Core Function 2: Evolve art pieces automatically
     * Creates new generation by breeding most popular pieces
     */
    function evolveArt() public {
        require(
            block.number >= lastEvolutionBlock + EVOLUTION_INTERVAL,
            "Evolution interval not reached"
        );
        
        // Find two most popular pieces from current generation
        uint256 parentA = _findMostPopular();
        uint256 parentB = _findSecondMostPopular(parentA);
        
        require(parentA != 0 && parentB != 0, "Not enough pieces to evolve");
        
        // Create new piece by combining parents
        uint256 newTokenId = totalSupply + 1;
        uint256 newDNA = _breedDNA(
            artPieces[parentA].dna,
            artPieces[parentB].dna,
            blockhash(block.number - 1)
        );
        
        // Apply random mutation
        newDNA = _mutate(newDNA);
        
        // Create new art piece
        artPieces[newTokenId] = ArtPiece({
            id: newTokenId,
            generation: currentGeneration + 1,
            birthBlock: block.number,
            dna: newDNA,
            interactionCount: 0,
            parentA: parentA,
            parentB: parentB,
            isGenesis: false
        });
        
        _mint(address(this), newTokenId);
        totalSupply++;
        currentGeneration++;
        lastEvolutionBlock = block.number;
        
        emit ArtCreated(newTokenId, currentGeneration, newDNA);
        emit EvolutionTriggered(currentGeneration, block.number);
    }
    
    /**
     * @dev Core Function 3: Interact with art piece (affects evolution fitness)
     * @param tokenId The ID of the art piece to interact with
     */
    function interactWithArt(uint256 tokenId) public {
        require(_exists(tokenId), "Art piece does not exist");
        
        // Increase interaction count (fitness score)
        artPieces[tokenId].interactionCount++;
        
        emit ArtInteraction(tokenId, msg.sender);
        
        // Trigger evolution if interval reached
        if (block.number >= lastEvolutionBlock + EVOLUTION_INTERVAL) {
            evolveArt();
        }
    }
    
    // Internal helper functions
    function _createGenesisPieces() internal {
        for (uint256 i = 1; i <= MAX_GENESIS_PIECES; i++) {
            uint256 dna = generateArtDNA(
                blockhash(block.number - (i % 10 + 1)),
                i
            );
            
            artPieces[i] = ArtPiece({
                id: i,
                generation: 0,
                birthBlock: block.number,
                dna: dna,
                interactionCount: 0,
                parentA: 0,
                parentB: 0,
                isGenesis: true
            });
            
            _mint(address(this), i);
            emit ArtCreated(i, 0, dna);
        }
        
        totalSupply = MAX_GENESIS_PIECES;
    }
    
    function _findMostPopular() internal view returns (uint256) {
        uint256 mostPopular = 0;
        uint256 highestCount = 0;
        
        for (uint256 i = 1; i <= totalSupply; i++) {
            if (artPieces[i].interactionCount > highestCount) {
                highestCount = artPieces[i].interactionCount;
                mostPopular = i;
            }
        }
        
        return mostPopular;
    }
    
    function _findSecondMostPopular(uint256 excludeId) internal view returns (uint256) {
        uint256 secondMostPopular = 0;
        uint256 secondHighestCount = 0;
        
        for (uint256 i = 1; i <= totalSupply; i++) {
            if (i != excludeId && artPieces[i].interactionCount > secondHighestCount) {
                secondHighestCount = artPieces[i].interactionCount;
                secondMostPopular = i;
            }
        }
        
        return secondMostPopular;
    }
    
    function _breedDNA(uint256 dnaA, uint256 dnaB, bytes32 randomSeed) internal pure returns (uint256) {
        // Combine parent DNA with some randomness
        uint256 combinedDNA = (dnaA + dnaB) / 2;
        uint256 randomFactor = uint256(randomSeed) % 1000;
        
        return (combinedDNA * (1000 + randomFactor)) / 1000;
    }
    
    function _mutate(uint256 dna) internal view returns (uint256) {
        // Random mutation based on block properties
        uint256 mutationChance = uint256(blockhash(block.number - 1)) % 100;
        
        if (mutationChance < 10) { // 10% mutation chance
            uint256 mutationFactor = (block.timestamp % 200) + 900; // 0.9x to 1.1x
            return (dna * mutationFactor) / 1000;
        }
        
        return dna;
    }
    
    // View functions for getting art properties
    function getArtPiece(uint256 tokenId) public view returns (ArtPiece memory) {
        require(_exists(tokenId), "Art piece does not exist");
        return artPieces[tokenId];
    }
    
    function getArtProperties(uint256 tokenId) public view returns (
        uint256 colorHue,
        uint256 pattern,
        uint256 complexity,
        uint256 size
    ) {
        require(_exists(tokenId), "Art piece does not exist");
        uint256 dna = artPieces[tokenId].dna;
        
        colorHue = (dna % 360); // 0-359 degrees
        pattern = ((dna / 360) % 10); // 0-9 pattern types
        complexity = ((dna / 3600) % 100); // 0-99 complexity level
        size = ((dna / 360000) % 5) + 1; // 1-5 size multiplier
    }
    
    function canEvolve() public view returns (bool) {
        return block.number >= lastEvolutionBlock + EVOLUTION_INTERVAL;
    }
}