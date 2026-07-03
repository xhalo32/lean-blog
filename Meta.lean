import VersoManual

open Verso.Genre Manual
open Verso.Doc Elab
open Verso.ArgParse
open Lean

@[code_block_expander nix]
public meta def nix : CodeBlockExpander
  | _args, code => do
    let code := code.getString
    -- TODO add syntax highlighting
    return #[← ``(Block.code $(quote code))]
