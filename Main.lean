import VersoManual
import Book

open Verso.Genre Manual
open Verso.Output.Html

def config : RenderConfig := {
  extraHead := #[
    {{ <link rel="icon" href="https://static.wikia.nocookie.net/asdfmovie/images/7/76/Potato.jpg/revision/latest" /> }}
  ]
}

def main := manualMain (%doc Book) (config := config)
