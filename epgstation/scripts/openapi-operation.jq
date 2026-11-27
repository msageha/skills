# Prints one operation of an OpenAPI 3 document with every local $ref inlined.
# Usage: curl -sf <document URL> | jq -e -f openapi-operation.jq --arg method <method> --arg path <path>
# <path> is a key of the document's `paths`, exactly as written there.
# Each REST skill ships an identical copy of this file; edit them together.
. as $root
| def resolve($seen):
    if type == "object" then
      if (."$ref" | type) == "string" and (."$ref" | startswith("#/")) then
        ."$ref" as $ref
        # A recursive schema refers back to itself: leave the inner reference as is.
        | (if $ref | IN($seen[]) then {"$ref": $ref}
           else $root
             | getpath($ref[2:] | split("/") | map(gsub("~1"; "/") | gsub("~0"; "~")))
             | (. // error("unresolvable $ref \($ref)"))
             | resolve($seen + [$ref])
           end)
          + (del(."$ref") | resolve($seen))
      else map_values(resolve($seen)) end
    elif type == "array" then map(resolve($seen))
    else . end;
($method | ascii_downcase) as $m
| ($root.paths[$path] // error("no path \($path) in the document")) as $item
| ($item[$m] // error("no \($m | ascii_upcase) operation on \($path)")) | resolve([]) as $op
| {method: ($m | ascii_upcase), $path, summary: $op.summary, description: $op.description}
  + ($op | with_entries(select(.key | startswith("x-"))))
  + {
    # Operation-level parameters override path-level ones with the same name and location.
    parameters: (($item.parameters // [] | resolve([])) + ($op.parameters // []) | group_by([.in, .name]) | map(last)),
    request: $op.requestBody,
    responses: $op.responses
  }
