Require Import Common.Definitions.
Require Import Common.Values.
Require Import Common.Memory.
Require Import Common.Linking.

Inductive expr : Type :=
| E_val : value -> expr
| E_local : expr
| E_binop : binop -> expr -> expr -> expr
| E_seq : expr -> expr -> expr
| E_if : expr -> expr -> expr -> expr
| E_alloc : expr -> expr
| E_deref : expr -> expr
| E_assign : expr -> expr -> expr
| E_call : Component.id -> Procedure.id -> expr -> expr
| E_exit : expr.

Module Source.
  Record program : Type := mkProg {
    prog_interface : Program.interface;
    prog_procedures : PMap.t (PMap.t expr);
    prog_buffers : PMap.t nat;
    prog_main : Component.id * Procedure.id
  }.

  Definition single_component (p: program) : Prop :=
    PMap.cardinal (prog_interface p) = 1%nat.

  (* An expression is well-formed when:
     1) calls outside the component are allowed by the interface
     2) calls inside the component are targeting existing procedures
     3) the undef value is not present
     4) pointers are not present (no pointers forging) *)
  Fixpoint well_formed_expr (p: program) (cur_comp: Component.id) (e: expr) : Prop :=
    match e with
    | E_val val => exists i, val = Int i
    | E_local => True
    | E_exit => True
    | E_binop op e1 e2 =>
      well_formed_expr p cur_comp e1 /\ well_formed_expr p cur_comp e2
    | E_seq e1 e2 =>
      well_formed_expr p cur_comp e1 /\ well_formed_expr p cur_comp e2
    | E_if e1 e2 e3 =>
      well_formed_expr p cur_comp e1 /\ well_formed_expr p cur_comp e2 /\
      well_formed_expr p cur_comp e3
    | E_alloc e' => well_formed_expr p cur_comp e'
    | E_deref e' => well_formed_expr p cur_comp e'
    | E_assign e1 e2 =>
      well_formed_expr p cur_comp e1 /\ well_formed_expr p cur_comp e2
    | E_call C' P' e' =>
      well_formed_expr p cur_comp e' /\
      (imported_procedure (prog_interface p) cur_comp C' P' \/
       (cur_comp = C' /\
        exists C'procs, PMap.MapsTo C' C'procs (prog_procedures p) /\
                   PMap.In P' C'procs))
    end.

  (* Component C has a buffer of size at least one *)
  Definition has_required_local_buffers (p: program) (C: Component.id) : Prop :=
    exists size, PMap.find C (prog_buffers p) = Some size /\
            (size > 0)%nat.

  Record well_formed_program (p: program) := {
    (* the interface is sound (but maybe not closed) *)
    wfprog_interface_soundness:
      sound_interface (prog_interface p);
    (* each declared component has the required static buffers *)
    wfprog_buffers_existence:
      forall C, PMap.In C (prog_interface p) ->
           has_required_local_buffers p C;
    (* each exported procedure actually exists *)
    wfprog_exported_procedures_existence:
      forall C CI,
        PMap.MapsTo C CI (prog_interface p) ->
      forall P,
        Component.is_exporting CI P ->
      exists Cprocs,
        PMap.MapsTo C Cprocs (prog_procedures p) /\
        PMap.In P Cprocs;
    (* each instruction of each procedure is well-formed *)
    wfprog_well_formed_procedures:
      forall C Cprocs P Pexpr,
        PMap.MapsTo C Cprocs (prog_procedures p) ->
        PMap.MapsTo P Pexpr Cprocs ->
        well_formed_expr p C Pexpr;
    (* if the main component exists, then the main procedure must exist as well *)
    wfprog_main_existence:
      forall main_procs,
        PMap.MapsTo (fst (prog_main p)) main_procs (prog_procedures p) ->
        PMap.In (snd (prog_main p)) main_procs
  }.

  (* a closed program is a program with a closed interface and an existing main
     procedure *)
  Record closed_program (p: program) := {
    (* the interface must be closed (and consequently sound) *)
    cprog_closed_interface:
      closed_interface (prog_interface p);
    (* the main procedure must exist *)
    cprog_main_existence:
      exists procs,
        PMap.MapsTo (fst (prog_main p)) procs (prog_procedures p) /\
        PMap.In (snd (prog_main p)) procs;
  }.

  Definition linkable_programs (p1 p2: program) : Prop :=
    (* both programs are well-formed *)
    well_formed_program p1 /\ well_formed_program p2 /\
    (* their interfaces are disjoint *)
    PMapExtra.Disjoint (prog_interface p1) (prog_interface p2) /\
    (* the union of their interfaces is sound *)
    sound_interface (PMapExtra.update (prog_interface p1) (prog_interface p2)).

  Definition program_link (p1 p2: program) mainC mainP : program :=
    {| prog_interface := PMapExtra.update (prog_interface p1) (prog_interface p2);
       prog_procedures := PMapExtra.update (prog_procedures p1) (prog_procedures p2);
       prog_buffers := PMapExtra.update (prog_buffers p1) (prog_buffers p2);
       prog_main := (mainC, mainP) |}.

  Fixpoint alloc_buffers
           (bufs: list (Component.id * nat))
           (m: Memory.t) (addrs: PMap.t Block.id)
    : Memory.t * PMap.t Block.id :=
    match bufs with
    | [] => (m, addrs)
    | (C,size)::bufs' =>
      let memC := match PMap.find C m with
                  | Some memC => memC
                  | None => ComponentMemory.empty
                  end in
      let '(memC', b) := ComponentMemory.alloc memC size in
      alloc_buffers bufs' (PMap.add C memC' m) (PMap.add C b addrs)
    end.

  Definition init_all (p: program) : PMap.t Block.id * Memory.t :=
    let pbufs := PMap.elements (prog_buffers p) in
    let init_mem := Memory.empty (map fst pbufs) in
    let '(mem, bufs) := alloc_buffers pbufs init_mem (@PMap.empty Block.id) in
    (bufs, mem).
End Source.