// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract PrivateVoting {
    event ProposalCreated(uint indexed proposalId, string description, uint depositAmount);
    event Voted(uint indexed proposalId, address indexed voter, bytes encryptedVote);
    event VotingClosed(uint indexed proposalId);
    event TokenSent(address indexed recipient, uint amount);

    struct Proposal {
        uint id; 
        string description;
        uint depositAmount; // Deposit amount required for voting
        uint tokenDistribution; // Token distribution amount per voter
        mapping(address => bool) hasVoted;
        bytes[] encryptedVotes;
        uint quorum;
        uint voteCount;
    }

    mapping(uint => Proposal) public proposals;
    uint public nextProposalId = 1;

    mapping(address => uint) public deposits; // Deposits made by proposal creators

    function createProposal(string memory description, uint quorum, uint depositAmount) external payable {
        uint tokenDistribution = depositAmount / quorum;
        require(depositAmount > 0, "Deposit amount must be greater than zero");
        require(tokenDistribution > 0, "Token distribution must be greater than zero");
        require(msg.value == depositAmount, "Deposit amount does not match sent value");

        uint proposalId = nextProposalId;
        nextProposalId++;

        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.description = description;
        proposal.depositAmount = depositAmount;
        proposal.tokenDistribution = tokenDistribution;
        proposal.quorum = quorum;
        deposits[msg.sender] += depositAmount; // Add deposit to sender's balance
        emit ProposalCreated(proposalId, description, depositAmount);
    }

    function getProposal(uint proposalId) external view returns (uint, string memory, uint, uint, uint) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.id, proposal.description, proposal.quorum, proposal.voteCount, proposal.tokenDistribution);
    }

    function vote(uint proposalId, bytes calldata encryptedVote) external {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(proposal.voteCount < proposal.quorum, "Voting closed");

        proposal.encryptedVotes.push(encryptedVote);
        proposal.hasVoted[msg.sender] = true;
        proposal.voteCount++;

        emit Voted(proposalId, msg.sender, encryptedVote);

        if (proposal.voteCount >= proposal.quorum) {
            emit VotingClosed(proposalId);
        }

        // Send token to voter
        uint tokenAmount = proposal.tokenDistribution; // Token amount to send
        require(address(this).balance >= tokenAmount, "Insufficient contract balance");
        payable(msg.sender).transfer(tokenAmount);
        emit TokenSent(msg.sender, tokenAmount); // Emit event to inform voter that tokens have been sent
    }

    function getVotes(uint proposalId) external view returns (bytes[] memory) {
        return proposals[proposalId].encryptedVotes;
    }

    struct ProposalInfo {
        uint id;
        string description;
        uint quorum;
        uint voteCount;
        uint tokenDistribution;
        bytes[] encryptedVotes;
    }

    function getAllProposals(bool open) external view returns (ProposalInfo[] memory) {
        uint count = 0;
        for (uint i = 1; i < nextProposalId; i++) {
            if ((proposals[i].voteCount < proposals[i].quorum) == open) {
                count++;
            }
        }

        ProposalInfo[] memory proposalsInfo = new ProposalInfo[](count);
        uint index = 0;
        for (uint i = 1; i < nextProposalId; i++) {
            if ((proposals[i].voteCount < proposals[i].quorum) == open) {
                Proposal storage proposal = proposals[i];
                proposalsInfo[index] = ProposalInfo({
                    id: proposal.id,
                    description: proposal.description,
                    quorum: proposal.quorum,
                    voteCount: proposal.voteCount,
                    tokenDistribution: proposal.tokenDistribution,
                    encryptedVotes: open ? new bytes[](0) : proposal.encryptedVotes
                });
                index++;
            }
        }

        return proposalsInfo;
    }

    // Function to withdraw deposit
    function withdrawDeposit() external {
        uint depositAmount = deposits[msg.sender];
        require(depositAmount > 0, "No deposit to withdraw");
        deposits[msg.sender] = 0; // Clear deposit balance
        payable(msg.sender).transfer(depositAmount);
    }
}
