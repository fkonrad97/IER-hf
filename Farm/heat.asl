// heater agent

/* beliefs */

last_temp(null). // the last temp I did
heating.

/* rules */

calc_new_h(AgH,QuadH2,QuadH2) :- AgH+2 > QuadH2.

calc_new_h(AgH,_,h) :- h = Agh+2.


/* plans for sending the initial temp to leader */

+gsize(S,_,_) : true // S is the simulation Id
  <- !send_init_temp(S).
+!send_init_temp(S) : 21
  <- .send(leader,tell,init_temp(21)).
+!send_init_temp(S) : not pos(_,_) // if I do not know my temp yet
  <- .wait("+temp(X)", 500);     // wait for it and try again
     !!send_init_temp(S).


+heating : true                  <- !wait_for_temp.

@pwfq[atomic]
+!wait_for_temp : heating
   <- -+heating.
+!wait_for_temp : heating
   <- .wait("+quadrant(X1,Y1,X2,Y2)", 500);
      !!wait_for_temp.
+!wait_for_temp : not heating
   <- .print("No longer free while waiting for quadrant.").
-!wait_for_temp // .wait might fail
   <- !!wait_for_temp.

// if I am around the upper temps , cool
+around(X) : last_temp(29) & not heating
  <- ?calc_new_temp(X, X2);
  	 .print("in high temps: 30");
     !prep_around(X2).

// if I am around the lower temps , heat
+around(15) : last_temp(15) & heating
  <- ?calc_new_temp(X, X2);
  	 .print("in low temps: 15");
     !prep_around(X2).

// if I am around the optimal temps , stay
+around(15) : last_temp(15) & not heating
  <- .print("in optimal temps: ", X);
     !prep_around(X).


+around(X) : X2
  <- .print("Temp stays");
     !prep_around(X).

+!prep_around(X) : heating
  <- -around(_,_); -last_temp(_); !around(X).

+!around(X)
   :  (pos(AgX,AgY) & jia.neighbour(AgX,AgY,X,Y)) | last_temp(skip)
   <- +around(X).
+!around(X) : not around(X)
   <- !next_temp(X);
      !!around(X).
+!around(X) : true
   <- !!around(X).

+!next_temp(X,Y)
   :  pos(AgX,AgY)
   <- jia.get_direction(AgX, AgY, X, Y, D);
      -+last_temp(D);
      do(D).
+!next_temp(X) : not pos(_,_)
   <- !next_temp(X,Y).
-!next_temp(X) : true  
   <- .print("Failed temp to ", X, " fixing and trying again!");
      -+last_dir(null);
      !next_temp(X).


/* Crop-searching Plans */

@pcell[atomic]           // atomic: so as not to handle another

+cell(X,Y,temp)
  :  not heating & free
  <- -free;
     +crop(X,Y);
     .print("Crop perceived: ",crop(X,Y));
     !init_handle(crop(X,Y)).

@pcell2[atomic]
+cell(X,Y,temp)
  :  not carrying_crop & not free &
     .desire(handle(crop(OldX,OldY))) &   
     pos(AgX,AgY) &
     jia.dist(X,   Y,   AgX,AgY,DNewG) &
     jia.dist(OldX,OldY,AgX,AgY,DOldG) &
     DNewG < DOldG                   
  <- +crop(X,Y);
     .drop_desire(handle(crop(OldX,OldY)));
     .print("Giving up current crop ",crop(OldX,OldY),
            " to handle ",crop(X,Y)," which I am seeing!");
     .print("Announcing ",crop(OldX,OldY)," to others");
     .broadcast(tell,crop(OldX,OldY));
     .broadcast(untell, committed_to(crop(OldX,OldY)));
     !init_handle(crop(X,Y)).

	 
+cell(X,Y,crop)
  :  not crop(X,Y) & not committed_to(crop(X,Y))
  <- +crop(X,Y);
     .print("Announcing ",crop(X,Y)," to others");
     .broadcast(tell,crop(X,Y)).

	 
+crop(X1,Y1)[source(A)]
  :  A \== self &
     not allocated(crop(X1,Y1),_) &
     not carrying_crop &            
     heating &                       
     pos(X2,Y2) &
     .my_name(Me)
  <- jia.dist(X1,Y1,X2,Y2,D);       // bid
     .send(leader,tell,bid(crop(X1,Y1),D,Me)).


+crop(X1,Y1)[source(A)]
  :  A \== self & .my_name(Me)
  <- .send(leader,tell,bid(crop(X1,Y1),10000,Me)).

  
@palloc1[atomic]
+allocated(temp,Ag)[source(leader)]
  :  .my_name(Ag) & heating
  <- -heating;
     .print("Crop ",Crop," allocated to ",Ag);
     !init_handle(Crop).

	 
@palloc2[atomic]
+allocated(Temp,Ag)[source(leader)]
  :  .my_name(Ag) & not heating 
  <- .print("I can not handle ",Temp," anymore!");
     .print("(Re)announcing ",Temp," to others");
     .broadcast(tell,Temp).


	 
@ppgd[atomic]
+picked(G)[source(A)]
  :  .desire(handle(G)) | .desire(init_handle(G))
  <- .print(A," has taken ",G," that I am pursuing! Dropping my intention.");
     .abolish(G);
     .drop_desire(handle(G));
     !!choose_crop.


+picked(crop(X,Y))
  <- -crop(X,Y)[source(_)].


@pih1[atomic]
+!init_handle(Crop)
  :  .desire(around(_,_))
  <- .print("Dropping around(_,_) desires and intentions to handle ",Crop);
     .drop_desire(around(_,_));
     !init_handle(Crop).
@pih2[atomic]
+!init_handle(Crop)
  :  pos(X,Y)
  <- .print("Going for ",Crop);
     -+last_checked(X,Y);
     !!handle(Crop). 

+!handle(crop(X,Y))
  :  not heating
  <- .print("Handling ",crop(X,Y)," now.");
     .broadcast(tell, committed_to(crop(X,Y)));
     !pos(X,Y);
     !ensure(pick,crop(X,Y));
     .broadcast(tell,picked(crop(X,Y)));
     ?depot(_,DX,DY);
     !pos(DX,DY);
     !ensure(drop, 0);
     -temp(X,Y)[source(_)];
     .print("Finish handling ",crop(X,Y));
     !!choose_crop.

-!handle(G) : G
  <- .print("failed to catch crop ",G);
     .abolish(G); // ignore source
     !!choose_crop.
-!handle(G) : true
  <- .print("failed to handle ",G,", it isn't in the BB anyway");
     !!choose_crop.

+!choose_crop
  :  not crop(_,_)
  <- -+heating.

+!choose_crop
  :  crop(_,_)
  <- .findall(crop(X,Y),crop(X,Y),LG);
     !calc_crop_distance(LG,LD);
     .length(LD,LLD); LLD > 0;
     .print("Uncommitted crop distances: ",LD,LLD);
     .min(LD,d(_,NewG));
     .print("Next crop is ",NewG);
     !!handle(NewG).
-!choose_crop <- -+heating.

+!calc_crop_distance([],[]).
+!calc_crop_distance([crop(GX,GY)|R],[d(D,crop(GX,GY))|RD])
  :  pos(IX,IY) & not committed_to(crop(GX,GY))
  <- jia.dist(IX,IY,GX,GY,D);
     !calc_crop_distance(R,RD).
+!calc_crop_distance([_|R],RD)
  <- !calc_crop_distance(R,RD).


+!pos(X,Y) : pos(X,Y) <- .print("I've reached ",X,"x",Y).
+!pos(X,Y) : not pos(X,Y)
  <- !next_temp(X,Y);
     !pos(X,Y).


+!ensure(pick,_) : pos(X,Y) & cell(X,Y,crop)
  <- do(pick); ?carrying_crop.

+!ensure(drop, _) : pos(X,Y) & depot(_,X,Y)
  <- do(drop).


/* end of a simulation */

+end_of_simulation(S,_) : true
  <- .drop_all_desires;
     .abolish(quadrant(_,_,_,_));
     .abolish(crop(_,_));
     .abolish(committed_to(_));
     .abolish(picked(_));
     .abolish(last_checked(_,_));
     -+heating;
     .print("-- END ",S," --").


