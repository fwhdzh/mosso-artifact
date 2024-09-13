--------------------------------- MODULE raft_el ---------------------------------
EXTENDS Naturals, FiniteSets, Sequences, TLC

\* The set of server IDs
CONSTANTS Server

\* Server states.
CONSTANTS Follower, Candidate, Leader

\* A reserved value.
CONSTANTS Nil

\* Message types:
CONSTANTS RequestVoteRequest, RequestVoteResponse

CONSTANTS TimeoutLimit, RestartLimit

----
\* Global variables

\* A bag of records representing requests and responses sent from one server
\* to another. TLAPS doesn't support the Bags module, so this is a function
\* mapping Message to Nat.
VARIABLE messages

\* Constraints variable by Dong Wang
VARIABLE timeoutNum, restartNum
----
\* The following variables are all per server (functions with domain Server).

\* The server's term number.
VARIABLE currentTerm
\* The server's state (Follower, Candidate, or Leader).
VARIABLE state
\* The candidate the server voted for in its current term, or
\* Nil if it hasn't voted for any.
VARIABLE votedFor
serverVars == <<currentTerm, state, votedFor>>

\* The following variables are used only on candidates:
\* The set of servers from which the candidate has received a RequestVote
\* response in its currentTerm.
VARIABLE votesSent
\* The set of servers from which the candidate has received a vote in its
\* currentTerm.
VARIABLE votesGranted
\* Function from each server that voted for this candidate in its currentTerm
\* to that voter's log.
candidateVars == <<votesSent, votesGranted>>

\* End of per server variables.
----

\* All variables; used for stuttering (asserting state hasn't changed).
vars == <<messages, serverVars, candidateVars, 
          timeoutNum, restartNum>>

----
\* Helpers

\* The set of all quorums. This just calculates simple majorities, but the only
\* important property is that every quorum overlaps with every other.
Quorum == {i \in SUBSET(Server) : Cardinality(i) * 2 > 
          Cardinality(Server)}

\* The term of the last entry in a log, or 0 if the log is empty.
LastTerm(xlog) == IF Len(xlog) = 0 THEN 0 ELSE 
                  xlog[Len(xlog)].term

delete(m,msgs) == [i \in DOMAIN msgs \ {m} |-> msgs[i]]

WithMessage(m, msgs) ==
          IF m \in DOMAIN msgs 
          THEN [msgs EXCEPT ![m] = msgs[m] + 1] 
          ELSE msgs @@ (m :> 1)
        
WithoutMessage(m , msgs) ==
          IF m \in DOMAIN msgs THEN 
                  IF msgs[m] <= 1 THEN delete(m,msgs)
                                                    ELSE [msgs EXCEPT ![m] = msgs[m] - 1]
                               ELSE msgs 


\* Add a message to the bag of messages.
Send(m) == /\ m \in DOMAIN messages => messages[m] < 1
           /\ messages' = WithMessage(m, messages)

\* Remove a message from the bag of messages. Used when a server is done
\* processing a message.
Discard(m) == messages' = WithoutMessage(m, messages)

\* Combination of Send and Discard
Reply(response, request) == 
          /\ response \in DOMAIN messages => messages[response] < 1
          /\ messages' = WithoutMessage(request, WithMessage(response, messages))
          

\* Return the minimum value from a set, or undefined if the set is empty.
Min(s) == CHOOSE x \in s : \A y \in s : x <= y
\* Return the maximum value from a set, or undefined if the set is empty.
Max(s) == CHOOSE x \in s : \A y \in s : x >= y

----
\* Define initial values for all variables

InitServerVars == /\ currentTerm = [i \in Server |-> 1]
                  /\ state       = [i \in Server |-> Follower]
                  /\ votedFor    = [i \in Server |-> Nil]
InitCandidateVars == /\ votesSent = [i \in Server |-> FALSE]
                     /\ votesGranted   = [i \in Server |-> {}]
\* The values nextIndex[i][i] and matchIndex[i][i] are never read, since the
\* leader does not send itself messages. It's still easier to include these
\* in the functions.
InitConstraints == /\ restartNum = 0
                   /\ timeoutNum = 0
Init == /\ messages = [m \in {} |-> 0]
        /\ InitServerVars
        /\ InitCandidateVars
        /\ InitConstraints
----
\* Define state transitions in leader election

\* Candidate i sends j a RequestVote request.
RequestVote(i, j) ==
    /\ state[i] = Candidate
    /\ i \notin votesGranted[i]
    /\ Send([mtype         |-> RequestVoteRequest,
             mterm         |-> currentTerm[i],
             msource       |-> i,
             mdest         |-> j])
    /\ UNCHANGED <<serverVars, votesGranted, 
                   votesSent, restartNum, timeoutNum>>
                   
\* Server i times out and starts a new election.
Timeout(i) == /\ state[i] \in {Follower, Candidate}
              \* /\ \A j \in Server : RequestVote(i, j) \*Not worked for unknown reason
              /\ state' = [state EXCEPT ![i] = Candidate]
              /\ currentTerm' = [currentTerm EXCEPT 
                                ![i] = currentTerm[i] + 1]
              \* Most implementations would probably just set the local vote
              \* atomically, but messaging localhost for it is weaker.
              /\ votedFor' = [votedFor EXCEPT ![i] = Nil]
              /\ votesSent' = [votesSent EXCEPT ![i] = FALSE]
              /\ votesGranted'   = [votesGranted EXCEPT 
                                   ![i] = {}]
              /\ timeoutNum'     = timeoutNum + 1
              /\ timeoutNum <= TimeoutLimit
              /\ UNCHANGED <<messages, restartNum>>


\* Server i receives a RequestVote request from server j with
\* m.mterm <= currentTerm[i].
HandleRequestVoteRequest(i, j, m) ==
    LET grant == \/ /\ votedFor[i] \in {Nil, j}
                    /\ m.mterm >= currentTerm[i]
                 \/ /\ i = j
        newTerm == Max({m.mterm,currentTerm[i]})
    IN 
       /\ \/ /\ m.mterm > currentTerm[i]
             /\ currentTerm' = [currentTerm EXCEPT ![i] = m.mterm]
             /\ state'       = [state       EXCEPT ![i] = Follower]
          \/ /\ m.mterm <= currentTerm[i]
             /\ UNCHANGED <<currentTerm,state>>
             
       /\ \/ /\ grant  
             /\ votedFor' = [votedFor EXCEPT ![i] = j]
          \/ /\ ~grant 
             /\ UNCHANGED votedFor
       /\ Reply([mtype        |-> RequestVoteResponse,
                 mterm        |-> newTerm,
                 mvoteGranted |-> grant,
                 \* mlog is used just for the `elections' history variable for
                 \* the proof. It would not exist in a real implementation.
                 msource      |-> i,
                 mdest        |-> j],
                 m)    
       /\ UNCHANGED <<restartNum, timeoutNum,candidateVars>>

\* Server i receives a RequestVote response from server j with
\* m.mterm = currentTerm[i].
HandleRequestVoteResponse(i, j, m) ==
    \* This tallies votes even when the current state is not Candidate, but
    \* they won't be looked at, so it doesn't matter. 
    \* /\ Assert(m.mterm = currentTerm[i], <<m.mterm, currentTerm[i]>>)
    /\ \/ /\ m.mterm > currentTerm[i]
          /\ state'        = [state EXCEPT ![i] = Follower]
          /\ currentTerm'  = [currentTerm EXCEPT ![i] = m.mterm]
          /\ votedFor'     = [votedFor EXCEPT ![i] = Nil]
          /\ votesGranted' = [votesGranted EXCEPT ![i] = {}]
          /\ UNCHANGED <<restartNum, timeoutNum , votesSent>>
       \/ /\ m.mterm = currentTerm[i]
          /\ \/ /\ m.mvoteGranted
                /\ votesGranted' = [votesGranted EXCEPT ![i] =
                                    votesGranted[i] \cup {j}]
                /\ UNCHANGED <<votesSent>>
             \/ /\ ~m.mvoteGranted
                /\ UNCHANGED <<votesSent, votesGranted>>
          /\ UNCHANGED <<serverVars,restartNum, timeoutNum>>
    /\ Discard(m)
          

\* Any RPC with a newer term causes the recipient to advance its term first.
UpdateTerm(i, j, m) ==
    /\ m.mterm > currentTerm[i]
    /\ currentTerm' = [currentTerm EXCEPT ![i] = m.mterm]
    /\ state'       = [state       EXCEPT ![i] = Follower]
    /\ votedFor'    = [votedFor    EXCEPT ![i] = Nil]
       \* messages is unchanged so m can be processed further.
    /\ UNCHANGED <<messages, candidateVars, 
                   restartNum, timeoutNum>>

\* Candidate i transitions to leader.
BecomeLeader(i) ==
    /\ state[i] = Candidate
    /\ votesGranted[i] \in Quorum
    /\ state'      = [state EXCEPT ![i] = Leader]
    /\ UNCHANGED <<messages, currentTerm, votedFor, 
                   candidateVars, restartNum, timeoutNum>>

\* Receive a message.
Receive(m) ==
    LET i == m.mdest
        j == m.msource
    IN \* Any RPC with a newer term causes the recipient to advance
       \* its term first. Responses with stale terms are ignored.
       \* \/ UpdateTerm(i, j, m)
       \/ /\ m.mtype = RequestVoteRequest
          /\ HandleRequestVoteRequest(i, j, m)
       \/ /\ m.mtype = RequestVoteResponse
          /\ HandleRequestVoteResponse(i, j, m)

----
\* Defines how the variables may transition.
Next ==\/ \E i \in Server : Timeout(i)
       \/ \E i,j \in Server : RequestVote(i, j)  
       \/ \E i \in Server : BecomeLeader(i)
       \/ \E m \in DOMAIN messages : Receive(m)

\* The specification must start with the initial state and transition according
\* to Next.
Spec == Init /\ [][Next]_vars

\* No two leaders in current cluster
Property1 == ~ \E i,j \in Server: /\ i /= j
                                  /\ state[i] = Leader
                                  /\ state[j] = Leader

inv == ~ \E m \in DOMAIN messages :messages[m] > 1

step1 == ~ \E i,j,k \in Server: 
           \E m1,m2,m3 \in DOMAIN messages:
                    /\ i /= j /\ i /= k /\ j /= k
                    /\ m1 /= m2 /\ m1 /= m3 /\ m2 /= m3
                    
                    /\ m1.mtype = RequestVoteResponse
                    /\ m1.msource = i
                    /\ m1.mdest = i
                    
                    /\ m2.mtype = RequestVoteResponse
                    /\ m2.msource = j
                    /\ m2.mdest = i
                    
                    /\ m3.mtype = RequestVoteRequest
                    /\ m3.msource = i
                    /\ m3.mdest = k
===============================================================================