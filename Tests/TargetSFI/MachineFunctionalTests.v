(**************************************************
 * Author: Ana Nora Evans (ananevans@virginia.edu)
 **************************************************)
Require Import Coq.ZArith.ZArith.
Require Import Coq.Structures.Equalities.
Require Import Coq.Lists.List.
Require Import Coq.FSets.FMapAVL.
Require Import Coq.Strings.Ascii.
Require Import Coq.Strings.String.

Require Import Common.Definitions.
Require Import Common.Util.
Require Import Common.Maps.
Require Import TargetSFI.SFIUtil.
Require Import TargetSFI.Machine.

Require Import TargetSFI.SFITestUtil.
From mathcomp.ssreflect Require Import ssreflect ssrbool eqtype.

Import BinNatMapExtra.
Import SFI.

Example test_CODE_DATA_BIT_MASK :
  SFI.CODE_DATA_BIT_MASK = hex2N "10000".
Proof. unfold CODE_DATA_BIT_MASK. unfold OFFSET_BITS_NO. unfold COMP_BITS_NO.
       simpl. unfold hex2N. reflexivity. Qed.

Example test_AND_DATA_MASK :
  SFI.AND_DATA_MASK = hex2N "FE0FFF".
Proof.
  compute. eauto. Qed.
  
  (* unfold AND_DATA_MASK. unfold OFFSET_BITS_NO. *)
  (* unfold COMP_BITS_NO. unfold BLOCK_BITS_NO. *)
  (* reflexivity. Qed. *)

Example test_AND_CODE_MASK :
  SFI.AND_CODE_MASK = hex2N "FE0FF0".
Proof.
  unfold AND_DATA_MASK. unfold OFFSET_BITS_NO.
  unfold COMP_BITS_NO. unfold BLOCK_BITS_NO.
  reflexivity. Qed.

Example test_address_of1 :
   address_of 1%N 0%N 0%N =  hex2N "001000".
Proof.
  unfold address_of.
  unfold OFFSET_BITS_NO. unfold COMP_BITS_NO.
  reflexivity. Qed.

Example test_C_SFI :
  C_SFI (hex2N "003000") = 3%N.
Proof.
  unfold C_SFI.
  unfold OFFSET_BITS_NO. unfold COMP_BITS_NO.
  reflexivity. Qed.

Example test_is_code_address_true :
  is_code_address (hex2N "00B000") = true.
Proof.
  unfold is_code_address.
  unfold CODE_DATA_BIT_MASK. unfold COMP_BITS_NO. unfold OFFSET_BITS_NO.
  reflexivity. Qed.

Example test_is_code_address_false :
  is_code_address (hex2N "01F000") = false.
Proof.
  unfold is_code_address.
  unfold CODE_DATA_BIT_MASK. unfold COMP_BITS_NO. unfold OFFSET_BITS_NO.
  reflexivity. Qed.

Example test_or_data_mask0 :
  or_data_mask 0%N = (hex2N "010000").
Proof.
  unfold or_data_mask.
  unfold COMP_BITS_NO. unfold OFFSET_BITS_NO.
  reflexivity. Qed.

Example test_or_data_mask3 :
  or_data_mask 3%N = (hex2N "013000").
Proof.
  unfold or_data_mask.
  unfold COMP_BITS_NO. unfold OFFSET_BITS_NO.
  reflexivity. Qed.

Example test_or_code_mask0 :
  or_code_mask 0%N = (hex2N "000000").
Proof.
  unfold or_code_mask.
  unfold COMP_BITS_NO. unfold OFFSET_BITS_NO.
  reflexivity. Qed.

Example test_or_code_mask3 :
  or_code_mask 3%N = (hex2N "003000").
Proof.
  unfold or_code_mask.
  unfold COMP_BITS_NO. unfold OFFSET_BITS_NO.
  reflexivity. Qed.

Example test_allocate_data_slots0 :
  Allocator.allocate_data_slots 0 = [].
Proof.
  unfold Allocator.allocate_data_slots.
  reflexivity. Qed.

Example test_allocate_data_slots5 :
  Allocator.allocate_data_slots 5 = [3%N;5%N;7%N;9%N;11%N].
Proof.
  unfold Allocator.allocate_data_slots.
  reflexivity. Qed.

Example test_allocate_code_slots0 :
  Allocator.allocate_code_slots 0 = [].
Proof.
  unfold Allocator.allocate_code_slots.
  reflexivity. Qed.

Example test_allocate_code_slots5 :
  Allocator.allocate_code_slots 5 = [0%N;2%N;4%N;6%N;8%N].
Proof.
  unfold Allocator.allocate_code_slots.
  reflexivity. Qed.

Example test_get_register :
   RiscMachine.RegisterFile.get_register RiscMachine.Register.R_SFI_SP (List.map Z.of_nat (List.seq 0 RiscMachine.Register.NO_REGISTERS)) = Some 26%Z.
Proof.
  unfold RiscMachine.RegisterFile.get_register.
  unfold RiscMachine.Register.R_SFI_SP.
  unfold  RiscMachine.Register.NO_REGISTERS.
  reflexivity. Qed.
