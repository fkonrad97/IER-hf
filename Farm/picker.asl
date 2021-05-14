/* Plans */
@pGetCrop[atomic]
+cell(X,Y,crop)
  <- do(pick_on);
     .send(agent,tell,crop(X,Y));
     !!change(temp);
     .print("Pick ", X, ", ", Y);.

+picked(X,Y)
  <- -cell(X,Y,crop);.

+!change(temp)
  :  cell(_,_,temp)
  <- .print("heat temp");
     do(change);
     .wait(1000);
     !change(temp).

@poff[atomic]
+!change(temp)
  :  not cell(_,_,temp)
  <- do(siren_off);
     .print("No more crop");.
     
+!perceive(crop)
  <- do(skip);
     .wait(100);
     !perceive(crop).


