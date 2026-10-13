// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

//Théorie: 
//  - on part du principe que chaque participant propose une idée et une seule.
//  - en cas d'égalité le vote sera à recommencer.Le reset n'est pas géré ici.

contract Voting is Ownable{

    constructor() Ownable(msg.sender){  }

    struct Voter { bool isRegistered; bool hasMadeProposal; bool hasVoted; uint votedProposalId;} 
    struct Proposal {uint proposalId; string description; uint voteCount; }
    enum WorkflowStatus { RegisteringVoters, ProposalsRegistrationStarted, ProposalsRegistrationEnded, VotingSessionStarted, VotingSessionEnded, VotesTallied }
    string[6] nameWorkflowStatut = ["Enregistrement des votants","Propositions Ouvertes",unicode"Propositions Fermées","Votes Ouverts","Votes Clos",unicode"Dépouillement"];

    uint winningProposalId; 
    uint votersCount;
    bool IsThereEquality;

    mapping(address=> Voter voterDetails) whitelist;
    WorkflowStatus electionProgressing;    
    Proposal [] proposals;

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(string previousStatus, string newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voterId, uint proposalId );

    modifier checkAddressZero(address _address){
        require(_address != address(0), unicode"Addresse électeur incorrecte");
        _;
    }

    modifier checkWorkflowStatus(WorkflowStatus _workflowStatus){
        require(_workflowStatus == electionProgressing, unicode"Cette action n'est pas compatible avec l'étape actuelle du processus de vote");
        _;
    }

    modifier isVoterRegistred(){        
        require(whitelist[msg.sender].isRegistered, unicode"Vous n'êtes pas enregistrés pour cette session !!!");
        _;
    }

    modifier isElectorRegistred(address _address){        
        require(whitelist[_address].isRegistered, unicode"Cette utilisaeur n'est pas enregistré pour cette session");
        _;
    }

    modifier isAllowedSeeVotes(){
        require(whitelist[msg.sender].isRegistered || msg.sender == owner(), unicode"Vous n'êtes pas autorisés à voir le vote des électeurs !!!");
        _;
    }

    function getWorkFlowStatus() external view returns(string memory){
        if(uint(electionProgressing) == nameWorkflowStatut.length-1){
            return string.concat("Etapes en cours: ", nameWorkflowStatut[uint(electionProgressing)], " / Votes Finis");
        }
        return string.concat("Etapes en cours: ", nameWorkflowStatut[uint(electionProgressing)], " / Prochaine Etape: ", nameWorkflowStatut[uint(electionProgressing)+1]);        
    }

    // Afin de faciliter le processus le workflow se declenchera par une nextstep unique.
    function NextWorkflowStep() external onlyOwner {
        require(WorkflowStatus.VotesTallied != electionProgressing, unicode"La session de vote est finie");
        if (WorkflowStatus.RegisteringVoters == electionProgressing)
            StartProposalRegistration();
        else if (WorkflowStatus.ProposalsRegistrationStarted == electionProgressing)
            CloseProposalRegistration();
        else if (WorkflowStatus.ProposalsRegistrationEnded == electionProgressing)
            StartVoting();
        else if ((WorkflowStatus.VotingSessionStarted == electionProgressing))
            StopVoting();
        else if ((WorkflowStatus.VotingSessionEnded == electionProgressing))
            VoteCounting();
    }

    //Ouverture des propositions
    function StartProposalRegistration() private checkWorkflowStatus(WorkflowStatus.RegisteringVoters) {
        require(votersCount > 1, unicode"En attente de deux électeurs minimum pour passer à l'étape suivante");
        electionProgressing = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(nameWorkflowStatut[uint(WorkflowStatus.RegisteringVoters)],nameWorkflowStatut[uint(WorkflowStatus.ProposalsRegistrationStarted)]);
    }

    //Cloture des propositions
    function CloseProposalRegistration() private checkWorkflowStatus(WorkflowStatus.ProposalsRegistrationStarted) {
        require(proposals.length > 1, unicode"En attente de deux propisitions minumum pour passer à l'étape suivante");
        electionProgressing = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(nameWorkflowStatut[uint(WorkflowStatus.ProposalsRegistrationStarted)],nameWorkflowStatut[uint(WorkflowStatus.ProposalsRegistrationEnded)]);
    }

    //ouverture des votes
    function StartVoting() private checkWorkflowStatus(WorkflowStatus.ProposalsRegistrationEnded) {
        electionProgressing = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(nameWorkflowStatut[uint(WorkflowStatus.ProposalsRegistrationEnded)],nameWorkflowStatut[uint(WorkflowStatus.VotingSessionStarted)]);       
    }

    //Fin des votes
    function StopVoting() private checkWorkflowStatus(WorkflowStatus.VotingSessionStarted) {
        uint totalVotes;
        for(uint i = 0; i < proposals.length; i++)
        {
            totalVotes += proposals[i].voteCount;
        }
        require(totalVotes == votersCount, unicode"Impossible de fermer les votes tant que tout le monde n'as pas voté !!!");
        electionProgressing = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(nameWorkflowStatut[uint(WorkflowStatus.VotingSessionStarted)],nameWorkflowStatut[uint(WorkflowStatus.VotingSessionEnded)]);       
    }

    //Decomtpes des votes
    function VoteCounting() private checkWorkflowStatus(WorkflowStatus.VotingSessionEnded) {
        winningProposalId=0;
        uint maxCount = proposals[winningProposalId].voteCount;
        
        for(uint i = 1; i<proposals.length;i++){
            if (maxCount < proposals[i].voteCount){
                winningProposalId=i;
                maxCount= proposals[i].voteCount;
                IsThereEquality= false;
            }
            else if(maxCount == proposals[i].voteCount){
                IsThereEquality= true;
            }
        }
        electionProgressing = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(nameWorkflowStatut[uint(WorkflowStatus.VotingSessionEnded)],nameWorkflowStatut[uint(WorkflowStatus.VotesTallied)]);       
    }

    //Affichage des propositions sans le nombre de vote sauf si à l'étape du depouillement
    function getPropositions() external view returns (Proposal[] memory) {
        require(proposals.length > 0, unicode"Aucune proposition à afficher pour l'instant");
        
        if(WorkflowStatus.VotesTallied == electionProgressing){
            return proposals;
        }
        else {
            Proposal[] memory shortProposals = new Proposal[](proposals.length);
            for (uint i = 0; i< proposals.length;i++){
                shortProposals[i] = Proposal(proposals[i].proposalId, proposals[i].description,0);
            }
            return shortProposals;
        }
        
    }

    //Enregistrement d'un électeur
    function RecordingElector (address _address) external 
    onlyOwner 
    checkAddressZero(_address) 
    checkWorkflowStatus(WorkflowStatus.RegisteringVoters) {
        require(!whitelist[_address].isRegistered, unicode"Electeur déja enregistré");
        whitelist[_address].isRegistered= true;
        votersCount++;
        emit VoterRegistered(_address);
    }

    //Enregistrement des propositions
    function RecordingProposal (string memory _proposal) external 
    isVoterRegistred
    checkWorkflowStatus(WorkflowStatus.ProposalsRegistrationStarted){
        require(!whitelist[msg.sender].hasMadeProposal, unicode"Proposition déja effectuée");
        whitelist[msg.sender].hasMadeProposal = true;
        proposals.push(Proposal(proposals.length,_proposal,0));
        emit ProposalRegistered(proposals.length-1);
    }

    //Enregistrement des votes
    function RecordingVote(uint _proposalId) external 
    isVoterRegistred
    checkWorkflowStatus(WorkflowStatus.VotingSessionStarted) {
         require(!whitelist[msg.sender].hasVoted, unicode"Vous avez déja voté");
         require(_proposalId <= proposals.length, unicode"Cette proposition n'existe pas");
         whitelist[msg.sender].hasVoted = true;
         whitelist[msg.sender].votedProposalId = _proposalId;
         proposals[_proposalId].voteCount++;
         emit Voted(msg.sender, _proposalId);
    }

    //Affichage du gagnant
    function getProposalWinner () external  view 
    checkWorkflowStatus(WorkflowStatus.VotesTallied) returns(Proposal memory)  {
        if(IsThereEquality){
            return Proposal(0,unicode"Pas de Vainqueur car égalité. Vote à recommencer",0);
        }
        return proposals[winningProposalId];
    }

    //Affichage du vote d'un electeur
    function getElectorVote(address _address) external view
    isAllowedSeeVotes
    isElectorRegistred(_address)
    checkWorkflowStatus(WorkflowStatus.VotesTallied) returns(string memory){
        
        return proposals[whitelist[_address].votedProposalId].description;
    }
}
