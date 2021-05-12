// leader agent

/* quadrant allocation */

@quads[atomic]
+gsize(S,W,H) : true
  <- .print("Defining quadrants for ",W,"x",H," simulation ",S);
     +quad(S,1, 0, 0, W div 2 - 1, H div 2 - 1);
     +quad(S,2, W div 2, 0, W-1, H div 2 - 1);
     +quad(S,3, 0, H div 2, W div 2 - 1, H - 1);
     +quad(S,4, W div 2, H div 2, W - 1, H - 1);
     .print("Finished all quadrs for ",S).

+init_pos(S,X,Y)[source(A)]
  :  .count(init_pos(S,_,_),4)
  <- .print("* InitPos ",A," is ",X,"x",Y);
     +~quad(S,harvester1); +~quad(S,harvester2);
     +~quad(S,harvester3); +~quad(S,harvester4);
     !assign_all_quads(S,[1,2,3,4]).
+init_pos(S,X,Y)[source(A)]
  <- .print("- InitPos ",A," is ",X,"x",Y).


+!assign_all_quads(_,[]).
+!assign_all_quads(S,[Q|T])
  <- !assign_quad(S,Q);
     !assign_all_quads(S,T).

+!assign_quad(S,Q)
  :  quad(S,Q,X1,Y1,X2,Y2) &
     ~quad(S,_)
  <- .findall(Ag, ~quad(S,Ag), LAgs);
     !calc_ag_dist(S,Q,LAgs,LD);
     .min(LD,d(Dist,Ag));
     .print(Ag, "'s Quadrant is: ",Q);
     -~quad(S,Ag);
     .send(Ag,tell,quadrant(X1,Y1,X2,Y2)).

+!calc_ag_dist(S,Q,[],[]).
+!calc_ag_dist(S,Q,[Ag|RAg],[d(Dist,Ag)|RDist])
  :  quad(S,Q,X1,Y1,X2,Y2) & init_pos(S,AgX,AgY)[source(Ag)]
  <- jia.dist(X1,Y1,AgX,AgY,Dist);
     !calc_ag_dist(S,Q,RAg,RDist).


/* negotiation for found crop */

+bid(Crop,D,Ag)
  :  .count(bid(Crop,_,_),3)  // three bids were received
  <- .print("bid from ",Ag," for ",Crop," is ",D);
     !allocate_harvester(Crop);
     .abolish(bid(Crop,_,_)).
+bid(Crop,D,Ag)
  <- .print("bid from ",Ag," for ",Crop," is ",D).

+!allocate_harvester(Crop)
  <- .findall(op(Dist,A),bid(Crop,Dist,A),LD);
     .min(LD,op(DistCloser,Closer));
     DistCloser < 10000;
     .print("Crop ",Crop," was allocated to ",Closer, " options were ",LD);
     .broadcast(tell,allocated(Crop,Closer)).
     //-Crop[source(_)].
-!allocate_harvester(Crop)
  <- .print("could not allocate crop ",Crop).


/* end of simulation plans */

@end[atomic]
+end_of_simulation(S,_) : true
  <- .print("-- END ",S," --");
     .abolish(init_pos(S,_,_)).


