Require Import Common.Definitions.
Require Import Common.Blame.
Require Import Common.CompCertExtensions.
Require Import CompCert.Events.
Require Import CompCert.Smallstep.
Require Import CompCert.Behaviors.
Require Import Source.Language.
Require Import Source.GlobalEnv.
Require Import Source.CS.
Require Import Source.PS.
Require Import Intermediate.Machine.
Require Import Intermediate.PS.
Require Import Intermediate.Decomposition.
Require Import Intermediate.Composition.
Require Import S2I.Compiler.
Require Import S2I.Definitions.
Require Import Definability.

From mathcomp Require Import ssreflect ssrfun ssrbool.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Set Bullet Behavior "Strict Subproofs".

Section RSC_DC_MD.
  Variable p: Source.program.
  Variable p_compiled: Intermediate.program.
  Variable Ct: Intermediate.program.

  (* Some reasonable assumptions about our programs *)

  Hypothesis well_formed_p : Source.well_formed_program p.
  Hypothesis successful_compilation : compile_program p = Some p_compiled.
  Hypothesis well_formed_Ct : Intermediate.well_formed_program Ct.
  Hypothesis linkability : linkable (Source.prog_interface p) (Intermediate.prog_interface Ct).
  Hypothesis closedness :
    Intermediate.closed_program (Intermediate.program_link p_compiled Ct).
  Hypothesis mains : Intermediate.linkable_mains p_compiled Ct.

  Lemma blame:
    forall
      Cs t' P' m
      (well_formed_Cs : Source.well_formed_program Cs)
      (Hlinkable_p_Cs : linkable (Source.prog_interface p) (Source.prog_interface Cs))
      (Hclosed_p_Cs : Source.closed_program (Source.program_link p Cs))
      (HpCs_beh : program_behaves (S.CS.sem (Source.program_link p Cs)) (Goes_wrong t'))
      (well_formed_P' : Source.well_formed_program P')
      (Hsame_iface1 : Source.prog_interface P' = Intermediate.prog_interface p_compiled)
      (HP'Cs_closed : Source.closed_program (Source.program_link P' Cs))
      (HP'_Cs_beh : program_behaves (S.CS.sem (Source.program_link P' Cs)) (Terminates (finpref_trace m)))
      (Hnot_wrong' : not_wrong_finpref m)
      (K : trace_finpref_prefix t' m),
      undef_in t' (Source.prog_interface p).
  Proof.
    intros Cs t' P' m well_formed_Cs Hlinkable_p_Cs Hclosed_p_Cs HpCs_beh
           well_formed_P' Hsame_iface1 HP'Cs_closed HP'_Cs_beh Hnot_wrong' K.
    inversion HP'_Cs_beh as [sini1 ? Hini1 Hstbeh1 |]; subst.
    inversion Hstbeh1 as [? sfin1 HStar1 Hfinal1 | | |]; subst.
    (* RB: TODO: Lemma relating final_state and Nostep.
       Also simplify all the annoying rewriting that follows. *)
    assert (HNostep1 : Nostep (S.CS.sem (Source.program_link P' Cs)) sfin1).
    {
      simpl in Hfinal1. simpl.
      intros tcon scon Hcontra.
      CS.unfold_state sfin1.
      destruct Hfinal1 as [Hexit | [val [Hexpr [Hcont Hstack]]]]; subst;
        inversion Hcontra.
    }
    inversion HpCs_beh as [sini2 ? Hini2 Hstbeh2 | Hnot_initial2]; subst;
      last (destruct (CS.initial_state_exists (Source.program_link p Cs)) as [wit Hf];
            specialize (Hnot_initial2 wit);
            contradiction).
    inversion Hstbeh2 as [| | | ? sfin2 HStar2 HNostep2 Hnot_final2]; subst.
    rewrite
      (Source.closed_program_link_sym well_formed_p well_formed_Cs Hlinkable_p_Cs)
      in Hclosed_p_Cs.
    pose proof compilation_preserves_interface _ _ successful_compilation
      as Hsame_iface3.
    assert (Hlinkable_P'_Cs := Hlinkable_p_Cs).
    rewrite <- Hsame_iface3 in Hlinkable_P'_Cs.
    rewrite <- Hsame_iface1 in Hlinkable_P'_Cs.
    rewrite
      (Source.closed_program_link_sym well_formed_P' well_formed_Cs Hlinkable_P'_Cs)
      in HP'Cs_closed.
    rewrite Hsame_iface3 in Hsame_iface1.
    assert (Hpartialize :
              Source.PS.PS.partialize (Source.prog_interface p) sini1 =
              Source.PS.PS.partialize (Source.prog_interface p) sini2).
    {
      pose proof PS.partialize_partition.
      rewrite (Source.link_sym well_formed_P' well_formed_Cs Hlinkable_P'_Cs)
        in Hini1.
      rewrite (Source.link_sym well_formed_p well_formed_Cs Hlinkable_p_Cs)
        in Hini2.
      pose proof PS.partialize_partition
           well_formed_Cs well_formed_P' well_formed_p
           Hsame_iface1 (linkable_sym Hlinkable_P'_Cs) HP'Cs_closed Hclosed_p_Cs
           Hini1 Hini2.
      congruence.
    }
    rewrite (Source.link_sym well_formed_P' well_formed_Cs Hlinkable_P'_Cs)
      in HStar1 HNostep1 Hfinal1.
    rewrite (Source.link_sym well_formed_p well_formed_Cs Hlinkable_p_Cs)
      in HStar2 HNostep2.
    (* Case analysis on m. FGoes_wrong can be ruled out by contradiction,
       but also solved exactly like the others. *)
    destruct m as [tm | tm | tm];
      (destruct K as [tm' Htm']; subst tm;
       unfold finpref_trace in HStar1;
       pose proof PS.parallel_exec
         well_formed_Cs well_formed_P' well_formed_p
         (linkable_sym Hlinkable_p_Cs)
         HP'Cs_closed Hclosed_p_Cs
         Hsame_iface1 (eq_refl (Source.prog_interface p))
         Hpartialize
         HStar1 HStar2 HNostep1 HNostep2 Hfinal1
         as Hparallel;
       case: (boolP (CS.s_component sfin2 \in domm (Source.prog_interface p)))=> [Hparallel1|/Hparallel Hparallel2];
         [ rewrite (Source.link_sym well_formed_p well_formed_Cs Hlinkable_p_Cs)
             in Hini2;
           exact (PS.blame_last_comp_star Hini2 HStar2 Hparallel1)
         | easy ]).
  Qed.

  (* Main Theorem *)

  Theorem RSC_DC_MD:
    forall b m,
      program_behaves (I.CS.sem (Intermediate.program_link p_compiled Ct)) b ->
      prefix m b ->
      not_wrong b -> (* CH: could try to weaken this later to `nor_wrong m` *)
    exists Cs beh,
      Source.prog_interface Cs = Intermediate.prog_interface Ct /\
      Source.well_formed_program Cs /\
      linkable (Source.prog_interface p) (Source.prog_interface Cs) /\
      Source.closed_program (Source.program_link p Cs) /\
      program_behaves (S.CS.sem (Source.program_link p Cs)) beh /\
      (prefix m beh \/
      (exists t',
        beh = Goes_wrong t' /\ trace_finpref_prefix t' m /\
         undef_in t' (Source.prog_interface p))).
  Proof.
    intros t m Hbeh Hprefix0 Hsafe_beh.

    (* Some auxiliary results. *)
    pose proof
      Compiler.compilation_preserves_well_formedness well_formed_p successful_compilation
      as well_formed_p_compiled.

    assert (linkability_pcomp_Ct :
              linkable (Intermediate.prog_interface p_compiled)
                       (Intermediate.prog_interface Ct)).
    {
      assert (sound_interface_p_Ct : sound_interface (unionm (Source.prog_interface p)
                                                             (Intermediate.prog_interface Ct)))
        by apply linkability.
      assert (fdisjoint_p_Ct : fdisjoint (domm (Source.prog_interface p))
                                         (domm (Intermediate.prog_interface Ct)))
        by apply linkability.
      constructor;
        apply compilation_preserves_interface in successful_compilation;
        now rewrite successful_compilation.
    }

    assert (Hnot_wrong' : not_wrong_finpref m).
    { now destruct m, t; simpl; auto. }

    (* intermediate decomposition (for p_compiled) *)
    pose proof Intermediate.Decomposition.decomposition_with_safe_behavior
      well_formed_p_compiled well_formed_Ct linkability_pcomp_Ct Hbeh Hsafe_beh as HP_decomp.

    (* CH: if we had undefined behavior we would use this *)
    (* destruct (decomposition_with_refinement linkability Hbeh) *)
    (*   as [beh' [Hbeh' Hbeh_improves]]. *)

    (* definability *)
    destruct (definability_with_linking
                well_formed_p_compiled well_formed_Ct
                linkability_pcomp_Ct closedness Hbeh Hprefix0 Hnot_wrong')
      as [P' [Cs
         [Hsame_iface1 [Hsame_iface2
         [well_formed_P' [well_formed_Cs [HP'Cs_closed [HP'_Cs_beh Hprefix1]]]]]]]].

    move: HP'_Cs_beh Hprefix1.
    set beh := Terminates _.
    move=> HP'_Cs_beh Hprefix1.

    assert (Source.linkable_mains P' Cs) as HP'Cs_mains.
    { apply Source.linkable_disjoint_mains; trivial; congruence. }

    (* FCC *)

    (* the definability output can be split in two programs *)
    (* probably need partialize to obtain them *)

    (* At this point, we compile P' and Cs and establish their basic properties. *)
    destruct (well_formed_compilable _ well_formed_P') as [P'_compiled HP'_compiles].
    pose proof Compiler.compilation_preserves_well_formedness well_formed_P' HP'_compiles
      as well_formed_P'_compiled.
    destruct (well_formed_compilable _ well_formed_Cs) as [Cs_compiled HCs_compiles].
    pose proof Compiler.compilation_preserves_well_formedness well_formed_Cs HCs_compiles
      as well_formed_Cs_compiled.
    assert
      (linkable
         (Intermediate.prog_interface Cs_compiled)
         (Intermediate.prog_interface P'_compiled))
      as linkability'. {
      eapply @Compiler.compilation_preserves_linkability with (p:=Cs) (c:=P'); eauto.
      apply linkable_sym.
      (* RB: If [linkability] is not used for anything else, refactor these
         rewrites with the instance above, or craft a separate assumption. *)
      rewrite <- Hsame_iface1 in linkability_pcomp_Ct.
      rewrite <- Hsame_iface2 in linkability_pcomp_Ct.
      apply linkability_pcomp_Ct.
    }
    assert (exists P'_Cs_compiled,
              compile_program (Source.program_link P' Cs) = Some P'_Cs_compiled)
      as [P'_Cs_compiled HP'_Cs_compiles]. {
      rewrite <- Hsame_iface1 in linkability_pcomp_Ct.
      rewrite <- Hsame_iface2 in linkability_pcomp_Ct.
      pose proof Source.linking_well_formedness well_formed_P' well_formed_Cs linkability_pcomp_Ct
        as Hlinking_wf.
      apply well_formed_compilable; assumption.
    }

    assert (forall b, program_behaves (I.CS.sem P'_Cs_compiled) b <->
                 program_behaves (I.CS.sem (Intermediate.program_link P'_compiled Cs_compiled)) b)
      as HP'_Cs_behaves. {
      apply Compiler.separate_compilation_weaker with (p:=P') (c:=Cs);
        try assumption;
        [congruence].
    }
    have well_formed_P'Cs : Source.well_formed_program (Source.program_link P' Cs).
      rewrite -Hsame_iface1 -Hsame_iface2 in linkability_pcomp_Ct.
      exact: Source.linking_well_formedness well_formed_P' well_formed_Cs linkability_pcomp_Ct.
    have HP'_Cs_compiled_beh : program_behaves (I.CS.sem P'_Cs_compiled) beh.
      have sim := Compiler.I_simulates_S HP'Cs_closed well_formed_P'Cs HP'_Cs_compiles.
      exact: (forward_simulation_same_safe_behavior sim).

    (* intermediate decomposition (for Cs_compiled) *)
    apply HP'_Cs_behaves in HP'_Cs_compiled_beh.
    apply Source.linkable_mains_sym in HP'Cs_mains. (* TODO: Check if this is used later. *)
    rewrite <- Intermediate.program_linkC in HP'_Cs_compiled_beh;
      [| (apply (Compiler.compilation_preserves_well_formedness well_formed_Cs HCs_compiles))
       | (apply (Compiler.compilation_preserves_well_formedness well_formed_P' HP'_compiles))
       | assumption ].

    have [beh2 [HCs_decomp HCs_beh_improves]] :=
         Intermediate.Decomposition.decomposition_with_refinement
           well_formed_Cs_compiled well_formed_P'_compiled
           linkability' HP'_Cs_compiled_beh.
    have {HCs_beh_improves} ? : beh2 = beh by case: HCs_beh_improves => [<-|[? []]].
    subst beh2.

    (* intermediate composition *)
    assert (Intermediate.prog_interface Ct = Intermediate.prog_interface Cs_compiled)
      as Hctx_same_iface. {
      symmetry. erewrite compilation_preserves_interface.
      - rewrite <- Hsame_iface2. reflexivity.
      - assumption.
    }
    rewrite Hctx_same_iface in HP_decomp.
    assert (Intermediate.prog_interface p_compiled = Intermediate.prog_interface P'_compiled) as Hprog_same_iface. {
      symmetry. erewrite compilation_preserves_interface.
      - apply Hsame_iface1.
      - assumption.
    }
    rewrite <- Hprog_same_iface in HCs_decomp.

    assert (linkable (Intermediate.prog_interface p_compiled) (Intermediate.prog_interface Cs_compiled))
      as linkability''.
    {
      unfold linkable. split; try
        rewrite Hprog_same_iface;
        apply linkable_sym in linkability';
        now inversion linkability'.
    }
    assert (Intermediate.closed_program (Intermediate.program_link p_compiled Cs_compiled))
      as HpCs_compiled_closed.
    now apply (Intermediate.interface_preserves_closedness_r
                 well_formed_p_compiled well_formed_Cs_compiled
                 Hctx_same_iface linkability_pcomp_Ct closedness mains); auto.
    assert (Intermediate.well_formed_program (Intermediate.program_link p_compiled Cs_compiled))
      as HpCs_compiled_well_formed
        by (apply Intermediate.linking_well_formedness; assumption).

    assert (Intermediate.linkable_mains p_compiled Cs_compiled) as linkable_mains.
    {
      eapply (Compiler.compilation_preserves_linkable_mains p _ Cs);
        try assumption.
      - rewrite <- Hsame_iface2 in linkability.
        eapply Source.linkable_disjoint_mains; assumption.
    }

    assert (PS.mergeable_interfaces (Intermediate.prog_interface p_compiled)
                                    (Intermediate.prog_interface Cs_compiled))
      as Hmergeable_ifaces.
    {
      split.
      - assumption.
      - by destruct HpCs_compiled_closed.
    }
    pose proof composition_prefix
         well_formed_p_compiled well_formed_Cs_compiled
         linkable_mains linkability'' HpCs_compiled_closed
         Hmergeable_ifaces
         HP_decomp HCs_decomp
         Hprefix0 Hprefix1
      as HpCs_compiled_beh.
    destruct HpCs_compiled_beh as [b3 [HpCs_compiled_beh HpCs_compiled_prefix]].
    assert (Source.closed_program (Source.program_link p Cs)) as Hclosed_p_Cs. {
      apply (Source.interface_preserves_closedness_l HP'Cs_closed); trivial.
      apply compilation_preserves_interface in HP'_compiles.
      apply compilation_preserves_interface in successful_compilation.
      congruence.
    }
    assert (linkable (Source.prog_interface p) (Source.prog_interface Cs))
      as Hlinkable_p_Cs. {
      inversion linkability'' as [sound_interface_p_Cs fdisjoint_p_Cs].
      constructor;
        (apply compilation_preserves_interface in HCs_compiles;
        apply compilation_preserves_interface in successful_compilation;
        rewrite <- HCs_compiles; rewrite <- successful_compilation;
        assumption).
    }
    assert (Source.well_formed_program (Source.program_link p Cs)) as Hwf_p_Cs
      by (apply Source.linking_well_formedness; assumption).

    (* BCC *)
    assert (exists pCs_compiled,
               compile_program (Source.program_link p Cs) = Some pCs_compiled)
      as [pCs_compiled HpCs_compiles]
      by now apply well_formed_compilable.
    assert (forall b, program_behaves (I.CS.sem pCs_compiled) b <->
                      program_behaves (I.CS.sem (Intermediate.program_link p_compiled Cs_compiled)) b)
      as HpCs_compiled_behaves
      by now apply Compiler.separate_compilation_weaker with (p:=p) (c:=Cs).
    apply HpCs_compiled_behaves in HpCs_compiled_beh.
    assert (exists beh1,
               program_behaves (S.CS.sem (Source.program_link p Cs)) beh1 /\
               behavior_improves beh1 b3) as HpCs_beh. {
      apply backward_simulation_behavior_improves
        with (L1:=S.CS.sem (Source.program_link p Cs)) in HpCs_compiled_beh; auto.
      apply S_simulates_I; assumption.
    }
    destruct HpCs_beh as [pCs_beh [HpCs_beh HpCs_beh_imp]].

    (* At this point we know:

       1. (HP'_Cs_beh) P' `union` Cs goes from s_i to s_f producing
          finpref_trace m, s_f is stuck and final.

       2. Either

          a. p `union` Cs goes from s_i' to s_f' producing a proper prefix of
             finpref_trace m, and s_f' is stuck and not final.

          b. p `union` Cs goes from s_i' to s_f' producing a super sequence of
             finpref_trace m.

       In (2.a), we should be able to conclude with parallel_exec.  This
       corresponds to the right side of the disjunction.

       In (2.b), we are in the left side of the disjunction.

     *)

    destruct HpCs_beh_imp as [Keq | [t' [Hwrong Klonger]]].
    + subst. exists Cs, b3.
      repeat (split; try now auto).
    + assert(finpref_trace_prefix m t' \/ trace_finpref_prefix t' m) as H
          by (eapply behavior_prefix_comp'; eauto).
      destruct H as [K | K].
      * exists Cs, pCs_beh. repeat (split; try now auto). left.
        subst. destruct m;
        inversion K. exists (Goes_wrong x). simpl. now rewrite H.
      * exists Cs, pCs_beh. repeat (split; try now auto).
        right. exists t'. repeat (split; try now auto).
        subst pCs_beh.
        unfold beh in HP'_Cs_beh.
        (* Close the diagram. *)
        exact (blame well_formed_Cs Hlinkable_p_Cs Hclosed_p_Cs HpCs_beh
                     well_formed_P' Hsame_iface1 HP'Cs_closed HP'_Cs_beh Hnot_wrong' K).
  Qed.

End RSC_DC_MD.
