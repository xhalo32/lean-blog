split("(^|\\n)(-/|/-)"; "") | 
map(ltrimstr("\n")) | 

(.[1] | split("\n")) as $lines | 
$lines[0] as $title |
($lines[1:] | join("\n")) as $metadata | 
.[2] as $preamble | 

"import VersoManual",
$preamble,
"open Verso.Genre Manual InlineLean",
"#doc (Manual) \"" + $title + "\" =>",
$metadata,
(.[3:] | to_entries[] | select(.value | test("\\S")) |
    if (.key % 2) == 0
    then .value
    else
      (.value | split("\n")) as $code_lines |
      if ($code_lines[0] == "-- -show")
      then "```lean -show\n" + .value + "\n```"
      else "```lean\n" + .value + "\n```"
      end
    end
)