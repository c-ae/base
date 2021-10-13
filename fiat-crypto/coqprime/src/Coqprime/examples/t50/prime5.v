Require Import PocklingtonRefl.


Local Open Scope positive_scope.

Lemma prime296193496741 : prime 296193496741.
Proof.
 apply (Pocklington_refl
         (Pock_certif 296193496741 2 ((2467, 1)::(2,2)::nil) 16834)
        ((Proof_certif 2467 prime2467) ::
         (Proof_certif 2 prime2) ::
          nil)).
 vm_cast_no_check (refl_equal true).
Qed.

Lemma prime56789012345678901234567890123456789012345678901251: prime  56789012345678901234567890123456789012345678901251.
apply (Pocklington_refl 

(SPock_certif 
56789012345678901234567890123456789012345678901251
2
((64809143903770500695655224106655394022648421, 1)::nil))
(
(SPock_certif 
64809143903770500695655224106655394022648421
2
((143528628977580537977599369933230499, 1)::nil))
::
(Ell_certif
143528628977580537977599369933230499
147984
((969892886917373085790177496509,1)::nil)
80956800083162715589327371358432158
51310268889317992145811050312666099
0
128485858476228824601322735963624700)
::
(Ell_certif
969892886917373085790177496509
18103449
((53575033515291555240277,1)::nil)
0
500
5
25)
::
(SPock_certif 
53575033515291555240277
2
((296193496741, 1)::nil))
:: (Proof_certif 296193496741 prime296193496741) :: nil)).
vm_cast_no_check (refl_equal true).
Time Qed.