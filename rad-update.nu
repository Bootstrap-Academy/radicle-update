def "rad update" [
  --title: string = "update dependencies",
  updates: closure,
] {
  let base = git rev-parse HEAD
  print -e $"base rev: ($base)"

  do $updates

  let head = git rev-parse HEAD
  print -e $"head rev: ($head)"

  rad update patch --base $base --head $head --title $title
}

def "rad update patch" [--base: string, --head: string, --title: string] {
  if $head == $base {
    print -e "no changes"
    return
  }

  let rid = rad inspect --rid
  let did = rad self --did
  let patches = rad cob list --repo $rid --type xyz.radicle.patch
    | lines
    | par-each { |id|
      rad cob show --repo $rid --type xyz.radicle.patch --object $id
      | from json
      | insert id $id
      | move --first id
      | insert last_update { get revisions | values | get timestamp? | each { default 0 } | math max }
    }
    | where author.id == $did and title == $title
    | where state.status in [open, draft]
    | sort-by -r last_update

  let push_options = [
    "-o" $"patch.message=($title)"
    "-o" $"patch.base=($base)"
  ]

  if ($patches | is-not-empty) {
    let patch = $patches | first
    print -e $"checking existing patch ($patch.id)"

    git fetch rad ...($patch.revisions | values | get oid)
    let matches = $patch.revisions
      | values
      | where { |r| $r.base == $base and (git diff -s --exit-code $r.oid $head | complete | $in.exit_code == 0) }

    if ($matches | is-not-empty) {
      print -e $"patch ($patch.id) is already up to date at revisions ($matches | get id)"
    } else {
      print -e $"pushing new revision to ($patch.id)"
      git push rad --force $"($head):refs/heads/patches/($patch.id)" ...$push_options
    }
  } else {
    print -e "creating new patch"
    git push rad $"($head):refs/patches" ...$push_options
  }
}
